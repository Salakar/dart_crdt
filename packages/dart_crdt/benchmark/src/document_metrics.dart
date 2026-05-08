import 'dart:convert';

import 'package:dart_crdt/src/doc/doc.dart';
import 'package:dart_crdt/src/sync/state_update.dart';

/// Captures document-level benchmark metrics.
Map<String, Object?> benchmarkDocumentMetrics(
  Doc doc, {
  required int payloadBytes,
}) {
  final updateV1 = encodeStateAsUpdate(doc);
  final updateV2 = encodeStateAsUpdateV2(doc);
  final rootMetadataBytes = jsonEncode(doc.toJson()).length;

  return <String, Object?>{
    'documentSizeBytes': rootMetadataBytes + payloadBytes,
    'documentPayloadBytes': payloadBytes,
    'documentRootMetadataBytes': rootMetadataBytes,
    'structCount': benchmarkStructCount(doc),
    'updateBytesV1': updateV1.length,
    'updateBytesV2': updateV2.length,
  };
}

/// Counts structs currently stored in [doc].
int benchmarkStructCount(Doc doc) {
  var count = 0;
  for (final client in doc.store.clients) {
    count += doc.store.structsFor(client).length;
  }

  return count;
}
