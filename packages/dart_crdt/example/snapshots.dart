import 'dart:io';

import 'package:dart_crdt/dart_crdt.dart';

void main() {
  final doc = _docWithRootText('snapshot');
  final snap = snapshot(doc);
  final restored = createDocFromSnapshot(
    doc,
    decodeSnapshot(encodeSnapshot(snap)),
  );

  stdout.writeln('snapshot:text=${_rootText(restored)};empty=${snap.isEmpty}');
}

Doc _docWithRootText(String text) {
  final doc = Doc(gc: false, clientId: ClientId(1));
  doc.store.add(
    Item(
      id: Id(client: ClientId(1), clock: Clock(0)),
      parent: doc.itemParentForKey('root'),
      content: ContentString(text),
    ),
  );
  return doc;
}

String _rootText(Doc doc) {
  return [
    for (final item in doc.itemParentForKey('root').items())
      if (!item.deleted && item.content is ContentString)
        (item.content as ContentString).value,
  ].join();
}
