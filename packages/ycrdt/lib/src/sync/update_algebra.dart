/// Update merge and diff helpers.
library;

import 'dart:typed_data';

import '../doc/doc.dart';
import 'apply_update.dart';
import 'state_update.dart';

/// Merges V1 [updates] into one normalized V1 update.
Uint8List mergeUpdates(Iterable<List<int>> updates) {
  final doc = Doc();
  for (final update in updates) {
    applyUpdate(doc, update);
  }
  _dropUnresolvedPending(doc);
  return encodeStateAsUpdate(doc);
}

/// Merges V2 [updates] into one normalized V2 update.
Uint8List mergeUpdatesV2(Iterable<List<int>> updates) {
  final doc = Doc();
  for (final update in updates) {
    applyUpdateV2(doc, update);
  }
  _dropUnresolvedPending(doc);
  return encodeStateAsUpdateV2(doc);
}

/// Returns the V1 part of [update] missing from [encodedStateVector].
Uint8List diffUpdate(List<int> update, List<int> encodedStateVector) {
  final doc = Doc();
  applyUpdate(doc, update);
  _dropUnresolvedPending(doc);
  return encodeStateAsUpdate(doc, encodedStateVector);
}

/// Returns the V2 part of [update] missing from [encodedStateVector].
Uint8List diffUpdateV2(List<int> update, List<int> encodedStateVector) {
  final doc = Doc();
  applyUpdateV2(doc, update);
  _dropUnresolvedPending(doc);
  return encodeStateAsUpdateV2(doc, encodedStateVector);
}

void _dropUnresolvedPending(Doc doc) {
  doc.store
    ..clearPendingStructs()
    ..clearPendingDeleteSet();
}
