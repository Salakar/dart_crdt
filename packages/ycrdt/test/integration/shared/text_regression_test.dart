import 'package:test/test.dart';
import 'package:ycrdt/src/content/content.dart';
import 'package:ycrdt/src/delta/delta_operation.dart';
import 'package:ycrdt/src/doc/doc.dart';

import '../../helpers/random_convergence_harness.dart';
import '../../helpers/random_shared_type_operations.dart';
import '../../helpers/shared_regression_fixture.dart';

void main() {
  group('shared text regressions', () {
    test('keeps formatting stable across fragmented edits', () {
      final doc = Doc();
      final text = doc.get('body', SharedTypeKind.text);
      final events = <Set<Object?>>[];
      text.observe((event) => events.add(event.keys));

      for (var index = 0; index < 64; index += 1) {
        text.insertText(
          index,
          index.isEven ? 'a' : 'b',
          attributes: DeltaAttributes.fromJson({'token': index}),
        );
      }
      text
        ..format(10, 20, DeltaAttributes.fromJson({'bold': true}))
        ..format(15, 5, DeltaAttributes.fromJson({'bold': null}))
        ..deleteText(30, 10)
        ..insertEmbed(
          30,
          {'image': 'asset'},
          attributes: DeltaAttributes.fromJson({'origin': 'fixture'}),
        );

      final delta = text.toDelta().toJson();

      expect(text.length, 55);
      expect(text.toPlainText().contains('\uFFFC'), isTrue);
      expect(delta.toString(), contains('token'));
      expect(delta.toString(), contains('origin'));
      expect(delta.toString(), contains('bold'));
      expect(events.length, greaterThan(60));
      expect(text.searchMarkers.single.index, 30);
    });

    test('preserves attribution-style attributes through fixture convergence',
        () {
      final scenario = sharedRegressionScenario('text');
      final harness = RandomConvergenceHarness<Doc>(
        seed: scenario.seed,
        replicaCount: scenario.replicaCount,
        createReplica: (_) => Doc(),
        snapshot: textConvergenceSnapshot,
        testFile: 'test/integration/shared/text_regression_test.dart',
        plainName: 'attribution-style attributes',
      );

      harness
        ..disconnect(0, 1)
        ..publish(
          originIndex: 0,
          operation: textInsertOperation(token: 888, origin: 0),
        )
        ..flushPending(duplicateDeliveries: scenario.duplicateDeliveries);

      expect(harness.pendingUpdateCount, greaterThan(0));

      harness.run(
        operationCount: scenario.operationCount,
        nextOperation: randomTextOperations(),
        networkChurnEvery: scenario.networkChurnEvery,
        duplicateDeliveries: scenario.duplicateDeliveries,
      );

      final uniqueSnapshots =
          harness.replicas.map(textConvergenceSnapshot).toSet();
      expect(uniqueSnapshots, hasLength(1));
      expect(uniqueSnapshots.single, contains('"token":888'));
      expect(uniqueSnapshots.single, contains('"origin":0'));
      expect(_traceContains(harness, 'text delete'), isTrue);
      expect(_traceContains(harness, 'duplicate'), isTrue);
    });
  });
}

bool _traceContains(RandomConvergenceHarness<Doc> harness, String text) {
  return harness.trace.any((entry) => entry.contains(text));
}
