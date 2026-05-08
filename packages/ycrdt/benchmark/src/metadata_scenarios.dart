import 'package:ycrdt/src/metadata/attr_range.dart';
import 'package:ycrdt/src/metadata/content_attribute.dart';
import 'package:ycrdt/src/metadata/id_map.dart';
import 'package:ycrdt/src/metadata/id_range.dart';
import 'package:ycrdt/src/metadata/id_set.dart';
import 'package:ycrdt/src/structs/id.dart';

import 'benchmark_case.dart';
import 'sync_metadata_shape.dart';

/// Builds metadata algebra benchmark cases.
List<BenchmarkCase> buildMetadataCases(SyncMetadataShape shape) {
  return <BenchmarkCase>[
    _metadataIdSetAlgebra(shape),
    _metadataIdMapAlgebra(shape),
  ];
}

BenchmarkCase _metadataIdSetAlgebra(SyncMetadataShape shape) {
  return BenchmarkCase(
    name: 'metadata_id_set_algebra',
    description: 'Run IdSet merge, diff, and intersection workloads.',
    work: () {
      final fixture = _buildIdSetFixture(shape);
      final merged = fixture.left.merged(fixture.right);
      final diff = fixture.left.diff(fixture.right);
      final intersect = fixture.left.intersect(fixture.right);
      if (merged.isEmpty || diff.isEmpty || intersect.isEmpty) {
        throw StateError('Expected non-empty id-set algebra outputs.');
      }
    },
    metrics: () {
      final fixture = _buildIdSetFixture(shape);
      final merged = fixture.left.merged(fixture.right);
      final diff = fixture.left.diff(fixture.right);
      final intersect = fixture.left.intersect(fixture.right);
      return <String, Object?>{
        'operationCount': 3,
        'leftRangeCount': _idSetRangeCount(fixture.left),
        'rightRangeCount': _idSetRangeCount(fixture.right),
        'mergedRangeCount': _idSetRangeCount(merged),
        'diffRangeCount': _idSetRangeCount(diff),
        'intersectRangeCount': _idSetRangeCount(intersect),
        'clientCount': merged.clientCount,
      };
    },
  );
}

BenchmarkCase _metadataIdMapAlgebra(SyncMetadataShape shape) {
  return BenchmarkCase(
    name: 'metadata_id_map_algebra',
    description: 'Run IdMap merge, diff, intersection, and filter workloads.',
    work: () {
      final fixture = _buildIdMapFixture(shape);
      final merged = fixture.left.merged(fixture.right);
      final diff = fixture.left.diff(fixture.right);
      final intersect = fixture.left.intersect(fixture.right);
      final filtered = merged.filter(_containsEvenAttribute);
      if (merged.isEmpty ||
          diff.isEmpty ||
          intersect.isEmpty ||
          filtered.isEmpty) {
        throw StateError('Expected non-empty id-map algebra outputs.');
      }
    },
    metrics: () {
      final fixture = _buildIdMapFixture(shape);
      final merged = fixture.left.merged(fixture.right);
      final diff = fixture.left.diff(fixture.right);
      final intersect = fixture.left.intersect(fixture.right);
      final filtered = merged.filter(_containsEvenAttribute);
      return <String, Object?>{
        'operationCount': 4,
        'leftRangeCount': _idMapRangeCount(fixture.left),
        'rightRangeCount': _idMapRangeCount(fixture.right),
        'mergedRangeCount': _idMapRangeCount(merged),
        'diffRangeCount': _idMapRangeCount(diff),
        'intersectRangeCount': _idMapRangeCount(intersect),
        'filteredRangeCount': _idMapRangeCount(filtered),
        'attributeCount': merged.attributes.length,
        'clientCount': merged.clientCount,
      };
    },
  );
}

final class _IdSetFixture {
  const _IdSetFixture(this.left, this.right);

  final IdSet left;
  final IdSet right;
}

final class _IdMapFixture {
  const _IdMapFixture(this.left, this.right);

  final IdMap left;
  final IdMap right;
}

_IdSetFixture _buildIdSetFixture(SyncMetadataShape shape) {
  final left = IdSet();
  final right = IdSet();
  for (var index = 0; index < shape.rangeCount; index += 1) {
    final client = ClientId((index % shape.clientCount) + 1);
    final start = Clock(index * (shape.rangeLength + 2));
    left.addRange(
      client,
      IdRange(start: start, length: shape.rangeLength),
    );
    right.addRange(
      client,
      IdRange(
        start: Clock(start.value + shape.rangeLength ~/ 2),
        length: shape.rangeLength,
      ),
    );
  }
  return _IdSetFixture(left, right);
}

_IdMapFixture _buildIdMapFixture(SyncMetadataShape shape) {
  final left = IdMap();
  final right = IdMap();
  for (var index = 0; index < shape.rangeCount; index += 1) {
    final client = ClientId((index % shape.clientCount) + 1);
    final start = Clock(index * (shape.rangeLength + 2));
    left.addRange(
      client,
      AttrRange(
        start: start,
        length: shape.rangeLength,
        attributes: _attributes(index),
      ),
    );
    right.addRange(
      client,
      AttrRange(
        start: Clock(start.value + shape.rangeLength ~/ 2),
        length: shape.rangeLength,
        attributes: _attributes(index + 1),
      ),
    );
  }
  return _IdMapFixture(left, right);
}

List<ContentAttribute> _attributes(int index) {
  return <ContentAttribute>[
    ContentAttribute('bucket', index % 4),
    ContentAttribute('parity', index.isEven ? 'even' : 'odd'),
  ];
}

bool _containsEvenAttribute(List<ContentAttribute> attributes) {
  return attributes.any(
    (attribute) =>
        attribute.name == 'parity' && attribute.value.toObject() == 'even',
  );
}

int _idSetRangeCount(IdSet set) {
  var count = 0;
  set.forEach((_, __) => count += 1);
  return count;
}

int _idMapRangeCount(IdMap map) {
  var count = 0;
  map.forEach((_, __) => count += 1);
  return count;
}
