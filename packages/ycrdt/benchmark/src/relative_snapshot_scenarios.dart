import 'package:ycrdt/src/content/content.dart';
import 'package:ycrdt/src/doc/doc.dart';
import 'package:ycrdt/src/relative_position/relative_position.dart';
import 'package:ycrdt/src/snapshot/snapshot.dart';
import 'package:ycrdt/src/sync/apply_update.dart';
import 'package:ycrdt/src/sync/state_update.dart';
import 'package:ycrdt/src/sync/state_vector.dart';

import 'advanced_shape.dart';
import 'benchmark_case.dart';
import 'document_metrics.dart';
import 'sync_document_fixtures.dart';

/// Builds relative-position and snapshot benchmark cases.
List<BenchmarkCase> buildRelativeSnapshotCases(AdvancedShape shape) {
  return <BenchmarkCase>[
    _relativePositionCreateResolve(shape),
    _snapshotCreateRestoreContainment(shape),
  ];
}

BenchmarkCase _relativePositionCreateResolve(AdvancedShape shape) {
  return BenchmarkCase(
    name: 'advanced_relative_position_create_resolve',
    description: 'Create, encode, decode, and resolve relative positions.',
    work: () {
      final fixture = _relativeFixture(shape);
      final positions = _relativePositions(fixture, shape);
      final resolved = _resolvePositions(fixture.doc, positions);
      if (positions.length != resolved) {
        throw StateError('Expected every relative position to resolve.');
      }
    },
    metrics: () {
      final fixture = _relativeFixture(shape);
      final positions = _relativePositions(fixture, shape);
      return <String, Object?>{
        ...benchmarkDocumentMetrics(
          fixture.doc,
          payloadBytes: fixture.update.length,
        ),
        'operationCount': positions.length * 3,
        'relativePositionCount': positions.length,
        'resolvedPositionCount': _resolvePositions(fixture.doc, positions),
        'encodedRelativeBytes': positions.fold<int>(
          0,
          (total, position) => total + encodeRelativePosition(position).length,
        ),
      };
    },
  );
}

BenchmarkCase _snapshotCreateRestoreContainment(AdvancedShape shape) {
  return BenchmarkCase(
    name: 'advanced_snapshot_create_restore_containment',
    description: 'Create, encode, decode, restore, and check snapshots.',
    work: () {
      final fixture = _snapshotFixture(shape);
      final snap = snapshot(fixture.origin);
      final restored = createDocFromSnapshot(fixture.origin, snap);
      if (restored.store.isEmpty ||
          !snapshotContainsUpdate(snap, fixture.includedV1) ||
          !snapshotContainsUpdateV2(snap, fixture.includedV2)) {
        throw StateError('Expected valid restored snapshot and containment.');
      }
    },
    metrics: () {
      final fixture = _snapshotFixture(shape);
      final snap = snapshot(fixture.origin);
      final encodedV1 = encodeSnapshot(snap);
      final encodedV2 = encodeSnapshotV2(snap);
      final restored =
          createDocFromSnapshot(fixture.origin, decodeSnapshot(encodedV1));
      final later = benchmarkStructDocument(
        client: 31,
        itemCount: shape.snapshotItems + 1,
        chunkSize: shape.chunkSize,
        parentKey: 'root',
      );
      final laterUpdate = encodeStateAsUpdate(
        later,
        encodeDocumentStateVector(fixture.origin),
      );
      return <String, Object?>{
        ...benchmarkDocumentMetrics(
          fixture.origin,
          payloadBytes: encodedV1.length + encodedV2.length,
        ),
        'operationCount': 8,
        'snapshotBytesV1': encodedV1.length,
        'snapshotBytesV2': encodedV2.length,
        'restoredStructCount': benchmarkStructCount(restored),
        'containsIncludedV1': snapshotContainsUpdate(snap, fixture.includedV1),
        'containsIncludedV2':
            snapshotContainsUpdateV2(snap, fixture.includedV2),
        'containsLaterV1': snapshotContainsUpdate(snap, laterUpdate),
      };
    },
  );
}

final class _RelativeFixture {
  const _RelativeFixture({
    required this.doc,
    required this.type,
    required this.update,
    required this.length,
  });

  final Doc doc;
  final SharedType type;
  final List<int> update;
  final int length;
}

final class _SnapshotFixture {
  const _SnapshotFixture({
    required this.origin,
    required this.includedV1,
    required this.includedV2,
  });

  final Doc origin;
  final List<int> includedV1;
  final List<int> includedV2;
}

_RelativeFixture _relativeFixture(AdvancedShape shape) {
  final source = benchmarkStructDocument(
    client: 30,
    itemCount: shape.relativeItems,
    chunkSize: shape.chunkSize,
    parentKey: 'body',
  );
  final update = encodeStateAsUpdate(source);
  final doc = Doc()..get('body', SharedTypeKind.text);
  applyUpdate(doc, update);
  return _RelativeFixture(
    doc: doc,
    type: doc.get('body', SharedTypeKind.text),
    update: update,
    length: shape.relativeItems * shape.chunkSize,
  );
}

_SnapshotFixture _snapshotFixture(AdvancedShape shape) {
  final origin = benchmarkStructDocument(
    client: 31,
    itemCount: shape.snapshotItems,
    chunkSize: shape.chunkSize,
    parentKey: 'root',
    gc: false,
  );
  final includedV1 = encodeStateAsUpdate(origin);
  final includedV2 = encodeStateAsUpdateV2(origin);
  return _SnapshotFixture(
    origin: origin,
    includedV1: includedV1,
    includedV2: includedV2,
  );
}

List<RelativePosition> _relativePositions(
  _RelativeFixture fixture,
  AdvancedShape shape,
) {
  final step = (fixture.length ~/ shape.relativeItems).clamp(1, fixture.length);
  return <RelativePosition>[
    for (var index = 0; index <= fixture.length; index += step)
      decodeRelativePosition(
        encodeRelativePosition(
          createRelativePositionFromTypeIndex(
            fixture.type,
            index.clamp(0, fixture.length),
            assoc: index.isEven ? 0 : -1,
          ),
        ),
      ),
  ];
}

int _resolvePositions(Doc doc, List<RelativePosition> positions) {
  var resolved = 0;
  for (final position in positions) {
    if (createAbsolutePositionFromRelativePosition(position, doc) != null) {
      resolved += 1;
    }
  }
  return resolved;
}
