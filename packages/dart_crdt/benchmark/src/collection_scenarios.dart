import 'dart:convert';
import 'dart:math';

import 'package:dart_crdt/src/content/content.dart';
import 'package:dart_crdt/src/doc/doc.dart';
import 'package:dart_crdt/src/structs/id.dart';

import 'benchmark_case.dart';
import 'collection_tree_shape.dart';
import 'document_metrics.dart';

/// Builds collection benchmark cases for [shape].
List<BenchmarkCase> buildCollectionCases(CollectionTreeShape shape) {
  return <BenchmarkCase>[
    _arrayRandomInsertDeleteNested(shape),
    _mapSetDeleteConflicts(shape),
  ];
}

BenchmarkCase _arrayRandomInsertDeleteNested(CollectionTreeShape shape) {
  return BenchmarkCase(
    name: 'array_random_insert_delete_nested',
    description: 'Run deterministic array insert/delete with nested types.',
    work: () {
      final result = _buildArrayWorkload(shape);
      if (result.root.isEmpty || result.root.children.isEmpty) {
        throw StateError('Expected populated array with nested children.');
      }
    },
    metrics: () {
      final result = _buildArrayWorkload(shape);
      return <String, Object?>{
        ..._collectionMetrics(result.doc, result.root),
        'operationCount': shape.operations,
        'arrayLength': result.root.length,
        'nestedChildCount': result.root.children.length,
        'searchMarkerCount': result.root.searchMarkers.length,
      };
    },
  );
}

BenchmarkCase _mapSetDeleteConflicts(CollectionTreeShape shape) {
  return BenchmarkCase(
    name: 'map_set_delete_conflicts',
    description: 'Run repeated map set/delete conflicts across clients.',
    work: () {
      final result = _buildMapConflictWorkload(shape);
      if (result.root.attrSize == 0) {
        throw StateError('Expected visible map attributes.');
      }
    },
    metrics: () {
      final result = _buildMapConflictWorkload(shape);
      return <String, Object?>{
        ..._collectionMetrics(result.doc, result.root),
        'operationCount': shape.operations,
        'mapAttrCount': result.root.attrSize,
        'conflictingKeyCount': shape.keyCount,
        'simulatedClientCount': shape.clientCount,
      };
    },
  );
}

final class _CollectionResult {
  const _CollectionResult(this.doc, this.root);

  final Doc doc;
  final SharedType root;
}

_CollectionResult _buildArrayWorkload(CollectionTreeShape shape) {
  final random = Random(17);
  final doc = Doc(clientId: ClientId(21));
  final array = doc.get('items', SharedTypeKind.array);

  for (var index = 0; index < shape.initialSize; index += 1) {
    array.push(_arrayValue(index));
  }
  for (var index = 0; index < shape.operations; index += 1) {
    if (index % 4 == 0 && array.length > 1) {
      array.delete(random.nextInt(array.length));
    } else {
      array.insert(random.nextInt(array.length + 1), _arrayValue(index + 1000));
    }
    if (array.isNotEmpty && index % 7 == 0) {
      array.get(random.nextInt(array.length));
    }
  }

  return _CollectionResult(doc, array);
}

_CollectionResult _buildMapConflictWorkload(CollectionTreeShape shape) {
  final doc = Doc(clientId: ClientId(22));
  final map = doc.get('attrs');

  for (var index = 0; index < shape.operations; index += 1) {
    final client = index % shape.clientCount;
    final key = 'key_${index % shape.keyCount}';
    final clock = index * shape.clientCount + client;
    map.setAttr(key, _mapValue(index), clock: clock);
    if (index % 3 == 0) {
      map.deleteAttr(key, clock: clock + 1);
    }
    if (index % 5 == 0) {
      map.setAttr(key, 'winner_$client:$index', clock: clock + 2);
    }
  }

  return _CollectionResult(doc, map);
}

Object? _arrayValue(int index) {
  if (index % 6 == 0) {
    return SharedType(kind: SharedTypeKind.map, name: 'card_$index')
      ..setAttr('id', index)
      ..setAttr('title', 'card-$index');
  }
  if (index % 5 == 0) {
    return SharedType(kind: SharedTypeKind.text, name: 'note_$index')
      ..insertText(0, 'note-$index');
  }
  return index.isEven ? index : 'value-$index';
}

Object? _mapValue(int index) {
  if (index % 9 == 0) {
    return SharedType(kind: SharedTypeKind.array, name: 'list_$index')
      ..push(index)
      ..push('nested-$index');
  }
  return index.isEven ? index : 'client-value-$index';
}

Map<String, Object?> _collectionMetrics(Doc doc, SharedType root) {
  final payloadBytes = jsonEncode(<String, Object?>{
    'kind': root.kind.name,
    'length': root.length,
    'attributes': root.getAttrs(),
    'children': root.children.length,
  }).length;

  return benchmarkDocumentMetrics(doc, payloadBytes: payloadBytes);
}
