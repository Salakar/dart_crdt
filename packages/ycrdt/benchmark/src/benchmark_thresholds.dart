import 'dart:convert';
import 'dart:io';

import 'benchmark_result.dart';

/// Default smoke benchmark threshold fixture.
const defaultSmokeThresholdPath = 'benchmark/baselines/smoke_thresholds.json';

/// Default full benchmark threshold fixture.
const defaultFullThresholdPath = 'benchmark/baselines/full_thresholds.json';

/// Thresholds loaded from a benchmark baseline fixture.
final class BenchmarkThresholds {
  /// Creates benchmark thresholds.
  BenchmarkThresholds({
    required this.mode,
    required Map<String, BenchmarkThreshold> thresholds,
  }) : thresholds = Map<String, BenchmarkThreshold>.unmodifiable(thresholds);

  /// Creates thresholds from decoded JSON.
  factory BenchmarkThresholds.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != benchmarkSchemaVersion) {
      throw FormatException(
        'Unsupported benchmark threshold schema: ${json['schemaVersion']}.',
      );
    }

    final mode = json['mode'];
    if (mode is! String || mode.isEmpty) {
      throw const FormatException('Benchmark threshold mode is required.');
    }

    final thresholdsJson = _objectMap(json['thresholds'], 'thresholds');
    final thresholds = <String, BenchmarkThreshold>{};
    for (final entry in thresholdsJson.entries) {
      thresholds[entry.key] = BenchmarkThreshold.fromJson(
        _objectMap(entry.value, 'thresholds.${entry.key}'),
      );
    }

    return BenchmarkThresholds(mode: mode, thresholds: thresholds);
  }

  /// Benchmark mode the thresholds apply to.
  final String mode;

  /// Per-benchmark thresholds keyed by benchmark name.
  final Map<String, BenchmarkThreshold> thresholds;

  /// Benchmark names covered by this fixture.
  Iterable<String> get benchmarkNames => thresholds.keys;

  /// Returns the threshold for [name], or `null` if it is not configured.
  BenchmarkThreshold? operator [](String name) => thresholds[name];
}

/// Catastrophic regression threshold for one benchmark.
final class BenchmarkThreshold {
  /// Creates a benchmark threshold.
  const BenchmarkThreshold({
    required this.maxMicrosecondsPerIteration,
    this.reason,
  });

  /// Creates a benchmark threshold from decoded JSON.
  factory BenchmarkThreshold.fromJson(Map<String, Object?> json) {
    final maxMicroseconds = json['maxMicrosecondsPerIteration'];
    if (maxMicroseconds is! num || maxMicroseconds <= 0) {
      throw const FormatException(
        'maxMicrosecondsPerIteration must be a positive number.',
      );
    }

    final reasonValue = json['reason'];
    String? reason;
    if (reasonValue != null) {
      if (reasonValue is! String) {
        throw const FormatException('Threshold reason must be a string.');
      }
      reason = reasonValue;
    }

    return BenchmarkThreshold(
      maxMicrosecondsPerIteration: maxMicroseconds.toDouble(),
      reason: reason,
    );
  }

  /// Maximum allowed average wall-clock microseconds per iteration.
  final double maxMicrosecondsPerIteration;

  /// Human-readable reason for the threshold.
  final String? reason;
}

/// A benchmark threshold validation failure.
final class BenchmarkThresholdFailure {
  /// Creates a threshold validation failure.
  const BenchmarkThresholdFailure(this.message);

  /// Human-readable failure message.
  final String message;

  @override
  String toString() => message;
}

/// Loads benchmark thresholds from [path].
BenchmarkThresholds loadBenchmarkThresholds(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  return BenchmarkThresholds.fromJson(_objectMap(decoded, path));
}

/// Validates [suite] against [thresholds].
List<BenchmarkThresholdFailure> validateBenchmarkThresholds(
  BenchmarkSuiteResult suite,
  BenchmarkThresholds thresholds,
) {
  final failures = <BenchmarkThresholdFailure>[];
  if (suite.mode != thresholds.mode) {
    failures.add(
      BenchmarkThresholdFailure(
        'Benchmark mode ${suite.mode} does not match threshold mode '
        '${thresholds.mode}.',
      ),
    );
  }

  final seen = <String>{};
  for (final measurement in suite.results) {
    seen.add(measurement.name);
    final threshold = thresholds[measurement.name];
    if (threshold == null) {
      failures.add(
        BenchmarkThresholdFailure(
          'No smoke threshold configured for ${measurement.name}.',
        ),
      );
      continue;
    }
    if (measurement.microsecondsPerIteration >
        threshold.maxMicrosecondsPerIteration) {
      failures.add(
        BenchmarkThresholdFailure(
          '${measurement.name} averaged '
          '${measurement.microsecondsPerIteration.toStringAsFixed(2)}us, '
          'above ${threshold.maxMicrosecondsPerIteration.toStringAsFixed(2)}us.',
        ),
      );
    }
  }

  for (final benchmarkName in thresholds.benchmarkNames) {
    if (!seen.contains(benchmarkName)) {
      failures.add(
        BenchmarkThresholdFailure(
          'Smoke threshold for $benchmarkName was not used.',
        ),
      );
    }
  }

  return failures;
}

Map<String, Object?> _objectMap(Object? value, String name) {
  if (value is Map<Object?, Object?>) {
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw FormatException('$name contains a non-string key.');
      }
      result[key] = entry.value;
    }
    return result;
  }

  throw FormatException('$name must be a JSON object.');
}
