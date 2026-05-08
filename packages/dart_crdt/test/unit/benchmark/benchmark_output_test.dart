import 'dart:convert';

import 'package:test/test.dart';

import '../../../benchmark/src/benchmark_result.dart';

void main() {
  group('benchmark output schema', () {
    test('encodes required suite, runtime, summary, and result fields', () {
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
            name: 'sample',
            description: 'Sample benchmark.',
            iterations: 4,
            warmupIterations: 1,
            elapsedMicroseconds: 20,
            metrics: <String, Object?>{
              'wallClockMicroseconds': 20,
              'updateBytesV1': 10,
              'updateBytesV2': 8,
              'structCountBefore': 0,
              'structCountAfter': 2,
              'rssBytesBefore': 100,
              'rssBytesAfter': 120,
              'rssBytesDelta': 20,
            },
          ),
        ],
      );

      final root = _objectMap(jsonDecode(suite.encode(pretty: true)));
      final runtime = _objectMap(root['runtime']);
      final summary = _objectMap(root['summary']);
      final results = _objectList(root['results']);
      final firstResult = _objectMap(results.single);
      final metrics = _objectMap(firstResult['metrics']);

      expect(root['schemaVersion'], benchmarkSchemaVersion);
      expect(root['package'], 'dart_crdt');
      expect(root['mode'], 'smoke');
      expect(root['generatedAt'], '2026-05-08T00:00:00.000Z');
      expect(runtime['dartVersion'], isA<String>());
      expect(runtime['operatingSystem'], isA<String>());
      expect(runtime['numberOfProcessors'], isA<int>());
      expect(summary['benchmarkCount'], 1);
      expect(summary['totalElapsedMicroseconds'], 20);
      expect(firstResult['name'], 'sample');
      expect(firstResult['description'], 'Sample benchmark.');
      expect(firstResult['iterations'], 4);
      expect(firstResult['warmupIterations'], 1);
      expect(firstResult['elapsedMicroseconds'], 20);
      expect(firstResult['microsecondsPerIteration'], 5.0);
      expect(metrics['wallClockMicroseconds'], 20);
      expect(metrics['updateBytesV1'], 10);
      expect(metrics['updateBytesV2'], 8);
      expect(metrics['structCountBefore'], 0);
      expect(metrics['structCountAfter'], 2);
      expect(metrics['rssBytesBefore'], 100);
      expect(metrics['rssBytesAfter'], 120);
      expect(metrics['rssBytesDelta'], 20);
    });
  });
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }

  fail('Expected object map, got ${value.runtimeType}.');
}

List<Object?> _objectList(Object? value) {
  if (value is List<Object?>) {
    return value;
  }

  fail('Expected object list, got ${value.runtimeType}.');
}
