import 'dart:convert';

/// Current version of the benchmark JSON output schema.
const benchmarkSchemaVersion = 1;

/// Runtime metadata captured with benchmark output.
final class BenchmarkRuntime {
  /// Creates runtime metadata.
  const BenchmarkRuntime({
    required this.dartVersion,
    required this.operatingSystem,
    required this.numberOfProcessors,
  });

  /// Dart VM version string.
  final String dartVersion;

  /// Operating system identifier reported by the VM.
  final String operatingSystem;

  /// Number of processors available to the process.
  final int numberOfProcessors;

  /// Converts this metadata to benchmark JSON.
  Map<String, Object?> toJson() => <String, Object?>{
        'dartVersion': dartVersion,
        'operatingSystem': operatingSystem,
        'numberOfProcessors': numberOfProcessors,
      };
}

/// A single benchmark measurement.
final class BenchmarkMeasurement {
  /// Creates a benchmark measurement.
  const BenchmarkMeasurement({
    required this.name,
    required this.description,
    required this.iterations,
    required this.warmupIterations,
    required this.elapsedMicroseconds,
    required this.metrics,
  });

  /// Stable benchmark name.
  final String name;

  /// Human-readable benchmark purpose.
  final String description;

  /// Number of measured iterations.
  final int iterations;

  /// Number of unmeasured warmup iterations.
  final int warmupIterations;

  /// Total measured elapsed wall-clock time.
  final int elapsedMicroseconds;

  /// Scenario-specific numeric and string metrics.
  final Map<String, Object?> metrics;

  /// Average elapsed wall-clock microseconds per measured iteration.
  double get microsecondsPerIteration => elapsedMicroseconds / iterations;

  /// Converts this measurement to benchmark JSON.
  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        'description': description,
        'iterations': iterations,
        'warmupIterations': warmupIterations,
        'elapsedMicroseconds': elapsedMicroseconds,
        'microsecondsPerIteration': microsecondsPerIteration,
        'metrics': metrics,
      };
}

/// Complete benchmark suite output.
final class BenchmarkSuiteResult {
  /// Creates benchmark suite output.
  const BenchmarkSuiteResult({
    required this.packageName,
    required this.mode,
    required this.generatedAt,
    required this.runtime,
    required this.results,
  });

  /// Name of the package being benchmarked.
  final String packageName;

  /// Benchmark mode, for example `smoke` or `full`.
  final String mode;

  /// UTC timestamp when the benchmark suite completed.
  final DateTime generatedAt;

  /// Runtime metadata for this benchmark process.
  final BenchmarkRuntime runtime;

  /// Measurements emitted by this run.
  final List<BenchmarkMeasurement> results;

  /// Converts this suite to benchmark JSON.
  Map<String, Object?> toJson() {
    final totalElapsedMicroseconds = results.fold<int>(
      0,
      (total, measurement) => total + measurement.elapsedMicroseconds,
    );

    return <String, Object?>{
      'schemaVersion': benchmarkSchemaVersion,
      'package': packageName,
      'mode': mode,
      'generatedAt': generatedAt.toIso8601String(),
      'runtime': runtime.toJson(),
      'summary': <String, Object?>{
        'benchmarkCount': results.length,
        'totalElapsedMicroseconds': totalElapsedMicroseconds,
      },
      'results': <Object?>[
        for (final measurement in results) measurement.toJson(),
      ],
    };
  }

  /// Encodes this suite as JSON.
  String encode({bool pretty = false}) {
    final encoder =
        pretty ? const JsonEncoder.withIndent('  ') : const JsonEncoder();

    return encoder.convert(toJson());
  }
}
