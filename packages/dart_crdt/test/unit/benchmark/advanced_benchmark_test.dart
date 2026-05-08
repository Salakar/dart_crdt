import 'package:test/test.dart';

import '../../../benchmark/src/advanced_scenarios.dart';
import '../../../benchmark/src/benchmark_runner.dart';

void main() {
  group('advanced benchmarks', () {
    test('emit required advanced feature metrics', () {
      final cases = buildAdvancedCases(BenchmarkMode.smoke);

      expect(
        cases.map((benchmarkCase) => benchmarkCase.name),
        containsAll(<String>[
          'advanced_relative_position_create_resolve',
          'advanced_snapshot_create_restore_containment',
          'advanced_undo_redo_stack',
          'advanced_attribution_diff_render_accept_reject_filter',
          'advanced_gc_enabled_vs_disabled',
        ]),
      );

      for (final benchmarkCase in cases) {
        final measurement = benchmarkCase.measureCase(
          iterations: 1,
          warmupIterations: 0,
        );

        expect(measurement.metrics['operationCount'], isA<int>());
        expect(measurement.metrics['rssBytesAfter'], isA<int>());
        if (benchmarkCase.name == 'advanced_gc_enabled_vs_disabled') {
          expect(
            measurement.metrics['structCountBeforeCompaction'],
            isA<int>(),
          );
          expect(measurement.metrics['structCountAfterCompaction'], isA<int>());
        }
      }
    });
  });
}
