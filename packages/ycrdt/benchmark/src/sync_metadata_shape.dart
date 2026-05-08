import 'benchmark_runner.dart';

/// Workload dimensions for sync and metadata benchmarks.
final class SyncMetadataShape {
  /// Creates workload dimensions.
  const SyncMetadataShape({
    required this.clientCount,
    required this.itemsPerClient,
    required this.chunkSize,
    required this.rangeCount,
    required this.rangeLength,
  });

  /// Returns workload dimensions for [mode].
  factory SyncMetadataShape.forMode(BenchmarkMode mode) => switch (mode) {
        BenchmarkMode.smoke => const SyncMetadataShape(
            clientCount: 4,
            itemsPerClient: 18,
            chunkSize: 5,
            rangeCount: 96,
            rangeLength: 5,
          ),
        BenchmarkMode.full => const SyncMetadataShape(
            clientCount: 10,
            itemsPerClient: 80,
            chunkSize: 8,
            rangeCount: 240,
            rangeLength: 8,
          ),
      };

  /// Number of clients represented in generated updates and metadata.
  final int clientCount;

  /// Number of structs per generated client document.
  final int itemsPerClient;

  /// Number of text positions per generated content struct.
  final int chunkSize;

  /// Number of metadata ranges to generate.
  final int rangeCount;

  /// Number of clocks covered by each generated metadata range.
  final int rangeLength;
}
