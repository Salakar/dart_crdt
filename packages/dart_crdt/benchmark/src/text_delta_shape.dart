import 'package:dart_crdt/src/delta/delta_operation.dart';
import 'package:dart_crdt/src/doc/doc.dart';

import 'benchmark_runner.dart';

/// Workload dimensions for text and delta benchmark scenarios.
final class TextDeltaShape {
  /// Creates workload dimensions.
  const TextDeltaShape({
    required this.operations,
    required this.randomOps,
    required this.baseLength,
    required this.fragments,
    required this.fragmentSize,
    required this.deltaOps,
    required this.deepDeltaDepth,
  });

  /// Returns workload dimensions for [mode].
  factory TextDeltaShape.forMode(BenchmarkMode mode) => switch (mode) {
        BenchmarkMode.smoke => const TextDeltaShape(
            operations: 48,
            randomOps: 72,
            baseLength: 96,
            fragments: 72,
            fragmentSize: 4,
            deltaOps: 32,
            deepDeltaDepth: 8,
          ),
        BenchmarkMode.full => const TextDeltaShape(
            operations: 256,
            randomOps: 420,
            baseLength: 768,
            fragments: 720,
            fragmentSize: 6,
            deltaOps: 180,
            deepDeltaDepth: 32,
          ),
      };

  /// Number of deterministic insert operations.
  final int operations;

  /// Number of deterministic random edit operations.
  final int randomOps;

  /// Base text length for delta application targets.
  final int baseLength;

  /// Number of formatted fragments in fragmented text workloads.
  final int fragments;

  /// Number of text positions per chunk or fragment.
  final int fragmentSize;

  /// Number of delta operation groups.
  final int deltaOps;

  /// Depth of nested child-modification deltas.
  final int deepDeltaDepth;
}

/// Creates deterministic formatting attributes for benchmark scenarios.
DeltaAttributes benchmarkFormatAttributes(int index) {
  return DeltaAttributes.fromJson(<String, Object?>{
    'bold': index.isEven,
    'color': 'c${index % 7}',
  });
}

/// Creates deterministic text with [length] Unicode scalar positions.
String benchmarkPatternText(int length) {
  return String.fromCharCodes(
    List<int>.generate(length, (index) => 'a'.codeUnitAt(0) + (index % 26)),
  );
}

/// Creates a deterministic repeated-character chunk.
String benchmarkChunk(int index, int size) {
  return String.fromCharCodes(
    List<int>.filled(size, 'a'.codeUnitAt(0) + (index % 26)),
  );
}

/// Creates a deterministic one-character token.
String benchmarkToken(int index) => benchmarkChunk(index, 1);

/// Captures shared text metrics for benchmark output.
Map<String, Object?> benchmarkTextMetrics(
  SharedType text,
  int operationCount,
) {
  return <String, Object?>{
    'operationCount': operationCount,
    'textLength': text.length,
    'plainTextLength': text.toPlainText().runes.length,
    'deltaOperationCount': text.toDelta().operations.length,
    'searchMarkerCount': text.searchMarkers.length,
  };
}

/// Throws if [text] is unexpectedly empty.
void expectBenchmarkText(SharedType text) {
  if (text.isEmpty || text.toPlainText().isEmpty) {
    throw StateError('Expected non-empty text.');
  }
}
