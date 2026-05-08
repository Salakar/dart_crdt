import 'dart:io';

import 'package:benchmark_harness/benchmark_harness.dart';

import 'benchmark_result.dart';

/// Function executed by a benchmark case.
typedef BenchmarkWork = void Function();

/// Function that captures scenario-specific benchmark metrics.
typedef BenchmarkMetricsFactory = Map<String, Object?> Function();

/// A benchmark case with a deterministic measurement loop.
final class BenchmarkCase extends BenchmarkBase {
  /// Creates a benchmark case.
  BenchmarkCase({
    required String name,
    required this.description,
    required BenchmarkWork work,
    required BenchmarkMetricsFactory metrics,
  })  : _work = work,
        _metrics = metrics,
        super(name);

  final BenchmarkWork _work;
  final BenchmarkMetricsFactory _metrics;

  /// Human-readable benchmark purpose.
  final String description;

  /// Measures this benchmark with fixed iteration counts.
  BenchmarkMeasurement measureCase({
    required int iterations,
    required int warmupIterations,
  }) {
    for (var index = 0; index < warmupIterations; index++) {
      run();
    }

    final rssBefore = ProcessInfo.currentRss;
    final stopwatch = Stopwatch()..start();
    for (var index = 0; index < iterations; index++) {
      run();
    }
    stopwatch.stop();
    final rssAfter = ProcessInfo.currentRss;

    return BenchmarkMeasurement(
      name: name,
      description: description,
      iterations: iterations,
      warmupIterations: warmupIterations,
      elapsedMicroseconds: stopwatch.elapsedMicroseconds,
      metrics: <String, Object?>{
        'wallClockMicroseconds': stopwatch.elapsedMicroseconds,
        ..._metrics(),
        'rssBytesBefore': rssBefore,
        'rssBytesAfter': rssAfter,
        'rssBytesDelta': rssAfter - rssBefore,
      },
    );
  }

  @override
  void run() => _work();
}
