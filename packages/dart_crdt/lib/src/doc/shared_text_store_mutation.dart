part of 'doc.dart';

void _insertRootTextValues(
  Transaction transaction,
  SharedType type,
  int index,
  List<Object?> values,
) {
  final parent = _storeParentFor(type);
  if (parent == null || values.isEmpty) {
    return;
  }
  final document = transaction.doc;
  final target = _LocalTextIntegrationTarget(transaction);
  var insertionIndex = index;
  for (final run in _textContentRuns(values)) {
    final origin = _textPositionAt(parent, insertionIndex - 1)?.lastId;
    final rightOrigin = _textPositionAt(parent, insertionIndex)?.firstId;
    _cleanItemBoundaries(
      document.store,
      origin: origin,
      rightOrigin: rightOrigin,
    );
    final item = Item(
      id: Id(
        client: document.clientId,
        clock: document.store.getClock(document.clientId),
      ),
      left: origin == null ? null : document.store.itemContaining(origin),
      origin: origin,
      right: rightOrigin == null
          ? null
          : document.store.itemContaining(rightOrigin),
      rightOrigin: rightOrigin,
      parent: parent,
      content: run.content,
    );
    item.integrate(target);
    if (item.content is ContentType) {
      _integrateNestedValue(transaction, item);
    }
    insertionIndex += run.textLength;
  }
}

void _deleteRootTextRange(
  Transaction transaction,
  SharedType type,
  int index,
  int length,
) {
  final parent = _storeParentFor(type);
  if (parent == null || length == 0) {
    return;
  }
  final document = transaction.doc;
  final target = _LocalTextIntegrationTarget(transaction);
  final deleteEnd = index + length;
  var textIndex = 0;
  for (final item in parent.items()) {
    final itemTextLength = ContentTextIndex.visibleLength(item);
    if (itemTextLength == 0) {
      continue;
    }
    final itemTextEnd = textIndex + itemTextLength;
    final itemDeleteStart = max(index, textIndex);
    final itemDeleteEnd = min(deleteEnd, itemTextEnd);
    if (itemDeleteStart < itemDeleteEnd) {
      final startOffset = ContentTextIndex.clockOffsetAtTextOffset(
        item,
        itemDeleteStart - textIndex,
      );
      final endOffset = ContentTextIndex.clockOffsetAtTextOffset(
        item,
        itemDeleteEnd - textIndex,
      );
      if (endOffset > startOffset) {
        final range = IdRange(
          start: Clock(item.id.clock.value + startOffset),
          length: endOffset - startOffset,
        );
        for (final struct in document.store.structsWithSplitting(
          client: item.id.client,
          range: range,
        )) {
          if (struct is Item && !struct.deleted) {
            struct.delete(target);
          }
        }
      }
    }
    textIndex = itemTextEnd;
    if (textIndex >= deleteEnd) {
      return;
    }
  }
}

List<_TextContentRun> _textContentRuns(List<Object?> values) {
  final runs = <_TextContentRun>[];
  var index = 0;
  while (index < values.length) {
    final value = values[index];
    if (value is String) {
      final buffer = StringBuffer(value);
      var textLength = 1;
      index += 1;
      while (index < values.length && values[index] is String) {
        buffer.write(values[index] as String);
        textLength += 1;
        index += 1;
      }
      runs.add(
        _TextContentRun(
          content: ContentString(buffer.toString()),
          textLength: textLength,
        ),
      );
      continue;
    }
    runs.add(
      _TextContentRun(
        content: value is SharedType ? ContentType(value) : ContentEmbed(value),
        textLength: 1,
      ),
    );
    index += 1;
  }
  return runs;
}

_TextClockPosition? _textPositionAt(ItemParent parent, int index) {
  if (index < 0) {
    return null;
  }
  var remaining = index;
  for (final item in parent.items()) {
    final textLength = ContentTextIndex.visibleLength(item);
    if (textLength == 0) {
      continue;
    }
    if (remaining < textLength) {
      final clockOffset = ContentTextIndex.clockOffsetAtTextOffset(
        item,
        remaining,
      );
      final nextClockOffset = ContentTextIndex.clockOffsetAtTextOffset(
        item,
        remaining + 1,
      );
      return _TextClockPosition(
        item: item,
        clockOffset: clockOffset,
        clockLength: nextClockOffset - clockOffset,
      );
    }
    remaining -= textLength;
  }
  return null;
}

void _cleanItemBoundaries(
  StructStore store, {
  required Id? origin,
  required Id? rightOrigin,
}) {
  if (origin != null) {
    store.cleanEnd(origin);
  }
  if (rightOrigin != null) {
    store.cleanStart(rightOrigin);
  }
}

final class _TextContentRun {
  const _TextContentRun({required this.content, required this.textLength});

  final AbstractContent content;
  final int textLength;
}

final class _TextClockPosition {
  const _TextClockPosition({
    required this.item,
    required this.clockOffset,
    required this.clockLength,
  });

  final Item item;
  final int clockOffset;
  final int clockLength;

  Id get firstId => item.id.advance(clockOffset);

  Id get lastId => item.id.advance(clockOffset + clockLength - 1);
}
