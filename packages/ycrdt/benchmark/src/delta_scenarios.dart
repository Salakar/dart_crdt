import 'dart:convert';
import 'dart:math';

import 'package:ycrdt/src/content/content.dart';
import 'package:ycrdt/src/delta/delta_operation.dart';
import 'package:ycrdt/src/doc/doc.dart';

import 'benchmark_case.dart';
import 'text_delta_shape.dart';

/// Builds delta benchmark cases for [shape].
List<BenchmarkCase> buildDeltaCases(TextDeltaShape shape) => <BenchmarkCase>[
      _deltaApplyShallow(shape),
      _deltaRenderShallow(shape),
      _deltaRenderDeep(shape),
    ];

BenchmarkCase _deltaApplyShallow(TextDeltaShape shape) {
  return BenchmarkCase(
    name: 'delta_apply_shallow',
    description:
        'Apply a shallow text delta with retains, inserts, and deletes.',
    work: () {
      final text = _deltaApplyTarget(shape);
      text.applyDelta(_buildApplyDelta(shape));
      expectBenchmarkText(text);
    },
    metrics: () {
      final delta = _buildApplyDelta(shape);
      final text = _deltaApplyTarget(shape)..applyDelta(delta);
      return <String, Object?>{
        ...benchmarkTextMetrics(text, shape.deltaOps),
        'deltaOperationCount': delta.operations.length,
      };
    },
  );
}

BenchmarkCase _deltaRenderShallow(TextDeltaShape shape) {
  return BenchmarkCase(
    name: 'delta_render_shallow',
    description: 'Render a shallow delta to stable JSON and debug strings.',
    work: () => _expectDeltaRender(_buildRenderDelta(shape)),
    metrics: () => _deltaMetrics(_buildRenderDelta(shape)),
  );
}

BenchmarkCase _deltaRenderDeep(TextDeltaShape shape) {
  return BenchmarkCase(
    name: 'delta_render_deep',
    description: 'Render nested child and attribute modifications as JSON.',
    work: () => _expectDeltaRender(_buildDeepDelta(shape)),
    metrics: () => _deltaMetrics(_buildDeepDelta(shape)),
  );
}

SharedType _deltaApplyTarget(TextDeltaShape shape) {
  return SharedType(kind: SharedTypeKind.text)
    ..insertText(0, benchmarkPatternText(shape.baseLength));
}

Delta _buildApplyDelta(TextDeltaShape shape) {
  final builder = DeltaBuilder();
  var consumed = 0;
  for (var index = 0;
      index < shape.deltaOps && consumed < shape.baseLength;
      index += 1) {
    final retainLength = min(3, shape.baseLength - consumed);
    builder.retain(
      length: retainLength,
      attributes: benchmarkFormatAttributes(index),
    );
    consumed += retainLength;
    builder.insertText(
      text: benchmarkToken(index),
      attributes: benchmarkFormatAttributes(index + 1),
    );
    if (index.isEven && consumed < shape.baseLength) {
      builder.delete(1);
      consumed += 1;
    }
  }
  return builder.done();
}

Delta _buildRenderDelta(TextDeltaShape shape) {
  final builder = DeltaBuilder();
  for (var index = 0; index < shape.deltaOps; index += 1) {
    builder.insertText(
      text: benchmarkChunk(index, shape.fragmentSize),
      attributes: benchmarkFormatAttributes(index),
    );
    if (index % 4 == 0) {
      builder.retain(
        length: 1,
        attributes: benchmarkFormatAttributes(index + 1),
      );
    }
  }
  return builder.done();
}

Delta _buildDeepDelta(TextDeltaShape shape) {
  var delta = Delta(<DeltaOperation>[
    DeltaInsertText(text: benchmarkChunk(0, shape.fragmentSize)),
  ]);
  for (var depth = 0; depth < shape.deepDeltaDepth; depth += 1) {
    final builder = DeltaBuilder()
      ..modifyChild(delta: delta, attributes: benchmarkFormatAttributes(depth))
      ..setAttribute(key: 'level_$depth', value: depth);
    delta = builder.done();
  }
  return delta;
}

Map<String, Object?> _deltaMetrics(Delta delta) {
  final json = delta.toJson();
  return <String, Object?>{
    'deltaOperationCount': delta.operations.length,
    'deltaLength': delta.length,
    'jsonBytes': jsonEncode(json).length,
    'debugBytes': delta.toDebugString().length,
  };
}

void _expectDeltaRender(Delta delta) {
  final json = delta.toJson();
  if (delta.operations.isEmpty || !json.containsKey('ops')) {
    throw StateError('Expected rendered delta JSON.');
  }
  delta.toDebugString();
}
