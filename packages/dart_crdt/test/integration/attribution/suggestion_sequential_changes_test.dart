import 'package:dart_crdt/dart_crdt.dart';
import 'package:test/test.dart';

void main() {
  group('suggestion decision causal safety', () {
    test('partial deletion acceptance fails before the reviewer corruption',
        () {
      final source = _sourceText(5, 'abc');
      final previous = _integrated(source, 90);
      final next = _integrated(source, 91);
      next.getText('root').deleteText(1, 2);
      final manager = createAttributionManagerFromDiff(previous, next);
      final previousState = previous.store.stateVector();
      final nextState = next.store.stateVector();
      final previousPending = previous.store.pendingStructUpdates.length;
      final nextPending = next.store.pendingStructUpdates.length;

      // Accepting only `b` used to materialize and then selectively undo causal
      // state. A later append on previous consequently remained pending forever
      // on next when `c` was rejected. Fail before either document is touched.
      expect(
        () => manager.acceptChanges(_id(5, 1)),
        throwsA(isA<UnsupportedError>()),
      );

      expect(_text(previous), 'abc');
      expect(_text(next), 'a');
      expect(previous.store.stateVector(), previousState);
      expect(next.store.stateVector(), nextState);
      expect(previous.store.pendingStructUpdates, hasLength(previousPending));
      expect(next.store.pendingStructUpdates, hasLength(nextPending));

      expect(
        () => manager.rejectChanges(_id(5, 2)),
        throwsA(isA<UnsupportedError>()),
      );
      expect(_text(previous), 'abc');
      expect(_text(next), 'a');
      expect(previous.store.pendingStructUpdates, isEmpty);
      expect(next.store.pendingStructUpdates, isEmpty);
    });

    test('partial insertion decisions also fail closed without mutation', () {
      final previous = Doc(gc: false, clientId: ClientId(90));
      final next = Doc(gc: false, clientId: ClientId(91));
      applyUpdate(next, encodeStateAsUpdate(_sourceText(7, 'abc')));
      final manager = createAttributionManagerFromDiff(previous, next);

      expect(
        () => manager.acceptChanges(_id(7, 0)),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => manager.rejectChanges(_id(7, 2)),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => manager.acceptChanges(_id(99, 0)),
        throwsA(isA<UnsupportedError>()),
      );

      expect(_text(previous), isEmpty);
      expect(_text(next), 'abc');
      expect(
        manager.suggestedChanges,
        ContentIds(inserts: _idSet([(7, 0, 3)])),
      );
      expect(previous.store.pendingStructUpdates, isEmpty);
      expect(next.store.pendingStructUpdates, isEmpty);
    });

    test('the full remaining deletion range delegates and stays causal', () {
      final source = _sourceText(5, 'abc');
      final previous = _integrated(source, 90);
      final next = _integrated(source, 91);
      next.getText('root').deleteText(1, 2);
      final manager = createAttributionManagerFromDiff(previous, next);

      manager.acceptChanges(_id(5, 1), _id(5, 2));

      expect(_text(previous), 'a');
      expect(_text(next), 'a');
      expect(manager.suggestedChanges, ContentIds.empty());

      final beforeEdit = encodeDocumentStateVector(previous);
      previous.getText('root').insertText(1, 'X');
      applyUpdate(next, encodeStateAsUpdate(previous, beforeEdit));

      expect(_text(previous), 'aX');
      expect(_text(next), 'aX');
      expect(previous.store.pendingStructUpdates, isEmpty);
      expect(next.store.pendingStructUpdates, isEmpty);
    });
  });
}

Doc _sourceText(int client, String text) {
  final doc = Doc(gc: false, clientId: ClientId(client));
  doc.getText('root').insertText(0, text);
  return doc;
}

Doc _integrated(Doc source, int client) {
  final doc = Doc(gc: false, clientId: ClientId(client));
  applyUpdate(doc, encodeStateAsUpdate(source));
  return doc;
}

String _text(Doc doc) => doc.getText('root').toPlainText();

Id _id(int client, int clock) {
  return Id(client: ClientId(client), clock: Clock(clock));
}

IdSet _idSet(List<(int client, int start, int length)> ranges) {
  final result = IdSet();
  for (final range in ranges) {
    result.addRange(
      ClientId(range.$1),
      IdRange(start: Clock(range.$2), length: range.$3),
    );
  }
  return result;
}
