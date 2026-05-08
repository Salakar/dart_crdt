library generate_fixtures;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../packages/dart_crdt/lib/src/binary/any_value.dart';
import '../packages/dart_crdt/lib/src/binary/byte_writer.dart';
import '../packages/dart_crdt/lib/src/content/content.dart';
import '../packages/dart_crdt/lib/src/doc/doc.dart';
import '../packages/dart_crdt/lib/src/metadata/content_attribute.dart';
import '../packages/dart_crdt/lib/src/metadata/content_ids.dart';
import '../packages/dart_crdt/lib/src/metadata/content_map.dart';
import '../packages/dart_crdt/lib/src/metadata/content_metadata_codec.dart';
import '../packages/dart_crdt/lib/src/metadata/id_map.dart';
import '../packages/dart_crdt/lib/src/metadata/id_map_codec.dart';
import '../packages/dart_crdt/lib/src/metadata/id_set.dart';
import '../packages/dart_crdt/lib/src/relative_position/relative_position.dart';
import '../packages/dart_crdt/lib/src/snapshot/snapshot.dart';
import '../packages/dart_crdt/lib/src/structs/abstract_struct.dart';
import '../packages/dart_crdt/lib/src/structs/id.dart';
import '../packages/dart_crdt/lib/src/sync/block_set.dart';
import '../packages/dart_crdt/lib/src/sync/state_update.dart';
import '../packages/dart_crdt/lib/src/sync/state_vector.dart';

part 'fixture_generation/compat_fixture_builders.dart';
part 'fixture_generation/compat_fixture_cases.dart';
part 'fixture_generation/compat_fixture_model.dart';

const _defaultOutput = 'packages/dart_crdt/test/fixtures/compat';

const _requiredCategories = [
  'empty-docs',
  'nested-docs',
  'arrays',
  'maps',
  'text',
  'rich-text-formats',
  'xml-tree-content',
  'subdocs',
  'binary-content',
  'embeds',
  'json',
  'pending-updates',
  'deletes',
  'gc-disabled-snapshots',
  'attribution-maps',
];

const _roundTripDirections = [
  'reference-to-dart',
  'dart-to-reference',
];

const _serializedFormats = [
  'update-v1',
  'update-v2',
  'state-vector',
  'snapshot',
  'relative-position',
  'id-map',
  'content-map',
];

Future<void> main(List<String> args) async {
  final output = _outputDirectory(args);
  await _writeFixtures(Directory(output));
  stdout.writeln('Generated neutral compatibility fixtures in $output.');
}

String _outputDirectory(List<String> args) {
  if (args.isEmpty) {
    return _defaultOutput;
  }
  if (args.length == 2 && args.first == '--output') {
    return args.last;
  }
  stderr
      .writeln('Usage: dart run tool/generate_fixtures.dart [--output <dir>]');
  exit(64);
}

Future<void> _writeFixtures(Directory output) async {
  output.createSync(recursive: true);
  final cases = _cases();
  _writeJson(
    File.fromUri(output.uri.resolve('manifest.schema.json')),
    _schema(),
  );
  _writeJson(
    File.fromUri(output.uri.resolve('manifest.json')),
    _manifest(cases),
  );
  await _writeJsonLines(File.fromUri(output.uri.resolve('cases.jsonl')), cases);
}

List<Map<String, Object?>> _cases() {
  return [
    for (var index = 0; index < _requiredCategories.length; index += 1)
      _caseFor(_definitionFor(index, _requiredCategories[index])),
  ];
}

Map<String, Object?> _caseFor(_FixtureDefinition definition) {
  final payloads = {
    'update-v1': _hex(encodeStateAsUpdate(definition.updateDoc)),
    'update-v2': _hex(encodeStateAsUpdateV2(definition.updateDoc)),
    'state-vector': _hex(encodeStateVector(_state(definition.stateVector))),
    'snapshot': _hex(encodeSnapshot(definition.snapshot)),
    'relative-position': _hex(
      encodeRelativePosition(definition.relativePosition),
    ),
    'id-map': _hex(_encodeIdMap(definition.idMap)),
    'content-map': _hex(encodeContentMap(definition.contentMap)),
  };

  return {
    'id': definition.id,
    'category': definition.category,
    'description': definition.description,
    'formats': _serializedFormats,
    'expected': {
      ...definition.expected,
      'stateVector': _jsonState(definition.stateVector),
      'snapshotStateVector': _jsonState(
        _intState(definition.snapshot.stateVector),
      ),
      'snapshotDeleteClients': _clients(definition.snapshot.deleteSet.clients),
      'relativePosition': definition.relativePosition.toJson(),
      'idMapClients': _clients(definition.idMap.clients),
      'contentMapInsertClients':
          _clients(definition.contentMap.inserts.clients),
      'contentMapDeleteClients':
          _clients(definition.contentMap.deletes.clients),
    },
    'roundTrips': [
      for (final format in _serializedFormats)
        for (final direction in _roundTripDirections)
          {
            'direction': direction,
            'format': format,
            'payloadHex': payloads[format],
          },
    ],
  };
}

Map<String, Object?> _manifest(List<Map<String, Object?>> cases) {
  return {
    'schemaVersion': 1,
    'generatedBy': 'tool/generate_fixtures.dart',
    'caseFile': 'cases.jsonl',
    'requiredCategories': _requiredCategories,
    'serializedFormats': _serializedFormats,
    'roundTripDirections': _roundTripDirections,
    'cases': [
      for (final fixtureCase in cases)
        {
          'id': fixtureCase['id'],
          'category': fixtureCase['category'],
        },
    ],
  };
}

Map<String, Object?> _schema() {
  return {
    'schema': 'compat-fixture-manifest',
    'version': 1,
    'requiredTopLevelKeys': [
      'schemaVersion',
      'generatedBy',
      'caseFile',
      'requiredCategories',
      'serializedFormats',
      'roundTripDirections',
      'cases',
    ],
    'caseRequiredKeys': [
      'id',
      'category',
      'description',
      'formats',
      'roundTrips',
    ],
    'roundTripRequiredKeys': [
      'direction',
      'format',
      'payloadHex',
    ],
  };
}

void _writeJson(File file, Map<String, Object?> value) {
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(value)}\n');
}

Future<void> _writeJsonLines(
  File file,
  Iterable<Map<String, Object?>> values,
) async {
  final sink = file.openWrite();
  try {
    for (final value in values) {
      sink.writeln(jsonEncode(value));
    }
  } finally {
    await sink.close();
  }
}
