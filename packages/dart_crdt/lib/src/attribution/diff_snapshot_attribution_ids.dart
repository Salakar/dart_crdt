part of 'diff_snapshot_attribution.dart';

IdSet _documentIds(Doc doc) {
  final ids = IdSet();
  for (final client in doc.store.clients) {
    for (final struct in doc.store.structsFor(client)) {
      if (struct is! Item ||
          struct.deleted ||
          struct.ref == contentDeletedRef) {
        continue;
      }
      ids.addRange(client, struct.range);
    }
  }
  return ids;
}

IdSet _deleteIds(Doc doc) =>
    createDeleteSetFromStore(doc.store).merged(doc.store.pendingDeleteSet);
