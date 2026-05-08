import 'package:ycrdt/src/content/content.dart';
import 'package:ycrdt/src/doc/doc.dart';
import 'package:ycrdt/src/metadata/id_set.dart';
import 'package:ycrdt/src/structs/abstract_struct.dart';
import 'package:ycrdt/src/structs/id.dart';

/// Builds a document with deterministic text items for one client.
Doc benchmarkStructDocument({
  required int client,
  required int itemCount,
  required int chunkSize,
  String parentKey = 'sync_root',
  bool gc = true,
}) {
  final clientId = ClientId(client);
  final doc = Doc(clientId: clientId, gc: gc);
  final parent = doc.itemParentForKey(parentKey);
  var clock = 0;

  for (var index = 0; index < itemCount; index += 1) {
    final text = _chunk(index, chunkSize);
    doc.store.add(
      Item(
        id: Id(client: clientId, clock: Clock(clock)),
        origin:
            clock == 0 ? null : Id(client: clientId, clock: Clock(clock - 1)),
        parent: parent,
        content: ContentString(text),
      ),
    );
    clock += text.length;
  }

  return doc;
}

/// Builds a document that only carries a pending delete range.
Doc benchmarkDeleteOnlyDocument({
  required int client,
  required int clock,
}) {
  return Doc(clientId: ClientId(99))
    ..store.addPendingDeleteSet(
      IdSet()..add(Id(client: ClientId(client), clock: Clock(clock))),
    );
}

String _chunk(int index, int size) {
  return String.fromCharCodes(
    List<int>.filled(size, 'a'.codeUnitAt(0) + (index % 26)),
  );
}
