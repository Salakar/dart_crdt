part of generate_fixtures;

_FixtureDefinition _definitionFor(int index, String category) {
  final client = index + 1;
  return switch (category) {
    'empty-docs' => _definition(
        index,
        category,
        _doc([]),
      ),
    'nested-docs' => _definition(
        index,
        category,
        _doc([
          _rootItem(
            client,
            0,
            'nested',
            ContentType(
              const SharedTypePlaceholder(
                kind: SharedTypeKind.map,
                name: 'child',
              ),
            ),
          ),
        ]),
        contentRefs: const [contentTypeRef],
      ),
    'arrays' => _definition(
        index,
        category,
        _doc([
          _rootItem(
            client,
            0,
            'array',
            ContentAny.fromObjects([1, 'two', true]),
          ),
        ]),
        contentRefs: const [contentAnyRef],
      ),
    'maps' => _definition(
        index,
        category,
        _doc([
          _rootItem(
            client,
            0,
            'map',
            ContentString('title'),
            parentSub: 'title',
          ),
          _rootItem(
            client,
            5,
            'map',
            ContentAny.fromObjects([true, 7]),
            parentSub: 'flags',
          ),
        ]),
        contentRefs: const [contentStringRef, contentAnyRef],
      ),
    'text' => _definition(
        index,
        category,
        _doc([_rootItem(client, 0, 'text', ContentString('plain text'))]),
        contentRefs: const [contentStringRef],
      ),
    'rich-text-formats' => _richTextDefinition(index, category, client),
    'xml-tree-content' => _xmlDefinition(index, category, client),
    'subdocs' => _definition(
        index,
        category,
        _doc([
          _rootItem(
            client,
            0,
            'subdocs',
            ContentDocument(
              guid: 'compat-subdoc',
              collectionId: 'compat',
              meta: AnyValue.fromObject({'role': 'child'}),
              shouldLoad: true,
            ),
          ),
        ]),
        contentRefs: const [contentDocumentRef],
        subdocGuids: const ['compat-subdoc'],
      ),
    'binary-content' => _definition(
        index,
        category,
        _doc([
          _rootItem(
            client,
            0,
            'binary',
            ContentBinary([0, 1, 2, 253, 254, 255]),
          ),
        ]),
        contentRefs: const [contentBinaryRef],
      ),
    'embeds' => _definition(
        index,
        category,
        _doc([
          _rootItem(
            client,
            0,
            'embeds',
            ContentEmbed({'kind': 'image', 'hash': 'abc123'}),
          ),
        ]),
        contentRefs: const [contentEmbedRef],
      ),
    'json' => _jsonDefinition(index, category, client),
    'pending-updates' => _definition(
        index,
        category,
        _doc([], pendingStructs: BlockSet()..add(_id(client, 4), length: 2)),
        stateVector: {client: 4},
        appliedStateVector: const {},
        pendingStructs: true,
      ),
    'deletes' => _definition(
        index,
        category,
        _doc(
          [_rootItem(client, 0, 'deletes', ContentString('remove'))],
          pendingDeleteSet: IdSet()..add(_id(client, 0), length: 6),
        ),
        deletedCount: 1,
        contentRefs: const [contentStringRef],
      ),
    'gc-disabled-snapshots' => _definition(
        index,
        category,
        _doc(
          [_rootItem(client, 0, 'snapshot', ContentString('retained'))],
          gc: false,
        ),
        contentRefs: const [contentStringRef],
      ),
    'attribution-maps' => _definition(
        index,
        category,
        _doc([
          _rootItem(
            client,
            0,
            'attribution',
            ContentString('tracked'),
          ),
        ]),
        contentRefs: const [contentStringRef],
      ),
    _ => throw StateError('Missing fixture definition for $category.'),
  };
}

_FixtureDefinition _richTextDefinition(
  int index,
  String category,
  int client,
) {
  return _definition(
    index,
    category,
    _doc([
      _rootItem(
        client,
        0,
        'rich',
        ContentFormat(key: 'bold', value: true),
      ),
      _rootItem(
        client,
        1,
        'rich',
        ContentString('Bold'),
        origin: _id(client, 0),
      ),
    ]),
    contentRefs: const [contentFormatRef, contentStringRef],
  );
}

_FixtureDefinition _xmlDefinition(int index, String category, int client) {
  return _definition(
    index,
    category,
    _doc([
      _rootItem(
        client,
        0,
        'xml',
        ContentType(
          const SharedTypePlaceholder(
            kind: SharedTypeKind.xmlFragment,
            name: 'root',
          ),
        ),
      ),
      _rootItem(
        client,
        1,
        'xml',
        ContentType(
          const SharedTypePlaceholder(
            kind: SharedTypeKind.xmlElement,
            name: 'p',
          ),
        ),
        origin: _id(client, 0),
      ),
    ]),
    contentRefs: const [contentTypeRef, contentTypeRef],
  );
}

_FixtureDefinition _jsonDefinition(int index, String category, int client) {
  return _definition(
    index,
    category,
    _doc([
      _rootItem(
        client,
        0,
        'json',
        ContentJson.fromObjects([
          {'a': 1, 'b': true},
          ['nested', null],
        ]),
      ),
    ]),
    contentRefs: const [contentJsonRef],
  );
}
