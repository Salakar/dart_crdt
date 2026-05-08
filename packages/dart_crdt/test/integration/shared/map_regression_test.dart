import 'package:dart_crdt/src/content/content.dart';
import 'package:dart_crdt/src/doc/doc.dart';
import 'package:test/test.dart';

import '../../helpers/random_convergence_harness.dart';
import '../../helpers/random_shared_type_operations.dart';
import '../../helpers/shared_regression_fixture.dart';

void main() {
  group('shared map regressions', () {
    test('preserves event values through conflicts, iteration, and nesting',
        () {
      final doc = Doc();
      final map = doc.get('attrs');
      final child = SharedType(kind: SharedTypeKind.map, name: 'child');
      final events = <String>[];
      final deepEvents = <String>[];

      map
        ..observe((event) {
          for (final key in event.keys) {
            events.add('$key=${event.target.getAttr('$key')}');
          }
        })
        ..observeDeep((event) {
          deepEvents.add('${event.target.name}:${event.keys.join(',')}');
        });

      doc.transact((_) {
        map
          ..setAttr('title', 'old', clock: 5)
          ..setAttr('title', 'stale', clock: 4)
          ..setAttr('title', 'new', clock: 6)
          ..setAttr('child', child, clock: 7);
        child.setAttr('nested', 'value');
        map.deleteAttr('title', clock: 5);
      });

      expect(map.getAttr('title'), 'new');
      expect(child.doc, same(doc));
      expect(child.parent, same(map));
      expect(map.attrEntries.map((entry) => entry.key).toList(), [
        'title',
        'child',
      ]);
      expect(events, [
        'title=new',
        'child=map:child',
      ]);
      expect(deepEvents, contains('child:nested'));

      map.clearAttrs();

      expect(child.parent, isNull);
      expect(map.attrSize, 0);
    });

    test('covers fixture-backed conflicts, late sync, and disconnects', () {
      final scenario = sharedRegressionScenario('map');
      final harness = RandomConvergenceHarness<Doc>(
        seed: scenario.seed,
        replicaCount: scenario.replicaCount,
        createReplica: (_) => Doc(),
        snapshot: mapConvergenceSnapshot,
        testFile: 'test/integration/shared/map_regression_test.dart',
        plainName: 'fixture-backed conflicts',
      );

      harness
        ..disconnect(0, 1)
        ..publish(
          originIndex: 0,
          operation: mapSetOperation(
            key: 'fixture',
            valueId: 'fixture',
            clock: 1,
            nested: true,
          ),
        )
        ..flushPending(duplicateDeliveries: scenario.duplicateDeliveries);

      expect(harness.pendingUpdateCount, greaterThan(0));

      harness.run(
        operationCount: scenario.operationCount,
        nextOperation: randomMapOperations(),
        networkChurnEvery: scenario.networkChurnEvery,
        duplicateDeliveries: scenario.duplicateDeliveries,
      );

      final uniqueSnapshots =
          harness.replicas.map(mapConvergenceSnapshot).toSet();
      expect(uniqueSnapshots, hasLength(1));
      expect(uniqueSnapshots.single, contains('fixture=nested:fixture'));
      expect(_traceContains(harness, 'map delete'), isTrue);
      expect(_traceContains(harness, 'disconnect'), isTrue);
    });
  });
}

bool _traceContains(RandomConvergenceHarness<Doc> harness, String text) {
  return harness.trace.any((entry) => entry.contains(text));
}
