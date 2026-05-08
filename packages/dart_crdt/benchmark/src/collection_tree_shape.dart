import 'benchmark_runner.dart';

/// Workload dimensions for collection and tree benchmarks.
final class CollectionTreeShape {
  /// Creates workload dimensions.
  const CollectionTreeShape({
    required this.operations,
    required this.initialSize,
    required this.keyCount,
    required this.clientCount,
    required this.treeBranches,
    required this.treeLeaves,
  });

  /// Returns workload dimensions for [mode].
  factory CollectionTreeShape.forMode(BenchmarkMode mode) => switch (mode) {
        BenchmarkMode.smoke => const CollectionTreeShape(
            operations: 72,
            initialSize: 24,
            keyCount: 16,
            clientCount: 3,
            treeBranches: 8,
            treeLeaves: 5,
          ),
        BenchmarkMode.full => const CollectionTreeShape(
            operations: 520,
            initialSize: 160,
            keyCount: 96,
            clientCount: 8,
            treeBranches: 64,
            treeLeaves: 12,
          ),
      };

  /// Number of deterministic collection operations.
  final int operations;

  /// Number of initial values inserted before random edits.
  final int initialSize;

  /// Number of hot keys used by map conflict workloads.
  final int keyCount;

  /// Number of simulated clients in conflict workloads.
  final int clientCount;

  /// Number of top-level XML branches.
  final int treeBranches;

  /// Number of XML leaves under each branch.
  final int treeLeaves;
}
