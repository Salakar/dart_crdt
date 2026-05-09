part of 'doc.dart';

void _syncRootTextFromStoreIfNeeded(SharedType type) {
  if (type.kind != SharedTypeKind.text && type.kind != SharedTypeKind.xmlText) {
    return;
  }
  final rootKey = _rootKeyFor(type);
  final document = type.doc;
  if (document == null || rootKey == null) {
    return;
  }
  final values = _rootTextValues(document.itemParentForKey(rootKey));
  if (_sameTextValues(type._sequence, values)) {
    return;
  }
  type._sequence
    ..clear()
    ..addAll(values);
  type._textAttributes
    ..clear()
    ..addAll(
      List<DeltaAttributes>.filled(values.length, DeltaAttributes.empty),
    );
  type._bindSequenceChildren();
  type._searchMarkers.clear();
}

String? _rootKeyFor(SharedType type) {
  final document = type.doc;
  if (document == null || !type.isRoot) {
    return null;
  }
  for (final entry in document.share.entries) {
    if (identical(entry.value, type)) {
      return entry.key.isEmpty ? null : entry.key;
    }
  }
  return type.name.isEmpty ? null : type.name;
}

List<Object?> _rootTextValues(ItemParent parent) {
  final values = <Object?>[];
  for (final item in parent.items()) {
    if (item.deleted || !item.countable) {
      continue;
    }
    switch (item.content) {
      case ContentString(:final value):
        values.addAll(_unicodeScalars(value));
      case ContentType(:final sharedType):
        values.add(sharedType);
      case final content:
        values.addAll(content.content);
    }
  }
  return values;
}

bool _sameTextValues(List<Object?> left, List<Object?> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (!_sameTextValue(left[index], right[index])) {
      return false;
    }
  }
  return true;
}

bool _sameTextValue(Object? left, Object? right) {
  if (left is Map && right is Map) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) ||
          !_sameTextValue(entry.value, right[entry.key])) {
        return false;
      }
    }
    return true;
  }
  if (left is List && right is List) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (!_sameTextValue(left[index], right[index])) {
        return false;
      }
    }
    return true;
  }
  return left == right;
}
