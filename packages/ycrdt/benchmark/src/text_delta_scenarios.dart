import 'benchmark_case.dart';
import 'benchmark_runner.dart';
import 'delta_scenarios.dart';
import 'text_delta_shape.dart';
import 'text_scenarios.dart';

/// Builds text and delta benchmark cases for [mode].
List<BenchmarkCase> buildTextAndDeltaCases(BenchmarkMode mode) {
  final shape = TextDeltaShape.forMode(mode);

  return <BenchmarkCase>[
    ...buildTextCases(shape),
    ...buildDeltaCases(shape),
  ];
}
