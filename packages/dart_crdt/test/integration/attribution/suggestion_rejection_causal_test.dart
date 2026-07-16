import 'package:dart_crdt/dart_crdt.dart';
import 'package:test/test.dart';

void main() {
  group('reject-all causal reconciliation', () {
    test('syncs insertion tombstones before successor edits', () {
      final source = Doc(gc: false, clientId: ClientId(12));
      final sourceText = source.getText('root')..insertText(0, 'abc');
      final previous = Doc(gc: false, clientId: ClientId(90));
      final next = Doc(gc: false, clientId: ClientId(91));
      applyUpdate(next, encodeStateAsUpdate(source));
      final manager = createAttributionManagerFromDiff(previous, next);

      manager.rejectAllChanges();

      expect(_text(previous), isEmpty);
      expect(_text(next), isEmpty);
      expect(previous.store.stateVector(), next.store.stateVector());

      final beforeSuccessor = encodeDocumentStateVector(source);
      sourceText.insertText(3, 'X');
      final successor = encodeStateAsUpdate(source, beforeSuccessor);
      applyUpdate(previous, successor);
      applyUpdate(next, successor);

      final beforeAdjacent = encodeDocumentStateVector(previous);
      previous.getText('root').insertText(0, 'Y');
      applyUpdate(next, encodeStateAsUpdate(previous, beforeAdjacent));

      expect(_text(previous), 'YX');
      expect(_text(next), 'YX');
      expect(previous.store.pendingStructUpdates, isEmpty);
      expect(next.store.pendingStructUpdates, isEmpty);
      expect(previous.store.stateVector(), next.store.stateVector());
    });

    test('syncs restored ids before adjacent edits', () {
      final source = Doc(gc: false, clientId: ClientId(13));
      final sourceText = source.getText('root')..insertText(0, 'abc');
      final previous = _integrated(source, 90);
      final next = _integrated(source, 91);
      next.getText('root').deleteText(1, 1);
      final manager = createAttributionManagerFromDiff(previous, next);

      manager.rejectAllChanges();

      expect(_text(previous), 'abc');
      expect(_text(next), 'abc');
      expect(previous.store.stateVector(), next.store.stateVector());

      final beforeAdjacent = encodeDocumentStateVector(previous);
      previous.getText('root').insertText(2, 'X');
      applyUpdate(next, encodeStateAsUpdate(previous, beforeAdjacent));

      final beforeSuccessor = encodeDocumentStateVector(source);
      sourceText.insertText(3, 'Z');
      final successor = encodeStateAsUpdate(source, beforeSuccessor);
      applyUpdate(previous, successor);
      applyUpdate(next, successor);

      final previousText = _text(previous);
      expect(previousText, _text(next));
      expect(previousText.runes, hasLength(5));
      for (final character in ['a', 'b', 'c', 'X', 'Z']) {
        expect(character.allMatches(previousText), hasLength(1));
      }
      expect(previous.store.pendingStructUpdates, isEmpty);
      expect(next.store.pendingStructUpdates, isEmpty);
      expect(previous.store.stateVector(), next.store.stateVector());
    });
  });
}

Doc _integrated(Doc source, int client) {
  final doc = Doc(gc: false, clientId: ClientId(client));
  applyUpdate(doc, encodeStateAsUpdate(source));
  return doc;
}

String _text(Doc doc) => doc.getText('root').toPlainText();
