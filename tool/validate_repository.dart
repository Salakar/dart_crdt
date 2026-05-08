import 'dart:io';

const _implementationLineLimit = 300;
const _testLineLimit = 250;

final _forbiddenReference = RegExp('y' 'js', caseSensitive: false);

const _ignoredDirectories = {
  '.dart_tool',
  '.git',
  '.idea',
  '.melos_tool',
  '.pub',
  '.vscode',
  'build',
  'coverage',
  'y' 'js_clone',
};

const _allowedReferenceFiles = {
  'PLAN.md',
  'README.md',
  'TODO.md',
};

const _scannedExtensions = {
  '.dart',
  '.md',
  '.yaml',
  '.yml',
};

void main(List<String> args) {
  final root = _rootFromArgs(args);
  final failures = <String>[
    ..._checkFileSizes(root),
    ..._checkForbiddenReferences(root),
  ];

  if (failures.isEmpty) {
    stdout.writeln('Repository validation passed.');
    return;
  }

  stderr.writeln('Repository validation failed:');
  for (final failure in failures) {
    stderr.writeln('- $failure');
  }
  exitCode = 1;
}

Directory _rootFromArgs(List<String> args) {
  if (args.isEmpty) {
    return Directory.current;
  }
  if (args.length == 2 && args.first == '--root') {
    return Directory(args.last);
  }
  stderr
      .writeln('Usage: dart run tool/validate_repository.dart [--root <path>]');
  exit(64);
}

Iterable<String> _checkFileSizes(Directory root) sync* {
  for (final file in _files(root)) {
    final relativePath = _relativePath(root, file);
    final limit = _lineLimitFor(relativePath);
    if (limit == null) {
      continue;
    }

    final lineCount = _lineCount(file);
    if (lineCount > limit) {
      yield '$relativePath has $lineCount lines; limit is $limit.';
    }
  }
}

Iterable<String> _checkForbiddenReferences(Directory root) sync* {
  for (final file in _files(root)) {
    final relativePath = _relativePath(root, file);
    if (!_shouldScanForReferences(relativePath)) {
      continue;
    }

    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index++) {
      if (_forbiddenReference.hasMatch(lines[index])) {
        yield '$relativePath:${index + 1} contains a forbidden reference.';
      }
    }
  }
}

Iterable<File> _files(Directory root) sync* {
  if (!root.existsSync()) {
    return;
  }

  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    final relativePath = _relativePath(root, entity);
    if (_isIgnored(relativePath)) {
      continue;
    }
    if (entity is File) {
      yield entity;
    }
  }
}

bool _isIgnored(String relativePath) {
  final segments = relativePath.split('/');
  return segments.any(_ignoredDirectories.contains);
}

int? _lineLimitFor(String relativePath) {
  if (!relativePath.endsWith('.dart')) {
    return null;
  }
  final segments = relativePath.split('/');
  if (_containsSegment(segments, 'lib')) {
    return _implementationLineLimit;
  }
  if (_containsSegment(segments, 'test')) {
    return _testLineLimit;
  }
  return null;
}

bool _shouldScanForReferences(String relativePath) {
  if (_allowedReferenceFiles.contains(relativePath)) {
    return false;
  }
  if (!_hasScannedExtension(relativePath)) {
    return false;
  }

  return relativePath.startsWith('.github/') ||
      relativePath.startsWith('packages/') ||
      relativePath == 'analysis_options.yaml' ||
      relativePath == 'melos.yaml' ||
      relativePath == 'pubspec.yaml' ||
      relativePath == 'CONTRIBUTING.md' ||
      relativePath == 'SECURITY.md' ||
      relativePath == 'CODE_OF_CONDUCT.md';
}

bool _hasScannedExtension(String relativePath) {
  for (final extension in _scannedExtensions) {
    if (relativePath.endsWith(extension)) {
      return true;
    }
  }
  return false;
}

bool _containsSegment(List<String> segments, String value) {
  for (final segment in segments) {
    if (segment == value) {
      return true;
    }
  }
  return false;
}

int _lineCount(File file) {
  if (file.lengthSync() == 0) {
    return 0;
  }
  return file.readAsLinesSync().length;
}

String _relativePath(Directory root, FileSystemEntity entity) {
  final rootPath = _normalizePath(root.absolute.path);
  final entityPath = _normalizePath(entity.absolute.path);
  final rootPrefix = rootPath.endsWith('/') ? rootPath : '$rootPath/';

  if (entityPath == rootPath) {
    return '';
  }
  if (entityPath.startsWith(rootPrefix)) {
    return entityPath.substring(rootPrefix.length);
  }
  return entityPath;
}

String _normalizePath(String path) {
  return path.replaceAll(r'\', '/');
}
