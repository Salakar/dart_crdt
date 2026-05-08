import 'package:ycrdt/src/content/content.dart';
import 'package:ycrdt/src/doc/doc.dart';
import 'package:ycrdt/src/structs/abstract_struct.dart';
import 'package:ycrdt/src/structs/id.dart';

/// Creates a deterministic text item.
Item benchmarkTextItem({
  required Doc doc,
  required int client,
  required int clock,
  required String text,
  String parentKey = 'root',
  bool deleted = false,
}) {
  final item = Item(
    id: benchmarkId(client, clock),
    origin: clock == 0 ? null : benchmarkId(client, clock - 1),
    parent: doc.itemParentForKey(parentKey),
    content: ContentString(text),
  );
  if (deleted) {
    item.markDeleted();
  }
  return item;
}

/// Creates a deterministic item id.
Id benchmarkId(int client, int clock) {
  return Id(client: ClientId(client), clock: Clock(clock));
}

/// Creates deterministic text content.
String benchmarkText(int length) {
  return String.fromCharCodes(
    List<int>.generate(length, (index) => 'a'.codeUnitAt(0) + (index % 26)),
  );
}

/// Returns visible root text from [doc].
String benchmarkRootText(Doc doc, {String parentKey = 'root'}) {
  return [
    for (final item in doc.itemParentForKey(parentKey).items())
      if (!item.deleted && item.content is ContentString)
        (item.content as ContentString).value,
  ].join();
}

/// Counts deleted-content payloads for [doc].
int benchmarkDeletedContentCount(Doc doc) {
  var count = 0;
  for (final client in doc.store.clients) {
    for (final struct in doc.store.structsFor(client)) {
      if (struct is Item && struct.content is ContentDeleted) {
        count += 1;
      }
    }
  }
  return count;
}

/// Counts deleted string payloads retained by [doc].
int benchmarkDeletedStringContentCount(Doc doc) {
  var count = 0;
  for (final client in doc.store.clients) {
    for (final struct in doc.store.structsFor(client)) {
      if (struct is Item && struct.deleted && struct.content is ContentString) {
        count += 1;
      }
    }
  }
  return count;
}
