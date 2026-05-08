import 'dart:io';

import 'package:dart_crdt/dart_crdt.dart';

void main() {
  final local = _docWithRootText('sync');
  final remote = Doc(clientId: ClientId(9));

  applyUpdate(remote, encodeStateAsUpdate(local));

  stdout.writeln(
    'update:text=${_rootText(remote)};'
    'clock=${remote.store.getClock(ClientId(1)).value}',
  );
}

Doc _docWithRootText(String text) {
  final doc = Doc(clientId: ClientId(1));
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
