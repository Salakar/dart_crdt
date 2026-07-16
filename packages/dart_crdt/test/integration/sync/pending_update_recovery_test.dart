import 'package:dart_crdt/src/doc/doc.dart';
import 'package:dart_crdt/src/events/event_handler.dart';
import 'package:dart_crdt/src/structs/id.dart';
import 'package:dart_crdt/src/sync/apply_update.dart';
import 'package:dart_crdt/src/sync/state_update.dart';
import 'package:dart_crdt/src/sync/state_vector.dart';
import 'package:dart_crdt/src/sync/update_decoder.dart';
import 'package:test/test.dart';

void main() {
  for (final version in _UpdateVersion.values) {
    group('${version.name} pending update recovery', () {
      test('deduplicates redelivery and converges without duplicate events',
          () {
        final updates = _prefixAndTail(version);
        final target = Doc(clientId: ClientId(8));
        final events = <DocUpdateEvent>[];
        _events(version, target).add(events.add);

        _apply(version, target, updates.tail);
        _apply(version, target, updates.tail);

        expect(target.store.pendingStructUpdates, hasLength(1));
        expect(events, isEmpty);

        _apply(version, target, updates.prefix);

        expect(target.getText('root').toPlainText(), 'abc');
        expect(target.store.pendingStructUpdates, isEmpty);
        expect(target.store.pendingStructs.isEmpty, isTrue);
        expect(events, hasLength(1));
      });

      test('low-level reads retain full bytes and retry after the prefix', () {
        final updates = _prefixAndTail(version);
        final target = Doc(clientId: ClientId(8));
        final events = <DocUpdateEvent>[];
        _events(version, target).add(events.add);

        _read(version, target, updates.tail);
        expect(target.store.pendingStructUpdates, hasLength(1));

        _read(version, target, updates.prefix);

        expect(target.getText('root').toPlainText(), 'abc');
        expect(target.store.pendingStructUpdates, isEmpty);
        expect(target.store.pendingStructs.isEmpty, isTrue);
        // These streaming APIs preserve their existing no-event contract.
        expect(events, isEmpty);
      });

      test('low-level reads recover a delete-bearing tail after its prefix',
          () {
        final updates = _prefixAndDelete(version);
        final target = Doc(clientId: ClientId(8));
        final events = <DocUpdateEvent>[];
        _events(version, target).add(events.add);

        _read(version, target, updates.tail);

        expect(target.getText('root').toPlainText(), isEmpty);
        expect(target.store.stateVector(), isEmpty);
        expect(target.store.pendingDeleteSet.isNotEmpty, isTrue);
        expect(target.store.pendingStructUpdates, hasLength(1));
        expect(events, isEmpty);

        _read(version, target, updates.prefix);

        expect(target.getText('root').toPlainText(), 'ac');
        expect(target.store.pendingDeleteSet.isEmpty, isTrue);
        expect(target.store.pendingStructUpdates, isEmpty);
        expect(target.store.pendingStructs.isEmpty, isTrue);
        expect(events, isEmpty);
      });
    });
  }
}

enum _UpdateVersion { v1, v2 }

({List<int> prefix, List<int> tail}) _prefixAndTail(
  _UpdateVersion version,
) {
  final source = Doc(clientId: ClientId(1));
  final text = source.getText('root')..insertText(0, 'a');
  final prefix = _encode(version, source);
  final prefixState = encodeDocumentStateVector(source);
  text.insertText(1, 'bc');
  return (
    prefix: prefix,
    tail: _encode(version, source, prefixState),
  );
}

({List<int> prefix, List<int> tail}) _prefixAndDelete(
  _UpdateVersion version,
) {
  final source = Doc(clientId: ClientId(1));
  final text = source.getText('root')..insertText(0, 'abc');
  final prefix = _encode(version, source);
  final prefixState = encodeDocumentStateVector(source);
  text.deleteText(1, 1);
  return (
    prefix: prefix,
    tail: _encode(version, source, prefixState),
  );
}

List<int> _encode(
  _UpdateVersion version,
  Doc doc, [
  List<int>? stateVector,
]) {
  return switch (version) {
    _UpdateVersion.v1 => encodeStateAsUpdate(doc, stateVector),
    _UpdateVersion.v2 => encodeStateAsUpdateV2(doc, stateVector),
  };
}

void _apply(_UpdateVersion version, Doc doc, List<int> update) {
  switch (version) {
    case _UpdateVersion.v1:
      applyUpdate(doc, update);
    case _UpdateVersion.v2:
      applyUpdateV2(doc, update);
  }
}

void _read(_UpdateVersion version, Doc doc, List<int> update) {
  switch (version) {
    case _UpdateVersion.v1:
      readUpdate(UpdateDecoderV1(update), doc);
    case _UpdateVersion.v2:
      readUpdateV2(UpdateDecoderV2(update), doc);
  }
}

EventHandler<DocUpdateEvent> _events(_UpdateVersion version, Doc doc) {
  return switch (version) {
    _UpdateVersion.v1 => doc.update,
    _UpdateVersion.v2 => doc.updateV2,
  };
}
