import 'package:test/test.dart';

import '../../../benchmark/src/benchmark_result.dart';
import '../../../benchmark/src/benchmark_runner.dart';
import '../../../benchmark/src/benchmark_thresholds.dart';

void main() {
  group('benchmark smoke thresholds', () {
    test('baseline fixture covers every smoke benchmark exactly once', () {
      final thresholds = loadBenchmarkThresholds(defaultSmokeThresholdPath);
      final benchmarkNames = buildBenchmarkCases(
        BenchmarkMode.smoke,
      ).map((benchmarkCase) => benchmarkCase.name).toSet();

      expect(thresholds.mode, BenchmarkMode.smoke.name);
      expect(thresholds.benchmarkNames.toSet(), benchmarkNames);
    });

    test('full fixture covers every scheduled benchmark exactly once', () {
      final thresholds = loadBenchmarkThresholds(defaultFullThresholdPath);
      final benchmarkNames = buildBenchmarkCases(
        BenchmarkMode.full,
      ).map((benchmarkCase) => benchmarkCase.name).toSet();

      expect(thresholds.mode, BenchmarkMode.full.name);
      expect(thresholds.benchmarkNames.toSet(), benchmarkNames);
    });

    test('validator reports missing, unused, and slow benchmarks', () {
      final suite = BenchmarkSuiteResult(
        packageName: 'dart_crdt',
        mode: 'smoke',
        generatedAt: DateTime.utc(2026, 5, 8),
        runtime: const BenchmarkRuntime(
          dartVersion: 'Dart VM',
          operatingSystem: 'macos',
          numberOfProcessors: 8,
        ),
        results: const <BenchmarkMeasurement>[
          BenchmarkMeasurement(
            name: 'slow',
            description: 'Slow benchmark.',
            iterations: 1,
            warmupIterations: 0,
            elapsedMicroseconds: 20,
            metrics: <String, Object?>{},
          ),
          BenchmarkMeasurement(
            name: 'missing',
            description: 'Missing benchmark.',
            iterations: 1,
            warmupIterations: 0,
            elapsedMicroseconds: 1,
            metrics: <String, Object?>{},
          ),
        ],
      );
      final thresholds = BenchmarkThresholds(
        mode: 'smoke',
        thresholds: const <String, BenchmarkThreshold>{
          'slow': BenchmarkThreshold(maxMicrosecondsPerIteration: 10),
          'unused': BenchmarkThreshold(maxMicrosecondsPerIteration: 10),
        },
      );

      final failures = validateBenchmarkThresholds(suite, thresholds);

      expect(failures.map((failure) => failure.message), [
        contains('slow averaged'),
        contains('No smoke threshold configured for missing'),
        contains('Smoke threshold for unused was not used'),
      ]);
    });
  });
}
