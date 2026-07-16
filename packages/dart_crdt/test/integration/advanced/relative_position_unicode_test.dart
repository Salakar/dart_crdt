import 'package:dart_crdt/dart_crdt.dart';
import 'package:dart_crdt/src/structs/struct_store.dart';
import 'package:test/test.dart';

void main() {
  group('Unicode-scalar relative positions', () {
    for (final value in <String>['A🦀B', 'A👩‍💻B', 'Ae\u0301B', 'A🇵🇱B']) {
      test('round-trips every index and association in "$value"', () {
        final source = _textDoc(1, value);
        final clone = Doc(clientId: ClientId(2));
        clone.getText('body');
        applyUpdate(clone, encodeStateAsUpdate(source));
        final type = source.getText('body');

        for (var index = 0; index <= value.runes.length; index += 1) {
          for (final assoc in const [-1, 0, 1]) {
            final relative = createRelativePositionFromTypeIndex(
              type,
              index,
              assoc: assoc,
            );
            expect(
              createAbsolutePositionFromRelativePosition(
                relative,
                source,
              )?.index,
              index,
              reason: 'local index=$index assoc=$assoc',
            );
            expect(
              createAbsolutePositionFromRelativePosition(
                relative,
                clone,
              )?.index,
              index,
              reason: 'clone index=$index assoc=$assoc',
            );
          }
        }
      });
    }

    test('emoji inserted before a cursor shifts by one scalar', () {
      final doc = _textDoc(1, 'AB');
      final text = doc.getText('body');
      final cursor = createRelativePositionFromTypeIndex(text, 1);

      text.insertText(0, '🦀');

      expect(text.toPlainText(), '🦀AB');
      expect(createAbsolutePositionFromRelativePosition(cursor, doc)?.index, 2);
    });

    test('preserves scalar indexes after UTF-16 item splits', () {
      final source = _textDoc(1, 'A🦀B🇵🇱C');
      final type = source.getText('body');

      // Split at valid scalar boundaries on both sides of surrogate-pair runs.
      source.store
        ..cleanStart(_id(1, 1))
        ..cleanStart(_id(1, 3))
        ..cleanStart(_id(1, 4))
        ..cleanStart(_id(1, 6))
        ..cleanStart(_id(1, 8));

      for (var index = 0; index <= type.length; index += 1) {
        for (final assoc in const [-1, 0, 1]) {
          final relative = createRelativePositionFromTypeIndex(
            type,
            index,
            assoc: assoc,
          );
          expect(
            createAbsolutePositionFromRelativePosition(relative, source)?.index,
            index,
            reason: 'split index=$index assoc=$assoc',
          );
        }
      }
    });

    test('floors legacy anchors inside a surrogate pair', () {
      final source = _textDoc(1, 'A🦀B');
      final clone = Doc(clientId: ClientId(2));
      clone.getText('body');
      applyUpdate(clone, encodeStateAsUpdate(source));

      // Clock 2 is the low surrogate inside 🦀. Right association resolves to
      // the scalar's leading boundary; left association resolves after it.
      final right = RelativePosition.item(_id(1, 2));
      final left = RelativePosition.item(_id(1, 2), assoc: -1);
      for (final doc in [source, clone]) {
        expect(
          createAbsolutePositionFromRelativePosition(right, doc)?.index,
          1,
        );
        expect(createAbsolutePositionFromRelativePosition(left, doc)?.index, 2);
      }
    });

    test('same-valued custom length callback retains legacy clock units', () {
      final source = _textDoc(1, 'A🦀B');
      final type = source.getText('body');

      final defaultPosition = createRelativePositionFromTypeIndex(type, 2);
      final customPosition = createRelativePositionFromTypeIndex(
        type,
        2,
        contentLength: _sameScalarLength,
      );

      expect(defaultPosition.itemId, _id(1, 3));
      expect(customPosition.itemId, _id(1, 2));
      expect(
        createAbsolutePositionFromRelativePosition(
          customPosition,
          source,
          contentLength: _sameScalarLength,
        )?.index,
        2,
      );
      expect(
        createAbsolutePositionFromRelativePosition(customPosition, source)
            ?.index,
        1,
      );
    });

    test(
      'deleteText removes one scalar without splitting a surrogate pair',
      () {
        final source = _textDoc(1, 'A🦀B');
        source.getText('body').deleteText(1, 1);
        final clone = Doc(clientId: ClientId(2));
        clone.getText('body');
        applyUpdate(clone, encodeStateAsUpdate(source));

        expect(source.getText('body').toPlainText(), 'AB');
        expect(clone.getText('body').toPlainText(), 'AB');
        expect(source.store.debugIntegrityErrors(), isEmpty);
        expect(clone.store.debugIntegrityErrors(), isEmpty);
      },
    );
  });
}

Doc _textDoc(int client, String value) {
  final doc = Doc(clientId: ClientId(client));
  doc.getText('body').insertText(0, value);
  return doc;
}

Id _id(int client, int clock) {
  return Id(client: ClientId(client), clock: Clock(clock));
}

int _sameScalarLength(Item item) => defaultRelativeContentLength(item);
