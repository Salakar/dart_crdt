import 'dart:math';

import 'package:ycrdt/src/content/content.dart';
import 'package:ycrdt/src/doc/doc.dart';

import 'benchmark_case.dart';
import 'text_delta_shape.dart';

/// Builds shared text benchmark cases for [shape].
List<BenchmarkCase> buildTextCases(TextDeltaShape shape) => <BenchmarkCase>[
      _textSequentialInsert(shape),
      _textAppend(shape),
      _textPrepend(shape),
      _textMiddleInsert(shape),
      _textRandomInsertDeleteFormat(shape),
      _textFragmentedDeltaRender(shape),
    ];

BenchmarkCase _textSequentialInsert(TextDeltaShape shape) {
  return BenchmarkCase(
    name: 'text_sequential_insert',
    description: 'Insert single text tokens at monotonically increasing slots.',
    work: () => expectBenchmarkText(_buildSequentialText(shape)),
    metrics: () => benchmarkTextMetrics(
      _buildSequentialText(shape),
      shape.operations,
    ),
  );
}

BenchmarkCase _textAppend(TextDeltaShape shape) {
  return BenchmarkCase(
    name: 'text_append',
    description: 'Append chunked text content to a shared text value.',
    work: () => expectBenchmarkText(
      _buildChunkedText(shape, _InsertPattern.append),
    ),
    metrics: () => benchmarkTextMetrics(
      _buildChunkedText(shape, _InsertPattern.append),
      shape.operations,
    ),
  );
}

BenchmarkCase _textPrepend(TextDeltaShape shape) {
  return BenchmarkCase(
    name: 'text_prepend',
    description: 'Prepend chunked text content to a shared text value.',
    work: () => expectBenchmarkText(
      _buildChunkedText(shape, _InsertPattern.prepend),
    ),
    metrics: () => benchmarkTextMetrics(
      _buildChunkedText(shape, _InsertPattern.prepend),
      shape.operations,
    ),
  );
}

BenchmarkCase _textMiddleInsert(TextDeltaShape shape) {
  return BenchmarkCase(
    name: 'text_middle_insert',
    description: 'Insert chunked text content into the middle of shared text.',
    work: () => expectBenchmarkText(
      _buildChunkedText(shape, _InsertPattern.middle),
    ),
    metrics: () => benchmarkTextMetrics(
      _buildChunkedText(shape, _InsertPattern.middle),
      shape.operations,
    ),
  );
}

BenchmarkCase _textRandomInsertDeleteFormat(TextDeltaShape shape) {
  return BenchmarkCase(
    name: 'text_random_insert_delete_format',
    description: 'Run deterministic random text insert/delete and formatting.',
    work: () => expectBenchmarkText(_buildRandomEditedText(shape)),
    metrics: () => benchmarkTextMetrics(
      _buildRandomEditedText(shape),
      shape.randomOps,
    ),
  );
}

BenchmarkCase _textFragmentedDeltaRender(TextDeltaShape shape) {
  return BenchmarkCase(
    name: 'text_fragmented_delta_render',
    description: 'Render a large fragmented formatted text value as a delta.',
    work: () {
      final text = _buildFragmentedText(shape);
      final delta = text.toDelta();
      if (delta.operations.isEmpty || text.toPlainText().isEmpty) {
        throw StateError('Expected fragmented delta output.');
      }
    },
    metrics: () => benchmarkTextMetrics(
      _buildFragmentedText(shape),
      shape.fragments,
    ),
  );
}

enum _InsertPattern { append, prepend, middle }

SharedType _buildSequentialText(TextDeltaShape shape) {
  final text = SharedType(kind: SharedTypeKind.text);
  for (var index = 0; index < shape.operations; index += 1) {
    text.insertText(index, benchmarkToken(index));
  }
  return text;
}

SharedType _buildChunkedText(TextDeltaShape shape, _InsertPattern pattern) {
  final text = SharedType(kind: SharedTypeKind.text);
  for (var index = 0; index < shape.operations; index += 1) {
    final insertIndex = switch (pattern) {
      _InsertPattern.append => text.length,
      _InsertPattern.prepend => 0,
      _InsertPattern.middle => text.length ~/ 2,
    };
    text.insertText(insertIndex, benchmarkChunk(index, shape.fragmentSize));
  }
  return text;
}

SharedType _buildRandomEditedText(TextDeltaShape shape) {
  final random = Random(42);
  final text = SharedType(kind: SharedTypeKind.text)
    ..insertText(0, benchmarkPatternText(shape.baseLength));

  for (var index = 0; index < shape.randomOps; index += 1) {
    if (index % 5 == 0 && text.length > 2) {
      final start = random.nextInt(text.length - 1);
      final length = min(4, text.length - start);
      text.format(start, length, benchmarkFormatAttributes(index));
    } else if (index % 3 == 0 && text.length > 1) {
      text.deleteText(random.nextInt(text.length), 1);
    } else {
      text.insertText(random.nextInt(text.length + 1), benchmarkToken(index));
    }
  }
  return text;
}

SharedType _buildFragmentedText(TextDeltaShape shape) {
  final text = SharedType(kind: SharedTypeKind.text);
  for (var index = 0; index < shape.fragments; index += 1) {
    text.insertText(
      text.length,
      benchmarkChunk(index, shape.fragmentSize),
      attributes: benchmarkFormatAttributes(index),
    );
  }
  return text;
}
