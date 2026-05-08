import 'benchmark_case.dart';
import 'benchmark_runner.dart';
import 'collection_scenarios.dart';
import 'collection_tree_shape.dart';
import 'tree_scenarios.dart';

/// Builds collection and tree benchmark cases for [mode].
List<BenchmarkCase> buildCollectionTreeCases(BenchmarkMode mode) {
  final shape = CollectionTreeShape.forMode(mode);

  return <BenchmarkCase>[
    ...buildCollectionCases(shape),
    ...buildTreeCases(shape),
  ];
}
