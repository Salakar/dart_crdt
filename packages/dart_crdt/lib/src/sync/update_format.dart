/// Conversion helpers between update encoding formats.
library;

import 'dart:typed_data';

import '../doc/doc.dart';
import 'apply_update.dart';
import 'state_update.dart';

/// Converts a causally complete V1 [update] into a normalized V2 update.
///
/// Unresolved structs are currently omitted during conversion. Retain the
/// source bytes when the update may contain causal gaps.
Uint8List convertUpdateFormatV1ToV2(List<int> update) {
  final doc = Doc();
  applyUpdate(doc, update);
  _dropUnresolvedPending(doc);
  return encodeStateAsUpdateV2(doc);
}

/// Converts a causally complete V2 [update] into a normalized V1 update.
///
/// Unresolved structs are currently omitted during conversion. Retain the
/// source bytes when the update may contain causal gaps.
Uint8List convertUpdateFormatV2ToV1(List<int> update) {
  final doc = Doc();
  applyUpdateV2(doc, update);
  _dropUnresolvedPending(doc);
  return encodeStateAsUpdate(doc);
}

void _dropUnresolvedPending(Doc doc) {
  doc.store
    ..clearPendingStructs()
    ..clearPendingDeleteSet();
}
