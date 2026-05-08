import 'benchmark_runner.dart';

/// Workload dimensions for advanced feature benchmarks.
final class AdvancedShape {
  /// Creates workload dimensions.
  const AdvancedShape({
    required this.relativeItems,
    required this.snapshotItems,
    required this.undoOperations,
    required this.attributionLength,
    required this.gcItems,
    required this.chunkSize,
  });

  /// Returns workload dimensions for [mode].
  factory AdvancedShape.forMode(BenchmarkMode mode) => switch (mode) {
        BenchmarkMode.smoke => const AdvancedShape(
            relativeItems: 40,
            snapshotItems: 32,
            undoOperations: 12,
            attributionLength: 36,
            gcItems: 24,
            chunkSize: 4,
          ),
        BenchmarkMode.full => const AdvancedShape(
            relativeItems: 220,
            snapshotItems: 120,
            undoOperations: 48,
            attributionLength: 120,
            gcItems: 96,
            chunkSize: 6,
          ),
      };

  /// Number of structs used by relative-position workloads.
  final int relativeItems;

  /// Number of structs used by snapshot workloads.
  final int snapshotItems;

  /// Number of undoable transactions.
  final int undoOperations;

  /// Text length used by attribution workloads.
  final int attributionLength;

  /// Number of deleted structs used by garbage-collection workloads.
  final int gcItems;

  /// Number of text positions per generated item.
  final int chunkSize;
}
