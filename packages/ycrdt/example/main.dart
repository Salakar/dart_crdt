import 'dart:io';

import 'package:ycrdt/ycrdt.dart';

void main() {
  final doc = Doc();
  final text = doc.get('body', SharedTypeKind.text);

  text.insertText(0, 'Hello, local-first Dart.');

  stdout.writeln('main:text=${text.toPlainText()};package=$packageName');
}
