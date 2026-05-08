import 'advanced_scenarios.dart';
import 'benchmark_case.dart';
import 'benchmark_runner.dart';
import 'collection_tree_scenarios.dart';
import 'sync_metadata_scenarios.dart';
import 'text_delta_scenarios.dart';
import 'update_scenarios.dart';

/// Builds benchmark scenario cases for [mode].
List<BenchmarkCase> buildScenarioCases(BenchmarkMode mode) => <BenchmarkCase>[
      ...buildUpdateEncodingCases(mode),
      ...buildTextAndDeltaCases(mode),
      ...buildCollectionTreeCases(mode),
      ...buildSyncMetadataCases(mode),
      ...buildAdvancedCases(mode),
    ];
