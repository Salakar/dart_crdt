import 'dart:io';

import 'package:ycrdt/ycrdt.dart';

void main() {
  final doc = Doc();
  final text = doc.get('body', SharedTypeKind.text);
  final builder = DeltaBuilder()
    ..insertText(
      text: 'Hello',
      attributes: DeltaAttributes.fromJson({'bold': true}),
    )
    ..insertText(text: '!');

  text.applyDelta(builder.done());

  stdout.writeln(
    'text_delta:text=${text.toPlainText()};'
    'ops=${text.toDelta().operations.length}',
  );
}
