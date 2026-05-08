part of generate_fixtures;

_FixtureDefinition _definition(
  int index,
  String category,
  Doc updateDoc, {
  Map<int, int>? stateVector,
  Map<int, int>? appliedStateVector,
  List<int> contentRefs = const [],
  int deletedCount = 0,
  bool pendingStructs = false,
  List<String> subdocGuids = const [],
}) {
  final sourceState = _intState(documentStateVector(updateDoc));
  return _FixtureDefinition(
    id: category,
    category: category,
    description: 'Neutral $category compatibility fixture.',
    updateDoc: updateDoc,
    stateVector: stateVector ?? sourceState,
    snapshot: _snapshotFor(index, category),
    relativePosition: _relativePositionFor(index, category),
    idMap: _idMapFor(index, category),
    contentMap: _contentMapFor(index, category),
    expected: {
      'appliedStateVector': _jsonState(appliedStateVector ?? sourceState),
      'contentRefs': contentRefs,
      'deletedCount': deletedCount,
      'pendingStructs': pendingStructs,
      'pendingDeletes': false,
      'subdocGuids': subdocGuids,
    },
  );
}

Doc _doc(
  Iterable<AbstractStruct> structs, {
  bool gc = true,
  BlockSet? pendingStructs,
  IdSet? pendingDeleteSet,
}) {
  final doc = Doc(gc: gc);
  for (final struct in structs) {
    doc.store.add(struct);
  }
  if (pendingStructs != null) {
    doc.store.addPendingStructs(pendingStructs);
  }
  if (pendingDeleteSet != null) {
    doc.store.addPendingDeleteSet(pendingDeleteSet);
  }
  return doc;
}

Item _rootItem(
  int client,
  int clock,
  String parentKey,
  AbstractContent content, {
  Id? origin,
  String? parentSub,
}) {
  return Item(
    id: _id(client, clock),
    origin: origin,
    parent: origin == null ? ItemParent(key: parentKey) : null,
    parentSub: parentSub,
    content: content,
  );
}

IdMap _idMapFor(int index, String category) {
  final map = IdMap();
  if (category == 'empty-docs') {
    return map;
  }
  final client = ClientId(index + 1);
  map.add(
    Id(client: client, clock: Clock(0)),
    length: (index % 3) + 1,
    attributes: [
      ContentAttribute('case', category),
      ContentAttribute('format', 'id-map'),
    ],
  );
  if (category == 'attribution-maps') {
    map.add(
      Id(client: client, clock: Clock(4)),
      length: 2,
      attributes: [
        ContentAttribute('author', 'alice'),
        ContentAttribute('session', 'review'),
      ],
    );
  }
  return map;
}

ContentMap _contentMapFor(int index, String category) {
  if (category == 'empty-docs') {
    return ContentMap.empty();
  }
  final client = ClientId(index + 1);
  final ids = ContentIds(
    inserts: IdSet()
      ..add(
        Id(client: client, clock: Clock(0)),
        length: (index % 2) + 1,
      ),
    deletes: category == 'deletes'
        ? (IdSet()..add(Id(client: client, clock: Clock(3))))
        : IdSet(),
  );
  return ids.toContentMap(
    insertAttributes: [
      ContentAttribute('case', category),
      ContentAttribute('branch', 'insert'),
    ],
    deleteAttributes: [
      ContentAttribute('case', category),
      ContentAttribute('branch', 'delete'),
    ],
  );
}

RelativePosition _relativePositionFor(int index, String category) {
  final client = index + 1;
  final assoc = switch (index % 3) {
    0 => -1,
    1 => 0,
    _ => 1,
  };
  return switch (index % 3) {
    0 => RelativePosition.root(category, assoc: assoc),
    1 => RelativePosition.item(_id(client, index), assoc: assoc),
    _ => RelativePosition.type(_id(client, index + 1), assoc: assoc),
  };
}

Snapshot _snapshotFor(int index, String category) {
  if (category == 'empty-docs') {
    return emptySnapshot;
  }
  final client = ClientId(index + 1);
  final deletes = IdSet();
  if (category == 'deletes' || category == 'gc-disabled-snapshots') {
    deletes.add(Id(client: client, clock: Clock(0)));
  }
  return createSnapshot(deletes, {client: Clock((index % 4) + 1)});
}

Uint8List _encodeIdMap(IdMap map) {
  final writer = ByteWriter();
  IdMapEncoderV2.write(writer, map);
  return writer.toBytes();
}

StateVector _state(Map<int, int> state) {
  return {
    for (final entry in state.entries) ClientId(entry.key): Clock(entry.value),
  };
}

Map<int, int> _intState(StateVector state) {
  return {
    for (final entry in state.entries) entry.key.value: entry.value.value,
  };
}

Map<String, int> _jsonState(Map<int, int> state) {
  return {
    for (final entry in state.entries) '${entry.key}': entry.value,
  };
}

List<int> _clients(Iterable<ClientId> clients) {
  return [for (final client in clients) client.value];
}

Id _id(int client, int clock) {
  return Id(client: ClientId(client), clock: Clock(clock));
}

String _hex(List<int> bytes) {
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
