import 'package:dart_crdt/src/content/content.dart';
import 'package:dart_crdt/src/doc/doc.dart';
import 'package:dart_crdt/src/structs/id.dart';

import 'benchmark_case.dart';
import 'collection_tree_shape.dart';
import 'document_metrics.dart';

/// Builds XML/tree benchmark cases for [shape].
List<BenchmarkCase> buildTreeCases(CollectionTreeShape shape) {
  return <BenchmarkCase>[
    _xmlTreeInsertDeleteStringify(shape),
  ];
}

BenchmarkCase _xmlTreeInsertDeleteStringify(CollectionTreeShape shape) {
  return BenchmarkCase(
    name: 'xml_tree_insert_delete_stringify',
    description: 'Build, edit, walk, and stringify an XML tree.',
    work: () {
      final result = _buildXmlWorkload(shape);
      final xml = result.root.toXmlString();
      if (xml.isEmpty || result.root.walkXmlTree().isEmpty) {
        throw StateError('Expected non-empty XML tree output.');
      }
    },
    metrics: () {
      final result = _buildXmlWorkload(shape);
      final xml = result.root.toXmlString();
      return <String, Object?>{
        ...benchmarkDocumentMetrics(result.doc, payloadBytes: xml.length),
        'operationCount': result.operationCount,
        'xmlStringBytes': xml.length,
        'xmlNodeCount': result.root.walkXmlTree().length,
        'xmlChildCount': result.root.xmlChildren.length,
      };
    },
  );
}

final class _TreeResult {
  const _TreeResult({
    required this.doc,
    required this.root,
    required this.operationCount,
  });

  final Doc doc;
  final SharedType root;
  final int operationCount;
}

_TreeResult _buildXmlWorkload(CollectionTreeShape shape) {
  final doc = Doc(clientId: ClientId(23));
  final fragment = doc.get('tree', SharedTypeKind.xmlFragment);
  var operationCount = 0;

  for (var branchIndex = 0;
      branchIndex < shape.treeBranches;
      branchIndex += 1) {
    final branch = fragment.appendXmlElement('section');
    operationCount += 1;
    branch
      ..setAttr('id', 'section-$branchIndex')
      ..setAttr('data-rank', branchIndex);
    operationCount += 2;

    for (var leafIndex = 0; leafIndex < shape.treeLeaves; leafIndex += 1) {
      final leaf = branch.appendXmlElement('p');
      operationCount += 1;
      leaf
        ..setAttr('class', 'leaf-${leafIndex % 4}')
        ..appendXmlText('text <$branchIndex:$leafIndex> & value');
      operationCount += 2;
      if (leafIndex % 3 == 0) {
        leaf.appendXmlElement('span').appendXmlText('inline-$leafIndex');
        operationCount += 2;
      }
    }

    if (branch.length > 2 && branchIndex % 2 == 0) {
      branch.delete(1);
      operationCount += 1;
    }
  }

  if (fragment.length > 3) {
    fragment.delete(1);
    operationCount += 1;
  }

  fragment.toXmlString();
  operationCount += 1;

  return _TreeResult(
    doc: doc,
    root: fragment,
    operationCount: operationCount,
  );
}
