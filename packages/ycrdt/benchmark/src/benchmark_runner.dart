import 'dart:io';

import 'benchmark_case.dart';
import 'benchmark_result.dart';
import 'scenarios.dart';

/// Supported benchmark suite modes.
enum BenchmarkMode {
  /// Short run suitable for pull request and local smoke verification.
  smoke,

  /// Longer run suitable for scheduled performance tracking.
  full,
}

/// Fixed benchmark configuration for a mode.
final class BenchmarkRunConfig {
  /// Creates benchmark run configuration.
  const BenchmarkRunConfig({
    required this.mode,
    required this.iterations,
    required this.warmupIterations,
  });

  /// Benchmark suite mode.
  final BenchmarkMode mode;

  /// Measured iterations per benchmark case.
  final int iterations;

  /// Warmup iterations per benchmark case.
  final int warmupIterations;
}

/// Returns the fixed run configuration for [mode].
BenchmarkRunConfig configForMode(BenchmarkMode mode) => switch (mode) {
      BenchmarkMode.smoke => const BenchmarkRunConfig(
          mode: BenchmarkMode.smoke,
          iterations: 12,
          warmupIterations: 2,
        ),
      BenchmarkMode.full => const BenchmarkRunConfig(
          mode: BenchmarkMode.full,
          iterations: 120,
          warmupIterations: 8,
        ),
    };

/// Parses a benchmark mode name.
BenchmarkMode parseBenchmarkMode(String value) => switch (value) {
      'smoke' => BenchmarkMode.smoke,
      'full' => BenchmarkMode.full,
      _ => throw ArgumentError.value(value, 'value', 'Expected smoke or full.'),
    };

/// Runs the benchmark suite and returns JSON-serializable results.
BenchmarkSuiteResult runYcrdtBenchmarks({
  BenchmarkMode mode = BenchmarkMode.smoke,
}) {
  final config = configForMode(mode);
  final cases = buildBenchmarkCases(mode);
  final results = <BenchmarkMeasurement>[
    for (final benchmarkCase in cases)
      benchmarkCase.measureCase(
        iterations: config.iterations,
        warmupIterations: config.warmupIterations,
      ),
  ];

  return BenchmarkSuiteResult(
    packageName: 'ycrdt',
    mode: mode.name,
    generatedAt: DateTime.now().toUtc(),
    runtime: BenchmarkRuntime(
      dartVersion: Platform.version,
      operatingSystem: Platform.operatingSystem,
      numberOfProcessors: Platform.numberOfProcessors,
    ),
    results: results,
  );
}

/// Builds benchmark cases for [mode].
List<BenchmarkCase> buildBenchmarkCases(BenchmarkMode mode) =>
    buildScenarioCases(mode);
