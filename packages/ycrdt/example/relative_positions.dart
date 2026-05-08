import 'dart:io';

import 'package:ycrdt/ycrdt.dart';

void main() {
  final source = _docWithTextRoot('hello');
  final doc = Doc();
  final text = doc.get('body', SharedTypeKind.text);

  applyUpdate(doc, encodeStateAsUpdate(source));
  final position = createRelativePositionFromTypeIndex(text, 2);
  final resolved = createAbsolutePositionFromRelativePosition(
    decodeRelativePosition(encodeRelativePosition(position)),
    doc,
  );

  stdout.writeln('relative:index=${resolved?.index};assoc=${resolved?.assoc}');
}

Doc _docWithTextRoot(String text) {
  final doc = Doc(clientId: ClientId(1));
  doc.store.add(
    Item(
      id: Id(client: ClientId(1), clock: Clock(0)),
      parent: doc.itemParentForKey('body'),
      content: ContentString(text),
    ),
  );
  return doc;
}
