import 'package:dart_crdt/src/content/content.dart';
import 'package:dart_crdt/src/doc/doc.dart';
import 'package:dart_crdt/src/structs/abstract_struct.dart';
import 'package:dart_crdt/src/structs/id.dart';
import 'package:dart_crdt/src/sync/state_update.dart';

import 'benchmark_case.dart';
import 'benchmark_runner.dart';

/// Builds update encoding benchmark cases for [mode].
List<BenchmarkCase> buildUpdateEncodingCases(BenchmarkMode mode) {
  final shape = switch (mode) {
    BenchmarkMode.smoke => const _DocumentShape(chunks: 8, chunkSize: 12),
    BenchmarkMode.full => const _DocumentShape(chunks: 120, chunkSize: 32),
  };

  return <BenchmarkCase>[
    BenchmarkCase(
      name: 'update_encoding_round_trip',
      description: 'Build a text document and encode V1/V2 state updates.',
      work: () {
        final doc = _textDocument(shape);
        final updateV1 = encodeStateAsUpdate(doc);
        final updateV2 = encodeStateAsUpdateV2(doc);
        if (updateV1.isEmpty || updateV2.isEmpty) {
          throw StateError('Expected non-empty encoded updates.');
        }
      },
      metrics: () {
        final doc = _textDocument(shape);
        final updateV1 = encodeStateAsUpdate(doc);
        final updateV2 = encodeStateAsUpdateV2(doc);
        final clientId = ClientId(1);

        return <String, Object?>{
          'updateBytesV1': updateV1.length,
          'updateBytesV2': updateV2.length,
          'structCountBefore': 0,
          'structCountAfter': _structCount(doc),
          'clientCount': doc.store.clients.length,
          'documentClock': doc.store.getClock(clientId).value,
        };
      },
    ),
  ];
}

final class _DocumentShape {
  const _DocumentShape({
    required this.chunks,
    required this.chunkSize,
  });

  final int chunks;
  final int chunkSize;
}

Doc _textDocument(_DocumentShape shape) {
  final doc = Doc(clientId: ClientId(1));
  final parent = doc.itemParentForKey('benchmark_text');
  final clientId = ClientId(1);
  var clock = 0;

  for (var index = 0; index < shape.chunks; index++) {
    final text = _chunkText(index, shape.chunkSize);
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

String _chunkText(int index, int size) {
  final codeUnit = 'a'.codeUnitAt(0) + (index % 26);

  return String.fromCharCodes(List<int>.filled(size, codeUnit));
}

int _structCount(Doc doc) {
  var count = 0;
  for (final client in doc.store.clients) {
    count += doc.store.structsFor(client).length;
  }

  return count;
}
