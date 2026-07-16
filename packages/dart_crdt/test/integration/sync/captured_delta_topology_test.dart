import 'dart:math';
import 'dart:typed_data';

import 'package:dart_crdt/dart_crdt.dart';
import 'package:test/test.dart';

void main() {
  for (final version in _UpdateVersion.values) {
    test(
      '${version.name} captured fixed deltas heal causal gaps and local edits',
      () {
        _runCapturedTopology(version, seed: 0xC0FFEE, operations: 90);
      },
    );
  }
}

void _runCapturedTopology(
  _UpdateVersion version, {
  required int seed,
  required int operations,
}) {
  final random = Random(seed);
  final baselineSource = Doc(clientId: ClientId(100));
  baselineSource.getText('body').insertText(0, 'abc');
  final baseline = _encode(version, baselineSource);

  final replicas = [
    for (var client = 1; client <= 3; client += 1)
      Doc(clientId: ClientId(client)),
  ];
  final archive = Doc(clientId: ClientId(99));
  for (final replica in [...replicas, archive]) {
    _apply(version, replica, baseline);
  }

  final emitted = <Uint8List>[];
  final heldByOrigin = <int, Uint8List>{};
  final localSequence = <int, int>{};
  var sawCausalGap = false;
  const inserts = ['a', 'b', 'c', '🦀', '\n'];

  for (var step = 0; step < operations; step += 1) {
    final originIndex = step % replicas.length;
    final origin = replicas[originIndex];
    final text = origin.getText('body');
    final before = encodeDocumentStateVector(origin);

    if (step % 7 == 6 && text.isNotEmpty) {
      text.deleteText(random.nextInt(text.length), 1);
    } else {
      text.insertText(
        random.nextInt(text.length + 1),
        inserts[random.nextInt(inserts.length)],
      );
    }

    // Capture the exact bytes produced at mutation time. Delivery below never
    // recomputes a diff from a newer document state.
    final update = _encode(version, origin, before);
    emitted.add(update);
    _apply(version, archive, update);

    final sequence = (localSequence[originIndex] ?? 0) + 1;
    localSequence[originIndex] = sequence;
    if (sequence.isOdd) {
      heldByOrigin[originIndex] = update;
      continue;
    }

    // Deliver the later same-client delta first. The recipient subsequently
    // becomes an origin itself, so it edits locally while this update is
    // pending on the held predecessor.
    final recipient = replicas[(originIndex + 1) % replicas.length];
    _apply(version, recipient, update);
    _apply(version, recipient, update); // duplicate delivery is intentional.
    sawCausalGap = sawCausalGap || recipient.store.pendingStructs.isNotEmpty;
  }

  expect(sawCausalGap, isTrue, reason: 'topology must create a causal gap');
  expect(heldByOrigin, isNotEmpty);

  // A healthy archive has retained every fixed delta. Its full state must heal
  // replicas even when they already contain pending future structs and have
  // made concurrent local edits in that state.
  final healthyState = _encode(version, archive);
  for (final replica in replicas) {
    _apply(version, replica, healthyState);
    expect(
      replica.getText('body').toPlainText(),
      archive.getText('body').toPlainText(),
    );
    expect(replica.store.pendingStructs.isEmpty, isTrue);
    expect(replica.store.pendingDeleteSet.isEmpty, isTrue);
    expect(replica.store.skips.isEmpty, isTrue);
  }

  // The journal is deliberately retained to prove this scenario exercised
  // many independent immutable network messages rather than one final diff.
  expect(emitted, hasLength(operations));
}

enum _UpdateVersion { v1, v2 }

Uint8List _encode(_UpdateVersion version, Doc doc, [List<int>? stateVector]) {
  return switch (version) {
    _UpdateVersion.v1 => encodeStateAsUpdate(doc, stateVector),
    _UpdateVersion.v2 => encodeStateAsUpdateV2(doc, stateVector),
  };
}

void _apply(_UpdateVersion version, Doc doc, List<int> update) {
  switch (version) {
    case _UpdateVersion.v1:
      applyUpdate(doc, update);
    case _UpdateVersion.v2:
      applyUpdateV2(doc, update);
  }
}
