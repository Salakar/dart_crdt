import 'package:dart_crdt/src/doc/doc.dart';
import 'package:test/test.dart';

import '../helpers/random_convergence_harness.dart';
import '../helpers/random_shared_type_operations.dart';

void main() {
  group('random shared map convergence', () {
    test('converges with key conflicts, late sync, nested values, and deletes',
        () {
      final harness = RandomConvergenceHarness<Doc>(
        seed: randomConvergenceSeed(fallback: 202),
        replicaCount: 4,
        createReplica: (_) => Doc(),
        snapshot: mapConvergenceSnapshot,
        testFile: 'test/integration/random_map_convergence_test.dart',
        plainName: 'converges with key conflicts, late sync',
      );

      harness
        ..disconnect(0, 1)
        ..publish(
          originIndex: 0,
          operation: mapSetOperation(
            key: 'late',
            valueId: 'late',
            clock: 1,
            nested: true,
          ),
        )
        ..flushPending(duplicateDeliveries: 1);

      expect(harness.pendingUpdateCount, greaterThan(0));

      harness.run(
        operationCount: 40,
        nextOperation: randomMapOperations(),
        networkChurnEvery: 2,
        duplicateDeliveries: 2,
      );

      final snapshots = harness.replicas.map(mapConvergenceSnapshot);
      final uniqueSnapshots = snapshots.toSet();
      expect(uniqueSnapshots, hasLength(1));
      expect(uniqueSnapshots.single, contains('late=nested:late'));
      expect(_traceContains(harness, 'map set nested'), isTrue);
      expect(_traceContains(harness, 'map delete'), isTrue);
      expect(_traceContains(harness, 'duplicate'), isTrue);
      expect(_traceContains(harness, 'disconnect'), isTrue);
      expect(_traceContains(harness, 'reconnect'), isTrue);
    });
  });
}

bool _traceContains(RandomConvergenceHarness<Doc> harness, String text) {
  return harness.trace.any((entry) => entry.contains(text));
}
