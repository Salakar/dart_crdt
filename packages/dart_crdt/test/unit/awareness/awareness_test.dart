import 'package:dart_crdt/dart_crdt.dart';
import 'package:test/test.dart';

void main() {
  group('Awareness', () {
    test('sets local state and emits added and updated events', () {
      final awareness = Awareness(localClientId: ClientId(1));
      final changes = <AwarenessChange>[];
      awareness.changes.add(changes.add);

      final first = awareness.setLocalState({'name': 'Ada'});
      final second = awareness.setLocalField('cursor', 4);

      expect(first, isNotEmpty);
      expect(second, isNotEmpty);
      expect(awareness.localState!.toObject(), {
        'name': 'Ada',
        'cursor': 4,
      });
      expect(changes, hasLength(2));
      expect(changes[0].added, {ClientId(1)});
      expect(changes[1].updated, {ClientId(1)});
    });

    test('round-trips updates between clients', () {
      final left = Awareness(localClientId: ClientId(1));
      final right = Awareness(localClientId: ClientId(2));

      left.setLocalState({
        'user': {'name': 'Ada'},
        'cursor': 7,
      });
      final update = encodeAwarenessUpdate(left, clients: {ClientId(1)});
      final change = applyAwarenessUpdate(right, update);

      expect(change.added, {ClientId(1)});
      expect(right.states[ClientId(1)]!.toObject(), {
        'user': {'name': 'Ada'},
        'cursor': 7,
      });
    });

    test('ignores stale updates and accepts newer clocks', () {
      final source = Awareness(localClientId: ClientId(1));
      final target = Awareness(localClientId: ClientId(2));

      final oldUpdate = source.setLocalState({'cursor': 1});
      final newUpdate = source.setLocalState({'cursor': 2});

      target.applyAwarenessUpdate(newUpdate);
      final staleChange = target.applyAwarenessUpdate(oldUpdate);

      expect(staleChange.isEmpty, isTrue);
      expect(target.states[ClientId(1)]!.toObject(), {'cursor': 2});
    });

    test('removes visible states with encoded tombstones', () {
      final left = Awareness(localClientId: ClientId(1));
      final right = Awareness(localClientId: ClientId(2));

      applyAwarenessUpdate(right, left.setLocalState({'name': 'Ada'}));
      final removal = removeAwarenessStates(left, {ClientId(1)});
      final change = applyAwarenessUpdate(right, removal);

      expect(change.removed, {ClientId(1)});
      expect(right.states, isNot(contains(ClientId(1))));
      expect(left.localState, isNull);
    });

    test('remote timeout tombstone allows the source next clock to recover',
        () {
      final source = Awareness(localClientId: ClientId(1));
      final target = Awareness(localClientId: ClientId(2));
      final relay = Awareness(localClientId: ClientId(3));

      final first = source.setLocalState({'cursor': 1});
      target.applyAwarenessUpdate(first);
      relay.applyAwarenessUpdate(first);

      final timeout = target.removeAwarenessStates({ClientId(1)});
      final relayChange = relay.applyAwarenessUpdate(timeout);
      expect(relayChange.removed, {ClientId(1)});
      expect(relay.states, isNot(contains(ClientId(1))));
      expect(relay.applyAwarenessUpdate(timeout).isEmpty, isTrue);
      expect(relay.applyAwarenessUpdate(first).isEmpty, isTrue);
      expect(relay.states, isNot(contains(ClientId(1))));

      final recovered = source.setLocalState({'cursor': 2});
      final targetChange = target.applyAwarenessUpdate(recovered);
      final relayRecovery = relay.applyAwarenessUpdate(recovered);

      expect(targetChange.added, {ClientId(1)});
      expect(relayRecovery.added, {ClientId(1)});
      expect(target.states[ClientId(1)]!.toObject(), {'cursor': 2});
      expect(relay.states[ClientId(1)]!.toObject(), {'cursor': 2});
    });

    test('echoed own tombstone preserves and advances local state', () {
      final source = Awareness(localClientId: ClientId(1));
      final target = Awareness(localClientId: ClientId(2));
      final first = source.setLocalState({'cursor': 1});
      target.applyAwarenessUpdate(first);
      final timeout = target.removeAwarenessStates({ClientId(1)});

      final protected = source.applyAwarenessUpdate(timeout);

      expect(protected.updated, {ClientId(1)});
      expect(source.localState!.clock, 2);
      expect(source.localState!.toObject(), {'cursor': 1});
      final refanned = target.applyAwarenessUpdate(
        source.encodeAwarenessUpdate(clients: {ClientId(1)}),
      );
      expect(refanned.added, {ClientId(1)});

      final movement = source.setLocalState({'cursor': 2});
      expect(source.localState!.clock, 3);
      expect(target.applyAwarenessUpdate(movement).updated, {ClientId(1)});
      expect(target.states[ClientId(1)]!.toObject(), {'cursor': 2});
    });

    test('accepted self clocks advance the next local clock', () {
      final source = Awareness(localClientId: ClientId(1));
      final sameIdPeer = Awareness(localClientId: ClientId(1));
      for (var index = 0; index < 4; index += 1) {
        source.setLocalState({'cursor': index});
      }

      sameIdPeer.applyAwarenessUpdate(source.encodeAwarenessUpdate());
      final local = sameIdPeer.setLocalState({'cursor': 5});

      expect(sameIdPeer.localState!.clock, 5);
      expect(source.applyAwarenessUpdate(local).updated, {ClientId(1)});
      expect(source.localState!.toObject(), {'cursor': 5});
    });

    test('rejects malformed payloads', () {
      final awareness = Awareness(localClientId: ClientId(1));

      expect(
        () => awareness.applyAwarenessUpdate([1, 1, 1, 2]),
        throwsFormatException,
      );
    });

    test('rejects a malformed frame atomically without events', () {
      final source = Awareness(localClientId: ClientId(1));
      final target = Awareness(localClientId: ClientId(1));
      final changes = <AwarenessChange>[];
      target.changes.add(changes.add);
      for (var index = 1; index <= 4; index += 1) {
        source.setLocalState({'cursor': index});
      }
      final validPrefix = source.encodeAwarenessUpdate().toList();
      validPrefix[0] = 2;
      validPrefix.addAll([3, 1, 2]);

      expect(
        () => target.applyAwarenessUpdate(validPrefix),
        throwsFormatException,
      );
      expect(target.states, isEmpty);
      expect(changes, isEmpty);
      target.setLocalState({'cursor': 1});
      expect(target.localState!.clock, 1);
    });

    test('rejects trailing bytes atomically without replacing prior state', () {
      final source = Awareness(localClientId: ClientId(2));
      final target = Awareness(localClientId: ClientId(1));
      target.applyAwarenessUpdate(source.setLocalState({'cursor': 1}));
      final changes = <AwarenessChange>[];
      target.changes.add(changes.add);
      final malformed = <int>[
        ...source.setLocalState({'cursor': 2}),
        0,
      ];

      expect(
        () => target.applyAwarenessUpdate(malformed),
        throwsFormatException,
      );
      expect(target.states[ClientId(2)]!.toObject(), {'cursor': 1});
      expect(changes, isEmpty);
    });
  });
}
