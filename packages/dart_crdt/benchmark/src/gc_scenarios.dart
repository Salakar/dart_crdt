import 'package:dart_crdt/src/doc/doc.dart';
import 'package:dart_crdt/src/metadata/id_set.dart';
import 'package:dart_crdt/src/structs/id.dart';
import 'package:dart_crdt/src/sync/apply_update.dart';
import 'package:dart_crdt/src/sync/state_update.dart';

import 'advanced_fixtures.dart';
import 'advanced_shape.dart';
import 'benchmark_case.dart';
import 'document_metrics.dart';

/// Builds garbage-collection benchmark cases.
List<BenchmarkCase> buildGcCases(AdvancedShape shape) {
  return <BenchmarkCase>[
    _gcEnabledVsDisabled(shape),
  ];
}

BenchmarkCase _gcEnabledVsDisabled(AdvancedShape shape) {
  return BenchmarkCase(
    name: 'advanced_gc_enabled_vs_disabled',
    description: 'Compare GC enabled and disabled delete-heavy workloads.',
    work: () {
      final result = _runGcWorkload(shape);
      if (result.enabledDeletedPayloads == 0 ||
          result.disabledRetainedPayloads == 0) {
        throw StateError('Expected GC and non-GC delete outputs.');
      }
    },
    metrics: () {
      final result = _runGcWorkload(shape);
      return <String, Object?>{
        ...benchmarkDocumentMetrics(
          result.enabled,
          payloadBytes: result.update.length + result.disabledRetainedPayloads,
        ),
        'operationCount': shape.gcItems,
        'structCountBeforeCompaction': result.enabledBeforeCompaction,
        'structCountAfterCompaction': result.enabledAfterCompaction,
        'disabledStructCount': result.disabledStructCount,
        'enabledDeletedPayloads': result.enabledDeletedPayloads,
        'disabledRetainedPayloads': result.disabledRetainedPayloads,
      };
    },
  );
}

final class _GcResult {
  const _GcResult({
    required this.enabled,
    required this.update,
    required this.enabledBeforeCompaction,
    required this.enabledAfterCompaction,
    required this.disabledStructCount,
    required this.enabledDeletedPayloads,
    required this.disabledRetainedPayloads,
  });

  final Doc enabled;
  final List<int> update;
  final int enabledBeforeCompaction;
  final int enabledAfterCompaction;
  final int disabledStructCount;
  final int enabledDeletedPayloads;
  final int disabledRetainedPayloads;
}

_GcResult _runGcWorkload(AdvancedShape shape) {
  final source = _deletedSource(shape);
  final update = encodeStateAsUpdate(source);
  var beforeCompaction = 0;
  final enabled = Doc();
  enabled.afterTransaction.add((_) {
    beforeCompaction = benchmarkStructCount(enabled);
  });
  applyUpdate(enabled, update);

  final disabled = Doc(gc: false);
  applyUpdate(disabled, update);

  return _GcResult(
    enabled: enabled,
    update: update,
    enabledBeforeCompaction: beforeCompaction,
    enabledAfterCompaction: benchmarkStructCount(enabled),
    disabledStructCount: benchmarkStructCount(disabled),
    enabledDeletedPayloads: benchmarkDeletedContentCount(enabled),
    disabledRetainedPayloads: benchmarkDeletedStringContentCount(disabled),
  );
}

Doc _deletedSource(AdvancedShape shape) {
  final doc = Doc(gc: false, clientId: ClientId(70));
  for (var index = 0; index < shape.gcItems; index += 1) {
    doc.store.add(
      benchmarkTextItem(
        doc: doc,
        client: 70,
        clock: index,
        text: benchmarkText(1),
      ),
    );
  }
  if (shape.gcItems > 0) {
    doc.store.addPendingDeleteSet(
      IdSet()..add(benchmarkId(70, 0), length: shape.gcItems),
    );
  }
  return doc;
}
