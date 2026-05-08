import 'package:test/test.dart';

import '../../../benchmark/src/benchmark_runner.dart';
import '../../../benchmark/src/collection_tree_scenarios.dart';

void main() {
  group('collection and tree benchmarks', () {
    test('emit required document and update metrics', () {
      final cases = buildCollectionTreeCases(BenchmarkMode.smoke);

      expect(
        cases.map((benchmarkCase) => benchmarkCase.name),
        containsAll(<String>[
          'array_random_insert_delete_nested',
          'map_set_delete_conflicts',
          'xml_tree_insert_delete_stringify',
        ]),
      );

      for (final benchmarkCase in cases) {
        final measurement = benchmarkCase.measureCase(
          iterations: 1,
          warmupIterations: 0,
        );

        expect(measurement.metrics['operationCount'], isA<int>());
        expect(measurement.metrics['documentSizeBytes'], isA<int>());
        expect(measurement.metrics['structCount'], isA<int>());
        expect(measurement.metrics['updateBytesV1'], isA<int>());
        expect(measurement.metrics['updateBytesV2'], isA<int>());
      }
    });
  });
}
