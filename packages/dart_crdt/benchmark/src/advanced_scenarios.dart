import 'advanced_shape.dart';
import 'benchmark_case.dart';
import 'benchmark_runner.dart';
import 'gc_scenarios.dart';
import 'relative_snapshot_scenarios.dart';
import 'undo_attribution_scenarios.dart';

/// Builds advanced feature benchmark cases for [mode].
List<BenchmarkCase> buildAdvancedCases(BenchmarkMode mode) {
  final shape = AdvancedShape.forMode(mode);

  return <BenchmarkCase>[
    ...buildRelativeSnapshotCases(shape),
    ...buildUndoAttributionCases(shape),
    ...buildGcCases(shape),
  ];
}
