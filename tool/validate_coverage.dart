import 'dart:io';

const _defaultPackageRoot = 'packages/dart_crdt';
const _defaultLcovPath = 'packages/dart_crdt/coverage/lcov.info';
const _overallThreshold = 95.0;
const _strictThreshold = 100.0;

const _strictPaths = {
  'lib/src/binary/any_codec.dart',
  'lib/src/binary/byte_reader.dart',
  'lib/src/binary/byte_writer.dart',
  'lib/src/binary/rle_codec.dart',
  'lib/src/binary/string_buffer_codec.dart',
  'lib/src/binary/string_table.dart',
  'lib/src/binary/uint_opt_rle_codec.dart',
  'lib/src/binary/varint_codec.dart',
  'lib/src/metadata/id_map.dart',
  'lib/src/metadata/id_map_codec.dart',
  'lib/src/metadata/id_range.dart',
  'lib/src/metadata/id_ranges.dart',
  'lib/src/metadata/id_set.dart',
  'lib/src/metadata/id_set_codec.dart',
  'lib/src/sync/update_algebra.dart',
};

void main(List<String> args) {
  final options = _Options.parse(args);
  final lcov = File(options.lcovPath);
  if (!lcov.existsSync()) {
    stderr.writeln('Coverage file not found: ${options.lcovPath}');
    exitCode = 1;
    return;
  }

  final records = _readLcov(lcov, options.packageRoot);
  final failures = <String>[
    ..._checkOverall(records),
    ..._checkStrict(records),
  ];

  if (failures.isEmpty) {
    final total = _sum(records);
    stdout.writeln(
      'Coverage validation passed: ${total.percentString} overall.',
    );
    return;
  }

  stderr.writeln('Coverage validation failed:');
  for (final failure in failures) {
    stderr.writeln('- $failure');
  }
  exitCode = 1;
}

Iterable<String> _checkOverall(List<_CoverageRecord> records) sync* {
  final total = _sum(records);
  if (total.percent < _overallThreshold) {
    yield 'overall line coverage is ${total.percentString}; '
        'required ${_overallThreshold.toStringAsFixed(2)}%.';
  }
}

Iterable<String> _checkStrict(List<_CoverageRecord> records) sync* {
  final byPath = {for (final record in records) record.path: record};
  for (final path in _strictPaths) {
    final record = byPath[path];
    if (record == null) {
      yield '$path is missing from LCOV output.';
    } else if (record.percent < _strictThreshold) {
      yield '$path line coverage is ${record.percentString}; '
          'required ${_strictThreshold.toStringAsFixed(2)}%.';
    }
  }
}

_CoverageRecord _sum(List<_CoverageRecord> records) {
  return _CoverageRecord(
    path: 'TOTAL',
    found: records.fold(0, (sum, record) => sum + record.found),
    hit: records.fold(0, (sum, record) => sum + record.hit),
  );
}

List<_CoverageRecord> _readLcov(File file, String packageRoot) {
  final records = <_CoverageRecord>[];
  String? path;
  var found = 0;
  var hit = 0;

  void flush() {
    final currentPath = path;
    if (currentPath != null && currentPath.startsWith('lib/')) {
      records.add(_CoverageRecord(path: currentPath, found: found, hit: hit));
    }
    path = null;
    found = 0;
    hit = 0;
  }

  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      flush();
      path = _normalizeSource(line.substring(3), packageRoot);
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      if (parts.length < 2) {
        throw FormatException('Malformed LCOV DA line: $line');
      }
      found += 1;
      if ((int.tryParse(parts[1]) ?? 0) > 0) {
        hit += 1;
      }
    } else if (line == 'end_of_record') {
      flush();
    }
  }
  flush();
  return List<_CoverageRecord>.unmodifiable(records);
}

String _normalizeSource(String source, String packageRoot) {
  final normalized = source.replaceAll(r'\', '/');
  final marker = '${packageRoot.replaceAll(r'\', '/')}/';
  final index = normalized.lastIndexOf(marker);
  if (index >= 0) {
    return normalized.substring(index + marker.length);
  }
  return normalized;
}

final class _CoverageRecord {
  const _CoverageRecord({
    required this.path,
    required this.found,
    required this.hit,
  });

  final String path;
  final int found;
  final int hit;

  double get percent => found == 0 ? 100 : hit * 100 / found;

  String get percentString {
    return '${percent.toStringAsFixed(2)}% ($hit/$found)';
  }
}

final class _Options {
  const _Options({required this.packageRoot, required this.lcovPath});

  final String packageRoot;
  final String lcovPath;

  factory _Options.parse(List<String> args) {
    var packageRoot = _defaultPackageRoot;
    var lcovPath = _defaultLcovPath;
    for (var index = 0; index < args.length; index += 1) {
      switch (args[index]) {
        case '--package-root':
          index += 1;
          packageRoot = _value(args, index, '--package-root');
        case '--lcov':
          index += 1;
          lcovPath = _value(args, index, '--lcov');
        default:
          _usage();
      }
    }
    return _Options(packageRoot: packageRoot, lcovPath: lcovPath);
  }
}

String _value(List<String> args, int index, String option) {
  if (index >= args.length) {
    stderr.writeln('Missing value for $option.');
    _usage();
  }
  return args[index];
}

Never _usage() {
  stderr.writeln(
    'Usage: dart run tool/validate_coverage.dart '
    '[--package-root <path>] [--lcov <path>]',
  );
  exit(64);
}
