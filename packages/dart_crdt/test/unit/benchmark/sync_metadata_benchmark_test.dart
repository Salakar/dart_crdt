import 'package:test/test.dart';

import '../../../benchmark/src/benchmark_runner.dart';
import '../../../benchmark/src/sync_metadata_scenarios.dart';

void main() {
  group('sync and metadata benchmarks', () {
    test('emit required sync and metadata metrics', () {
      final cases = buildSyncMetadataCases(BenchmarkMode.smoke);

      expect(
        cases.map((benchmarkCase) => benchmarkCase.name),
        containsAll(<String>[
          'sync_v1_encode_apply_merge_diff',
          'sync_v2_encode_apply_merge_diff',
          'sync_update_format_convert',
          'sync_pending_out_of_order_recovery',
          'metadata_id_set_algebra',
          'metadata_id_map_algebra',
        ]),
      );

      for (final benchmarkCase in cases) {
        final measurement = benchmarkCase.measureCase(
          iterations: 1,
          warmupIterations: 0,
        );

        expect(measurement.metrics['operationCount'], isA<int>());
        if (benchmarkCase.name.startsWith('sync_')) {
          expect(measurement.metrics['updateBytesV1'], isA<int>());
          expect(measurement.metrics['updateBytesV2'], isA<int>());
          expect(measurement.metrics['structCount'], isA<int>());
        } else {
          expect(measurement.metrics['clientCount'], isA<int>());
          expect(measurement.metrics['mergedRangeCount'], isA<int>());
        }
      }
    });
  });
}
