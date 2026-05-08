import 'benchmark_case.dart';
import 'benchmark_runner.dart';
import 'metadata_scenarios.dart';
import 'sync_metadata_shape.dart';
import 'sync_scenarios.dart';

/// Builds sync and metadata benchmark cases for [mode].
List<BenchmarkCase> buildSyncMetadataCases(BenchmarkMode mode) {
  final shape = SyncMetadataShape.forMode(mode);

  return <BenchmarkCase>[
    ...buildSyncCases(shape),
    ...buildMetadataCases(shape),
  ];
}
