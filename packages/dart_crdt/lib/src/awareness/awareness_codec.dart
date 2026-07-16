part of 'awareness.dart';

enum _AwarenessChangeKind { added, updated, removed }

bool _isNewer(AwarenessState next, AwarenessState? previous) {
  return previous == null ||
      next.clock > previous.clock ||
      (next.clock == previous.clock && next.isRemoved && !previous.isRemoved);
}

_AwarenessChangeKind? _changeKind(
  AwarenessState? previous,
  AwarenessState next,
) {
  if (previous == next) {
    return null;
  }
  if (previous == null || previous.isRemoved) {
    return next.isRemoved ? null : _AwarenessChangeKind.added;
  }
  if (next.isRemoved) {
    return _AwarenessChangeKind.removed;
  }
  return _AwarenessChangeKind.updated;
}

AwarenessState _readAwarenessState(ByteReader reader) {
  final clientId = ClientId(readVarUint(reader));
  final clock = readVarUint(reader);
  final hasState = reader.readByte();
  if (hasState == 0) {
    return AwarenessState(clientId: clientId, clock: clock, state: null);
  }
  if (hasState != 1) {
    throw FormatException('Invalid awareness state marker $hasState.');
  }
  final value = readJsonValue(reader);
  if (value is! JsonMap) {
    throw const FormatException('Awareness state must be a JSON object.');
  }
  return AwarenessState(clientId: clientId, clock: clock, state: value);
}

JsonMap _jsonMap(Map<String, Object?> state) {
  return JsonMap(
    state.map((key, value) => MapEntry(key, JsonValue.fromObject(value))),
  );
}
