/// Update merge and diff helpers.
library;

import 'dart:typed_data';

import '../doc/doc.dart';
import '../structs/abstract_struct.dart';
import '../structs/id.dart';
import 'apply_update.dart';
import 'state_update.dart';
import 'state_vector.dart';
import 'update_inspection.dart';

/// Merges causally complete V1 [updates] into one normalized V1 update.
///
/// This release materializes a temporary document, so unresolved structs that
/// arrive without their dependencies are omitted. Retain the original journal
/// when updates may contain causal gaps.
Uint8List mergeUpdates(Iterable<List<int>> updates) {
  final doc = Doc();
  for (final update in updates) {
    applyUpdate(doc, update);
  }
  _dropUnresolvedPending(doc);
  return encodeStateAsUpdate(doc);
}

/// Merges causally complete V2 [updates] into one normalized V2 update.
///
/// This release materializes a temporary document, so unresolved structs that
/// arrive without their dependencies are omitted. Retain the original journal
/// when updates may contain causal gaps.
Uint8List mergeUpdatesV2(Iterable<List<int>> updates) {
  final doc = Doc();
  for (final update in updates) {
    applyUpdateV2(doc, update);
  }
  _dropUnresolvedPending(doc);
  return encodeStateAsUpdateV2(doc);
}

/// Returns the causally complete V1 part missing from [encodedStateVector].
///
/// Unresolved structs are currently omitted; do not use this as the sole
/// durable copy of an update that may contain causal gaps.
Uint8List diffUpdate(List<int> update, List<int> encodedStateVector) {
  final doc = Doc();
  applyUpdate(doc, update);
  _dropUnresolvedPending(doc);
  return encodeStateAsUpdate(doc, encodedStateVector);
}

/// Returns the causally complete V2 part missing from [encodedStateVector].
///
/// Unresolved structs are currently omitted; do not use this as the sole
/// durable copy of an update that may contain causal gaps.
Uint8List diffUpdateV2(List<int> update, List<int> encodedStateVector) {
  final doc = Doc();
  applyUpdateV2(doc, update);
  _dropUnresolvedPending(doc);
  return encodeStateAsUpdateV2(doc, encodedStateVector);
}

/// Encodes the concrete state prefix represented by a V1 [update].
///
/// A client is included only for clocks that are contiguous from zero. Wire
/// `Skip` framing and any other gap stop that client's prefix. Consequently a
/// target-relative delta that starts above clock zero cannot prove the target's
/// earlier state and contributes no clock by itself; combine this result with
/// the already-known target vector when that context is available.
Uint8List encodeStateVectorFromUpdate(List<int> update) {
  return encodeStateVector(_stateVectorFromUpdate(decodeUpdate(update)));
}

/// Encodes the concrete state prefix represented by a V2 [update].
///
/// A client is included only for clocks that are contiguous from zero. Wire
/// `Skip` framing and any other gap stop that client's prefix. Consequently a
/// target-relative delta that starts above clock zero cannot prove the target's
/// earlier state and contributes no clock by itself; combine this result with
/// the already-known target vector when that context is available.
Uint8List encodeStateVectorFromUpdateV2(List<int> update) {
  return encodeStateVectorV2(_stateVectorFromUpdate(decodeUpdateV2(update)));
}

void _dropUnresolvedPending(Doc doc) {
  doc.store
    ..clearPendingStructs()
    ..clearPendingDeleteSet();
}

StateVector _stateVectorFromUpdate(DecodedUpdate update) {
  final state = <ClientId, Clock>{};
  final structsByClient = <ClientId, List<DecodedStruct>>{};
  for (final struct in update.structs) {
    // decodeUpdate represents every unresolved block range as a synthetic
    // Skip. Those ranges can overlap concrete structs that integrated before a
    // later gap was discovered, so they must not participate in contiguity at
    // all. Only decoded concrete structs prove clock ownership.
    if (struct.ref == structSkipRefNumber) {
      continue;
    }
    (structsByClient[struct.id.client] ??= <DecodedStruct>[]).add(struct);
  }
  for (final entry in structsByClient.entries) {
    final structs = entry.value
      ..sort((left, right) => left.id.clock.compareTo(right.id.clock));
    var contiguousEnd = 0;
    for (final struct in structs) {
      final start = struct.id.clock.value;
      if (start > contiguousEnd) {
        break;
      }
      final end = start + struct.length;
      if (end > contiguousEnd) {
        contiguousEnd = end;
      }
    }
    if (contiguousEnd > 0) {
      state[entry.key] = Clock(contiguousEnd);
    }
  }
  return Map<ClientId, Clock>.unmodifiable(state);
}
