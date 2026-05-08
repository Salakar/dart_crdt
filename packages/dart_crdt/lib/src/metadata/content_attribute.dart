/// Immutable content attribution values.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../binary/any_value.dart';

/// Metadata attached to a client-local content range.
final class ContentAttribute {
  /// Creates an attribute by converting [value] to an any-value.
  factory ContentAttribute(String name, Object? value) {
    return ContentAttribute.fromAny(
      name: name,
      value: AnyValue.fromObject(value),
    );
  }

  /// Creates an attribute from a pre-built any-value [value].
  ContentAttribute.fromAny({
    required this.name,
    required this.value,
  });

  /// The attribute name.
  final String name;

  /// The attribute payload.
  final AnyValue value;

  late final String _stableKey = _attributeKey(name, value);

  /// A deterministic content key for this attribute.
  String get stableKey => _stableKey;

  /// A deterministic short hash for this attribute.
  String get stableHash => _fnv64Hex(_stableKey);

  /// Converts this attribute to a JSON-compatible object where possible.
  Map<String, Object?> toJson() => {
        'name': name,
        'value': value.toObject(),
      };

  @override
  bool operator ==(Object other) {
    return other is ContentAttribute &&
        name == other.name &&
        value == other.value;
  }

  @override
  int get hashCode => Object.hash(name, value);

  @override
  String toString() => '$name=${value.toObject()}';
}

/// Returns unique attributes sorted by deterministic content identity.
List<ContentAttribute> normalizeContentAttributes(
  Iterable<ContentAttribute> attributes,
) {
  final byKey = <String, ContentAttribute>{};
  for (final attribute in attributes) {
    byKey.putIfAbsent(attribute.stableKey, () => attribute);
  }

  final normalized = byKey.values.toList()
    ..sort((left, right) => left.stableKey.compareTo(right.stableKey));
  return List.unmodifiable(normalized);
}

/// Returns whether two normalized attribute lists describe the same set.
bool contentAttributesEqual(
  List<ContentAttribute> left,
  List<ContentAttribute> right,
) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

String _attributeKey(String name, AnyValue value) {
  return 'attr:${_stringKey(name)}:${_valueKey(value)}';
}

String _valueKey(AnyValue value) {
  return switch (value) {
    JsonNull() => 'n',
    JsonBool(value: final boolValue) => 'b:${boolValue ? 1 : 0}',
    JsonNumber(value: final number) => _numberKey(number),
    JsonString(value: final string) => 's:${_stringKey(string)}',
    JsonList(values: final values) => _listKey(values),
    JsonMap(entries: final entries) => _jsonMapKey(entries),
    AnyList(values: final values) => _listKey(values),
    AnyMap(entries: final entries) => _anyMapKey(entries),
    AnyBinary(bytes: final bytes) => 'x:${base64UrlEncode(bytes)}',
  };
}

String _numberKey(num number) {
  if (number == 0) {
    return 'i:0';
  }
  if (number is int) {
    return 'i:$number';
  }
  if (number % 1 == 0) {
    return 'i:${number.toInt()}';
  }
  return 'd:${number.toString()}';
}

String _listKey(Iterable<AnyValue> values) {
  return 'l:[${values.map(_valueKey).join(',')}]';
}

String _jsonMapKey(Map<String, JsonValue> entries) {
  return _mapKey({
    for (final entry in entries.entries) entry.key: entry.value,
  });
}

String _anyMapKey(Map<String, AnyValue> entries) {
  return _mapKey(entries);
}

String _mapKey(Map<String, AnyValue> entries) {
  final keys = entries.keys.toList()..sort();
  final parts = <String>[
    for (final key in keys) '${_stringKey(key)}:${_valueKey(entries[key]!)}',
  ];
  return 'm:{${parts.join(',')}}';
}

String _stringKey(String value) {
  return base64UrlEncode(utf8.encode(value));
}

String _fnv64Hex(String value) {
  const mask = 0xffffffffffffffff;
  var hash = 0xcbf29ce484222325;
  for (final byte in Uint8List.fromList(utf8.encode(value))) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}
