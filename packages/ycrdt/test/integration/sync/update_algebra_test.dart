import 'package:test/test.dart';
import 'package:ycrdt/src/content/content.dart';
import 'package:ycrdt/src/doc/doc.dart';
import 'package:ycrdt/src/structs/abstract_struct.dart';
import 'package:ycrdt/src/structs/id.dart';
import 'package:ycrdt/src/sync/apply_update.dart';
import 'package:ycrdt/src/sync/state_update.dart';
import 'package:ycrdt/src/sync/state_vector.dart';
import 'package:ycrdt/src/sync/update_algebra.dart';

void main() {
  group('V1 update algebra', () {
    test('merges empty and duplicate update arrays', () {
      final update = encodeStateAsUpdate(_docWithItem(1, 'a'));
      final merged = mergeUpdates([update, update]);
      final target = Doc(clientId: ClientId(9));

      expect(mergeUpdates(const []), [0, 0]);
      applyUpdate(target, merged);

      expect(target.store.getClock(ClientId(1)), Clock(1));
      expect(_rootText(target), 'a');
    });

    test('is commutative for shuffled independent updates', () {
      final a = encodeStateAsUpdate(_docWithItem(1, 'a'));
      final b = encodeStateAsUpdate(_docWithItem(2, 'b'));
      final left = Doc(clientId: ClientId(9));
      final right = Doc(clientId: ClientId(10));

      applyUpdate(left, mergeUpdates([a, b, a]));
      applyUpdate(right, mergeUpdates([b, a, b]));

      expect(left.store.stateVector(), right.store.stateVector());
      expect(_rootText(left), _rootText(right));
    });

    test('diffs merged updates against a target state vector', () {
      final a = encodeStateAsUpdate(_docWithItem(1, 'a'));
      final b = encodeStateAsUpdate(_docWithItem(2, 'b'));
      final target = Doc(clientId: ClientId(9));
      applyUpdate(target, a);

      final diff =
          diffUpdate(mergeUpdates([a, b]), encodeDocumentStateVector(target));
      applyUpdate(target, diff);

      expect(target.store.stateVector(), {
        ClientId(1): Clock(1),
        ClientId(2): Clock(1),
      });
    });

    test('does not emit first-written skip output for unresolved updates', () {
      final unresolved = encodeStateAsUpdate(
        _docWithItem(1, 'abc'),
        encodeStateVector({ClientId(1): Clock(1)}),
      );

      expect(mergeUpdates([unresolved]), [0, 0]);
      expect(diffUpdate(unresolved, encodeStateVector(const {})), [0, 0]);
    });
  });

  group('V2 update algebra', () {
    test('merges and diffs V2 updates', () {
      final a = encodeStateAsUpdateV2(_docWithItem(1, 'a'));
      final b = encodeStateAsUpdateV2(_docWithItem(2, 'b'));
      final merged = mergeUpdatesV2([b, a, b]);
      final target = Doc(clientId: ClientId(9));

      applyUpdateV2(target, diffUpdateV2(merged, encodeStateVector(const {})));

      expect(target.store.stateVector(), {
        ClientId(1): Clock(1),
        ClientId(2): Clock(1),
      });
    });
  });
}

Doc _docWithItem(int client, String text) {
  final doc = Doc(clientId: ClientId(client));
  doc.store.add(
    Item(
      id: _id(client, 0),
      parent: doc.itemParentForKey('root'),
      content: ContentString(text),
    ),
  );
  return doc;
}

String _rootText(Doc doc) {
  return doc
      .itemParentForKey('root')
      .items()
      .where((item) => !item.deleted)
      .map((item) => (item.content as ContentString).value)
      .join();
}

Id _id(int client, int clock) {
  return Id(client: ClientId(client), clock: Clock(clock));
}
