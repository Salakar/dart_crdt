part of 'apply_update.dart';

void _validateUpdateBytes(List<int> update, int version) {
  final decoder = _decoderFor(update, version);
  final scratch = Doc(clientId: ClientId(0), guid: 'update-preflight');
  final clientCount = readVarUint(_restReader(decoder));
  for (var clientIndex = 0; clientIndex < clientCount; clientIndex += 1) {
    final structCount = readVarUint(_restReader(decoder));
    final client = _readClient(decoder);
    var clock = Clock(readVarUint(_restReader(decoder)));
    for (var index = 0; index < structCount; index += 1) {
      final struct = _readStruct(
        decoder,
        scratch,
        Id(client: client, clock: clock),
      );
      clock = Clock(struct.end);
    }
  }
  _readDeleteSet(decoder);
  _requireRestDone(decoder);
}
