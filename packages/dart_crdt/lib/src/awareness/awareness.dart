/// Provider-neutral awareness and presence state.
library;

import 'dart:typed_data';

import '../binary/any_codec.dart';
import '../binary/any_value.dart';
import '../binary/byte_reader.dart';
import '../binary/byte_writer.dart';
import '../binary/varint_codec.dart';
import '../events/event_handler.dart';
import '../structs/id.dart';

part 'awareness_codec.dart';

/// A client awareness snapshot.
final class AwarenessState {
  /// Creates an awareness state.
  const AwarenessState({
    required this.clientId,
    required this.clock,
    required this.state,
  });

  /// Client that owns this state.
  final ClientId clientId;

  /// Monotonic state clock for last-write-wins merging.
  final int clock;

  /// JSON-compatible presence payload, or `null` when removed.
  final JsonMap? state;

  /// Whether this state represents a removed/offline client.
  bool get isRemoved => state == null;

  /// Converts the payload to a defensive Dart map.
  Map<String, Object?>? toObject() => state?.toObject();

  @override
  bool operator ==(Object other) {
    return other is AwarenessState &&
        clientId == other.clientId &&
        clock == other.clock &&
        state == other.state;
  }

  @override
  int get hashCode => Object.hash(clientId, clock, state);
}

/// Awareness clients changed by an update.
final class AwarenessChange {
  /// Creates an awareness change event.
  AwarenessChange({
    required Set<ClientId> added,
    required Set<ClientId> updated,
    required Set<ClientId> removed,
  })  : added = Set<ClientId>.unmodifiable(added),
        updated = Set<ClientId>.unmodifiable(updated),
        removed = Set<ClientId>.unmodifiable(removed);

  /// Clients that became visible.
  final Set<ClientId> added;

  /// Clients whose visible state changed.
  final Set<ClientId> updated;

  /// Clients that were removed.
  final Set<ClientId> removed;

  /// Whether no client changed.
  bool get isEmpty => added.isEmpty && updated.isEmpty && removed.isEmpty;
}

/// Tracks ephemeral client presence state.
final class Awareness {
  /// Creates awareness for [localClientId].
  Awareness({required this.localClientId});

  /// Local client controlled by [setLocalState].
  final ClientId localClientId;

  final EventHandler<AwarenessChange> _changes =
      EventHandler<AwarenessChange>();
  final Map<ClientId, AwarenessState> _states = <ClientId, AwarenessState>{};
  int _localClock = 0;

  /// Emits after visible awareness states change.
  EventHandler<AwarenessChange> get changes => _changes;

  /// Current non-removed states.
  Map<ClientId, AwarenessState> get states =>
      Map<ClientId, AwarenessState>.unmodifiable({
        for (final entry in _states.entries)
          if (!entry.value.isRemoved) entry.key: entry.value,
      });

  /// Local visible state, or `null` when offline.
  AwarenessState? get localState => states[localClientId];

  /// Replaces the local presence payload and returns the encoded update.
  Uint8List setLocalState(Map<String, Object?>? state) {
    _localClock += 1;
    final awarenessState = AwarenessState(
      clientId: localClientId,
      clock: _localClock,
      state: state == null ? null : _jsonMap(state),
    );
    _applyState(awarenessState, emit: true);
    return encodeAwarenessUpdate(clients: {localClientId});
  }

  /// Updates one local presence field and returns the encoded update.
  Uint8List setLocalField(String key, Object? value) {
    final current = Map<String, Object?>.of(localState?.toObject() ?? {});
    current[key] = value;
    return setLocalState(current);
  }

  /// Encodes awareness states for [clients], or all known clients by default.
  Uint8List encodeAwarenessUpdate({Iterable<ClientId>? clients}) {
    final selected = clients ?? _states.keys;
    final writer = ByteWriter();
    final states = [
      for (final client in selected)
        if (_states[client] case final state?) state,
    ];
    writeVarUint(writer, states.length);
    for (final state in states) {
      writeVarUint(writer, state.clientId.value);
      writeVarUint(writer, state.clock);
      writer.writeByte(state.state == null ? 0 : 1);
      final payload = state.state;
      if (payload != null) {
        writeJsonValue(writer, payload);
      }
    }
    return writer.toBytes();
  }

  /// Applies an encoded awareness update and returns the visible changes.
  AwarenessChange applyAwarenessUpdate(List<int> update) {
    final reader = ByteReader(update);
    final count = readVarUint(reader);
    // Decode and validate the complete frame before mutating state. Presence
    // updates are small, and atomic rejection is substantially safer than
    // committing a valid prefix of a malformed provider frame.
    final decoded = <AwarenessState>[
      for (var index = 0; index < count; index += 1)
        _readAwarenessState(reader),
    ];
    if (!reader.isDone) {
      throw FormatException(
        'Trailing awareness update bytes.',
        update,
        reader.offset,
      );
    }

    final added = <ClientId>{};
    final updated = <ClientId>{};
    final removed = <ClientId>{};
    for (final state in decoded) {
      final previous = _states[state.clientId];
      if (!_isNewer(state, previous)) {
        continue;
      }
      var acceptedState = state;
      if (state.clientId == localClientId) {
        if (state.clock > _localClock) {
          _localClock = state.clock;
        }
        if (state.isRemoved && previous != null && !previous.isRemoved) {
          // A relayed timeout may echo this client's equal-clock tombstone back
          // to its owner. Keep the locally owned payload authoritative and move
          // its clock beyond the tombstone so the provider can re-fan it.
          _localClock += 1;
          acceptedState = AwarenessState(
            clientId: localClientId,
            clock: _localClock,
            state: previous.state,
          );
        }
      }
      final accepted = _applyState(acceptedState, emit: false);
      if (accepted == _AwarenessChangeKind.added) {
        added.add(state.clientId);
      } else if (accepted == _AwarenessChangeKind.updated) {
        updated.add(state.clientId);
      } else if (accepted == _AwarenessChangeKind.removed) {
        removed.add(state.clientId);
      }
    }

    final change = AwarenessChange(
      added: added,
      updated: updated,
      removed: removed,
    );
    if (!change.isEmpty) {
      _changes.emit(change);
    }
    return change;
  }

  /// Removes [clients] and returns an encoded update for the removal.
  Uint8List removeAwarenessStates(Iterable<ClientId> clients) {
    final changed = <ClientId>{};
    for (final client in clients) {
      final previous = _states[client];
      if (previous == null || previous.isRemoved) {
        continue;
      }
      // A provider may time out a remote client, but it does not own that
      // client's clock. Reuse the last observed clock for a remote tombstone;
      // equal-clock removal wins over a visible state, while the source's very
      // next clock can make it visible again. Only this instance's local client
      // advances its own clock.
      final clock = client == localClientId ? ++_localClock : previous.clock;
      final state = AwarenessState(
        clientId: client,
        clock: clock,
        state: null,
      );
      _applyState(state, emit: false);
      changed.add(client);
    }
    if (changed.isNotEmpty) {
      _changes.emit(
        AwarenessChange(
          added: {},
          updated: {},
          removed: changed,
        ),
      );
    }
    return encodeAwarenessUpdate(clients: changed);
  }

  _AwarenessChangeKind? _applyState(
    AwarenessState state, {
    required bool emit,
  }) {
    final previous = _states[state.clientId];
    _states[state.clientId] = state;
    final kind = _changeKind(previous, state);
    if (emit && kind != null) {
      _changes.emit(
        AwarenessChange(
          added: kind == _AwarenessChangeKind.added ? {state.clientId} : {},
          updated: kind == _AwarenessChangeKind.updated ? {state.clientId} : {},
          removed: kind == _AwarenessChangeKind.removed ? {state.clientId} : {},
        ),
      );
    }
    return kind;
  }
}

/// Encodes awareness states from [awareness].
Uint8List encodeAwarenessUpdate(
  Awareness awareness, {
  Iterable<ClientId>? clients,
}) {
  return awareness.encodeAwarenessUpdate(clients: clients);
}

/// Applies an encoded awareness [update] to [awareness].
AwarenessChange applyAwarenessUpdate(Awareness awareness, List<int> update) {
  return awareness.applyAwarenessUpdate(update);
}

/// Removes [clients] from [awareness] and encodes the removal.
Uint8List removeAwarenessStates(
  Awareness awareness,
  Iterable<ClientId> clients,
) {
  return awareness.removeAwarenessStates(clients);
}
