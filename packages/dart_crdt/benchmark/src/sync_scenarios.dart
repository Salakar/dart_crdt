import 'package:dart_crdt/src/doc/doc.dart';
import 'package:dart_crdt/src/structs/id.dart';
import 'package:dart_crdt/src/sync/apply_update.dart';
import 'package:dart_crdt/src/sync/state_update.dart';
import 'package:dart_crdt/src/sync/state_vector.dart';
import 'package:dart_crdt/src/sync/update_algebra.dart';
import 'package:dart_crdt/src/sync/update_format.dart';

import 'benchmark_case.dart';
import 'document_metrics.dart';
import 'sync_document_fixtures.dart';
import 'sync_metadata_shape.dart';

/// Builds update encoding and synchronization benchmark cases.
List<BenchmarkCase> buildSyncCases(SyncMetadataShape shape) {
  return <BenchmarkCase>[
    _syncV1EncodeApplyMergeDiff(shape),
    _syncV2EncodeApplyMergeDiff(shape),
    _syncUpdateFormatConvert(shape),
    _syncPendingOutOfOrderRecovery(shape),
  ];
}

BenchmarkCase _syncV1EncodeApplyMergeDiff(SyncMetadataShape shape) {
  return BenchmarkCase(
    name: 'sync_v1_encode_apply_merge_diff',
    description: 'Encode, apply, merge, and diff V1 state updates.',
    work: () {
      final fixture = _buildSyncFixture(shape);
      final target = Doc();
      applyUpdate(target, fixture.v1Updates.first);
      applyUpdate(
        target,
        diffUpdate(fixture.v1Merged, encodeDocumentStateVector(target)),
      );
    },
    metrics: () {
      final fixture = _buildSyncFixture(shape);
      return <String, Object?>{
        ..._syncMetrics(fixture),
        'operationCount': fixture.v1Updates.length * 4,
        'mergedUpdateBytesV1': fixture.v1Merged.length,
      };
    },
  );
}

BenchmarkCase _syncV2EncodeApplyMergeDiff(SyncMetadataShape shape) {
  return BenchmarkCase(
    name: 'sync_v2_encode_apply_merge_diff',
    description: 'Encode, apply, merge, and diff V2 state updates.',
    work: () {
      final fixture = _buildSyncFixture(shape);
      final target = Doc();
      applyUpdateV2(target, fixture.v2Updates.first);
      applyUpdateV2(
        target,
        diffUpdateV2(fixture.v2Merged, encodeDocumentStateVector(target)),
      );
    },
    metrics: () {
      final fixture = _buildSyncFixture(shape);
      return <String, Object?>{
        ..._syncMetrics(fixture),
        'operationCount': fixture.v2Updates.length * 4,
        'mergedUpdateBytesV2': fixture.v2Merged.length,
      };
    },
  );
}

BenchmarkCase _syncUpdateFormatConvert(SyncMetadataShape shape) {
  return BenchmarkCase(
    name: 'sync_update_format_convert',
    description: 'Convert V1 updates to V2 and back to V1.',
    work: () {
      final fixture = _buildSyncFixture(shape);
      final converted = convertUpdateFormatV1ToV2(fixture.v1Merged);
      final roundTrip = convertUpdateFormatV2ToV1(converted);
      if (converted.isEmpty || roundTrip.isEmpty) {
        throw StateError('Expected non-empty converted updates.');
      }
    },
    metrics: () {
      final fixture = _buildSyncFixture(shape);
      final converted = convertUpdateFormatV1ToV2(fixture.v1Merged);
      final roundTrip = convertUpdateFormatV2ToV1(converted);
      return <String, Object?>{
        ..._syncMetrics(fixture),
        'operationCount': 2,
        'convertedUpdateBytesV2': converted.length,
        'roundTripUpdateBytesV1': roundTrip.length,
      };
    },
  );
}

BenchmarkCase _syncPendingOutOfOrderRecovery(SyncMetadataShape shape) {
  return BenchmarkCase(
    name: 'sync_pending_out_of_order_recovery',
    description:
        'Recover pending structs and delete sets from out-of-order updates.',
    work: () {
      final fixture = _buildPendingFixture(shape);
      final v1 = Doc();
      applyUpdate(v1, fixture.laterV1);
      applyUpdate(v1, fixture.deleteOnlyV1);
      applyUpdate(v1, fixture.baseV1);

      final v2 = Doc();
      applyUpdateV2(v2, fixture.laterV2);
      applyUpdateV2(v2, fixture.deleteOnlyV2);
      applyUpdateV2(v2, fixture.baseV2);
    },
    metrics: () {
      final fixture = _buildPendingFixture(shape);
      final target = Doc();
      applyUpdate(target, fixture.laterV1);
      final hadPendingStructs = target.store.pendingStructs.isNotEmpty;
      applyUpdate(target, fixture.deleteOnlyV1);
      final hadPendingDeletes = target.store.pendingDeleteSet.isNotEmpty;
      applyUpdate(target, fixture.baseV1);
      return <String, Object?>{
        ...benchmarkDocumentMetrics(target, payloadBytes: shape.chunkSize * 3),
        'operationCount': 6,
        'hadPendingStructs': hadPendingStructs,
        'hadPendingDeletes': hadPendingDeletes,
        'pendingStructsAfterRecovery':
            target.store.pendingStructs.isEmpty ? 0 : 1,
        'pendingDeletesAfterRecovery':
            target.store.pendingDeleteSet.isEmpty ? 0 : 1,
        'outOfOrderUpdateBytesV1': fixture.laterV1.length,
        'outOfOrderUpdateBytesV2': fixture.laterV2.length,
      };
    },
  );
}

final class _SyncFixture {
  const _SyncFixture({
    required this.doc,
    required this.v1Updates,
    required this.v2Updates,
    required this.v1Merged,
    required this.v2Merged,
  });

  final Doc doc;
  final List<List<int>> v1Updates;
  final List<List<int>> v2Updates;
  final List<int> v1Merged;
  final List<int> v2Merged;
}

final class _PendingFixture {
  const _PendingFixture({
    required this.baseV1,
    required this.laterV1,
    required this.deleteOnlyV1,
    required this.baseV2,
    required this.laterV2,
    required this.deleteOnlyV2,
  });

  final List<int> baseV1;
  final List<int> laterV1;
  final List<int> deleteOnlyV1;
  final List<int> baseV2;
  final List<int> laterV2;
  final List<int> deleteOnlyV2;
}

_SyncFixture _buildSyncFixture(SyncMetadataShape shape) {
  final docs = <Doc>[
    for (var client = 1; client <= shape.clientCount; client += 1)
      benchmarkStructDocument(
        client: client,
        itemCount: shape.itemsPerClient,
        chunkSize: shape.chunkSize,
      ),
  ];
  final target = Doc();
  final v1Updates = <List<int>>[];
  final v2Updates = <List<int>>[];
  for (final doc in docs) {
    v1Updates.add(encodeStateAsUpdate(doc));
    v2Updates.add(encodeStateAsUpdateV2(doc));
    applyUpdate(target, v1Updates.last);
  }

  return _SyncFixture(
    doc: target,
    v1Updates: v1Updates,
    v2Updates: v2Updates,
    v1Merged: mergeUpdates(v1Updates),
    v2Merged: mergeUpdatesV2(v2Updates),
  );
}

_PendingFixture _buildPendingFixture(SyncMetadataShape shape) {
  final doc = benchmarkStructDocument(
    client: 4,
    itemCount: 1,
    chunkSize: shape.chunkSize * 3,
  );
  final baseVector = encodeStateVector({doc.clientId: Clock(1)});
  final deleteOnly = benchmarkDeleteOnlyDocument(client: 4, clock: 1);

  return _PendingFixture(
    baseV1: encodeStateAsUpdate(doc),
    laterV1: encodeStateAsUpdate(doc, baseVector),
    deleteOnlyV1: encodeStateAsUpdate(deleteOnly),
    baseV2: encodeStateAsUpdateV2(doc),
    laterV2: encodeStateAsUpdateV2(doc, baseVector),
    deleteOnlyV2: encodeStateAsUpdateV2(deleteOnly),
  );
}

Map<String, Object?> _syncMetrics(_SyncFixture fixture) {
  return <String, Object?>{
    ...benchmarkDocumentMetrics(
      fixture.doc,
      payloadBytes: fixture.v1Merged.length + fixture.v2Merged.length,
    ),
    'clientCount': fixture.doc.store.clients.length,
    'updateCount': fixture.v1Updates.length,
    'totalUpdateBytesV1': fixture.v1Updates.fold<int>(0, _sumLengths),
    'totalUpdateBytesV2': fixture.v2Updates.fold<int>(0, _sumLengths),
  };
}

int _sumLengths(int total, List<int> update) => total + update.length;
