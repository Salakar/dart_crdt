import 'package:dart_crdt/src/attribution/attribution_manager.dart';
import 'package:dart_crdt/src/attribution/diff_snapshot_attribution.dart';
import 'package:dart_crdt/src/content/content.dart';
import 'package:dart_crdt/src/doc/doc.dart';
import 'package:dart_crdt/src/metadata/content_attribute.dart';
import 'package:dart_crdt/src/metadata/id_map.dart';
import 'package:dart_crdt/src/structs/id.dart';
import 'package:dart_crdt/src/sync/apply_update.dart';
import 'package:dart_crdt/src/sync/state_update.dart';
import 'package:dart_crdt/src/undo/undo_manager.dart';

import 'advanced_fixtures.dart';
import 'advanced_shape.dart';
import 'benchmark_case.dart';
import 'document_metrics.dart';

/// Builds undo/redo and attribution benchmark cases.
List<BenchmarkCase> buildUndoAttributionCases(AdvancedShape shape) {
  return <BenchmarkCase>[
    _undoRedoStack(shape),
    _attributionDiffRenderAcceptRejectFilter(shape),
  ];
}

BenchmarkCase _undoRedoStack(AdvancedShape shape) {
  return BenchmarkCase(
    name: 'advanced_undo_redo_stack',
    description: 'Create undo stack items, undo, redo, and clear stacks.',
    work: () {
      final result = _runUndoWorkload(shape);
      if (result.finalText.isEmpty || result.clearedUndoCount == 0) {
        throw StateError('Expected undo/redo workload to mutate stacks.');
      }
    },
    metrics: () {
      final result = _runUndoWorkload(shape);
      return <String, Object?>{
        ...benchmarkDocumentMetrics(
          result.doc,
          payloadBytes: result.finalText.length,
        ),
        'operationCount': shape.undoOperations * 3,
        'clearedUndoCount': result.clearedUndoCount,
        'clearedRedoCount': result.clearedRedoCount,
        'finalTextLength': result.finalText.length,
      };
    },
  );
}

BenchmarkCase _attributionDiffRenderAcceptRejectFilter(AdvancedShape shape) {
  return BenchmarkCase(
    name: 'advanced_attribution_diff_render_accept_reject_filter',
    description: 'Diff, render, accept, reject, and filter attributions.',
    work: () {
      final result = _runAttributionWorkload(shape);
      if (result.acceptedText.isEmpty || result.renderedSegments == 0) {
        throw StateError('Expected attribution workload output.');
      }
    },
    metrics: () {
      final result = _runAttributionWorkload(shape);
      return <String, Object?>{
        ...benchmarkDocumentMetrics(
          result.acceptedDoc,
          payloadBytes: result.acceptedText.length + result.filteredRangeCount,
        ),
        'operationCount': 7,
        'renderedSegments': result.renderedSegments,
        'acceptedTextLength': result.acceptedText.length,
        'rejectedTextLength': result.rejectedText.length,
        'filteredRangeCount': result.filteredRangeCount,
      };
    },
  );
}

final class _UndoResult {
  const _UndoResult({
    required this.doc,
    required this.finalText,
    required this.clearedUndoCount,
    required this.clearedRedoCount,
  });

  final Doc doc;
  final String finalText;
  final int clearedUndoCount;
  final int clearedRedoCount;
}

final class _AttributionResult {
  const _AttributionResult({
    required this.acceptedDoc,
    required this.acceptedText,
    required this.rejectedText,
    required this.renderedSegments,
    required this.filteredRangeCount,
  });

  final Doc acceptedDoc;
  final String acceptedText;
  final String rejectedText;
  final int renderedSegments;
  final int filteredRangeCount;
}

_UndoResult _runUndoWorkload(AdvancedShape shape) {
  final doc = Doc(gc: false, clientId: ClientId(40));
  final manager = UndoManager(doc);
  for (var index = 0; index < shape.undoOperations; index += 1) {
    applyUpdate(
      doc,
      encodeStateAsUpdate(_singleTextDoc(41 + index, benchmarkText(1))),
    );
    manager.stopCapturing();
  }

  var undoCount = 0;
  while (manager.undo() != null) {
    undoCount += 1;
  }
  var redoCount = 0;
  while (manager.redo() != null) {
    redoCount += 1;
  }
  final undoStackCount = manager.undoStack.length;
  final redoStackCount = manager.redoStack.length;
  manager.clear();
  return _UndoResult(
    doc: doc,
    finalText: benchmarkRootText(doc),
    clearedUndoCount: undoStackCount + undoCount,
    clearedRedoCount: redoStackCount + redoCount,
  );
}

_AttributionResult _runAttributionWorkload(AdvancedShape shape) {
  final previous = Doc(gc: false);
  final next = Doc(gc: false, clientId: ClientId(60));
  final text = benchmarkText(shape.attributionLength);
  applyUpdate(next, encodeStateAsUpdate(_singleTextDoc(61, text)));
  final attributions = Attributions(
    inserts: IdMap()
      ..add(
        benchmarkId(61, 0),
        length: text.length,
        attributes: <ContentAttribute>[ContentAttribute('user', 'alice')],
      ),
  );
  final manager = createAttributionManagerFromDiff(
    previous,
    next,
    attributions: attributions,
  );
  final rendered = manager.readContent(
    client: ClientId(61),
    clock: Clock(0),
    deleted: false,
    content: ContentString(text),
  );
  manager.acceptChanges(benchmarkId(61, 0), benchmarkId(61, text.length - 1));

  final rejectPrevious = Doc(gc: false);
  final rejectNext = Doc(gc: false);
  applyUpdate(rejectNext, encodeStateAsUpdate(_singleTextDoc(62, text)));
  final rejectManager = createAttributionManagerFromDiff(
    rejectPrevious,
    rejectNext,
    attributions: attributions,
  );
  rejectManager.rejectAllChanges();
  final filtered = attributions.filter(
    insertPredicate: (attrs) => attrs.any((attr) => attr.name == 'user'),
  );

  return _AttributionResult(
    acceptedDoc: previous,
    acceptedText: benchmarkRootText(previous),
    rejectedText: benchmarkRootText(rejectNext),
    renderedSegments: rendered.length,
    filteredRangeCount: _idMapRangeCount(filtered.inserts),
  );
}

Doc _singleTextDoc(int client, String text) {
  final doc = Doc(gc: false, clientId: ClientId(client));
  doc.store.add(
    benchmarkTextItem(
      doc: doc,
      client: client,
      clock: 0,
      text: text,
    ),
  );
  return doc;
}

int _idMapRangeCount(IdMap map) {
  var count = 0;
  map.forEach((_, __) => count += 1);
  return count;
}
