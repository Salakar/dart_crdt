import 'dart:typed_data';

import 'package:dart_crdt/dart_crdt.dart';
import 'package:test/test.dart' hide Skip;

void main() {
  for (final version in _UpdateVersion.values) {
    group('${version.name} wire Skip framing', () {
      test('Skip-only input integrates no state and emits no update', () {
        final legacy = Doc(clientId: ClientId(90))
          ..store.add(Skip(id: _id(7, 0), length: 3));
        final target = Doc(clientId: ClientId(8));
        final events = <DocUpdateEvent>[];
        _events(version, target).add(events.add);

        _apply(version, target, _encode(version, legacy));

        expect(target.store.getClock(ClientId(7)), Clock(0));
        expect(target.store.skips.isEmpty, isTrue);
        expect(target.store.pendingStructs.isEmpty, isTrue);
        expect(target.store.inserted.isEmpty, isTrue);
        expect(events, isEmpty);
      });

      test('legacy midstream Skip cannot poison abcZXY convergence', () {
        final relay = Doc(clientId: ClientId(1));
        final peer = Doc(clientId: ClientId(2));
        final target = Doc(clientId: ClientId(3));
        final relayText = relay.getText('body');
        relayText.insertText(0, 'abc');
        final baseline = _encode(version, relay);
        _apply(version, peer, baseline);
        _apply(version, target, baseline);

        final peerText = peer.getText('body');
        final beforeX = encodeDocumentStateVector(peer);
        peerText.insertText(3, 'X');
        final x = _encode(version, peer, beforeX);
        final beforeY = encodeDocumentStateVector(peer);
        peerText.insertText(4, 'Y');
        final y = _encode(version, peer, beforeY);

        // The relay sees Y before X, then edits locally while Y is pending.
        _apply(version, relay, y);
        expect(relay.store.pendingStructs.isNotEmpty, isTrue);
        relayText.insertText(3, 'Z');

        _apply(version, target, x);
        final targetState = encodeDocumentStateVector(target);

        // This is the payload emitted by a pre-0.4.0 relay: its real local Z
        // plus a fabricated Skip covering the still-pending Y clock.
        final legacyRelay = Doc(clientId: ClientId(90))
          ..store.add(
            Item(
              id: _id(1, 3),
              origin: _id(1, 2),
              parent: null,
              content: ContentString('Z'),
            ),
          )
          ..store.add(Skip(id: _id(2, 1), length: 1));
        _apply(version, target, _encode(version, legacyRelay, targetState));

        expect(target.store.getClock(ClientId(2)), Clock(1));
        expect(target.store.skips.isEmpty, isTrue);

        _apply(version, target, y);
        _apply(version, relay, x);

        expect(target.getText('body').toPlainText(), 'abcZXY');
        expect(relayText.toPlainText(), 'abcZXY');
        expect(target.store.pendingStructs.isEmpty, isTrue);
        expect(relay.store.pendingStructs.isEmpty, isTrue);
        expect(target.store.skips.isEmpty, isTrue);
      });

      test('delete set remains pending across a skipped causal gap', () {
        final source = Doc(clientId: ClientId(7));
        final sourceText = source.getText('body');
        sourceText.insertText(0, 'abc');
        final prefix = _encode(version, source);
        final prefixState = encodeDocumentStateVector(source);
        sourceText.insertText(3, 'XYZ');
        final healthyTail = _encode(version, source, prefixState);

        final target = Doc(clientId: ClientId(8));
        _apply(version, target, prefix);

        final legacy = Doc(clientId: ClientId(90))
          ..store.add(Skip(id: _id(7, 3), length: 2))
          ..store.add(
            Item(
              id: _id(7, 5),
              origin: _id(7, 4),
              parent: null,
              content: ContentString('Z'),
            ),
          )
          ..store.addPendingDeleteSet(IdSet()..add(_id(7, 4)));
        _apply(version, target, _encode(version, legacy, prefixState));

        expect(target.store.getClock(ClientId(7)), Clock(3));
        expect(target.store.skips.isEmpty, isTrue);
        expect(target.store.pendingStructs.isNotEmpty, isTrue);
        expect(target.store.pendingDeleteSet.hasId(_id(7, 4)), isTrue);

        _apply(version, target, healthyTail);

        expect(target.getText('body').toPlainText(), 'abcXZ');
        expect(target.store.getClock(ClientId(7)), Clock(6));
        expect(target.store.pendingStructs.isEmpty, isTrue);
        expect(target.store.pendingDeleteSet.isEmpty, isTrue);
        expect(target.store.skips.isEmpty, isTrue);
      });

      test('full-state dependency chain retries to a fixpoint', () {
        final first = Doc(clientId: ClientId(1));
        first.getText('body').insertText(0, 'a');
        final updateA = _encode(version, first);

        final second = Doc(clientId: ClientId(2));
        _apply(version, second, updateA);
        final beforeB = encodeDocumentStateVector(second);
        second.getText('body').insertText(1, 'b');
        final updateB = _encode(version, second, beforeB);

        final third = Doc(clientId: ClientId(3));
        _apply(version, third, updateA);
        _apply(version, third, updateB);
        final beforeC = encodeDocumentStateVector(third);
        third.getText('body').insertText(2, 'c');
        final updateC = _encode(version, third, beforeC);

        final archive = Doc(clientId: ClientId(99));
        _apply(version, archive, updateA);
        _apply(version, archive, updateB);
        _apply(version, archive, updateC);

        final target = Doc(clientId: ClientId(100));
        _apply(version, target, _encode(version, archive));

        expect(target.getText('body').toPlainText(), 'abc');
        expect(target.store.pendingStructs.isEmpty, isTrue);
        expect(target.store.skips.isEmpty, isTrue);
      });
    });
  }
}

enum _UpdateVersion { v1, v2 }

Uint8List _encode(_UpdateVersion version, Doc doc, [List<int>? stateVector]) {
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

EventHandler<DocUpdateEvent> _events(_UpdateVersion version, Doc doc) {
  return switch (version) {
    _UpdateVersion.v1 => doc.update,
    _UpdateVersion.v2 => doc.updateV2,
  };
}

Id _id(int client, int clock) {
  return Id(client: ClientId(client), clock: Clock(clock));
}
