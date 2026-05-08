import 'dart:io';

const _packageRoot = 'packages/ycrdt';
const _requiredPubspecFields = {
  'name:',
  'description:',
  'version:',
  'homepage:',
  'repository:',
  'issue_tracker:',
  'documentation:',
  'topics:',
  'platforms:',
};
const _requiredChangelogSections = {
  'API Changes',
  'Compatibility Summary',
  'Benchmark Summary',
  'Known Limitations',
  'Verification',
};
const _requiredReleasePhrases = {
  'Semantic Versioning',
  'Release Checklist',
  'melos run release:validate',
  'melos run publish:dry-run',
  'API changes',
  'Compatibility summary',
  'Benchmark summary',
  'Known limitations',
  'melos run test:long-random',
};

void main() {
  final failures = <String>[
    ..._checkReleaseGuide(),
    ..._checkContributingGuide(),
    ..._checkPubspec(),
    ..._checkChangelog(),
    ..._checkCi(),
    ..._checkNightly(),
  ];

  if (failures.isEmpty) {
    stdout.writeln('Release validation passed.');
    return;
  }

  stderr.writeln('Release validation failed:');
  for (final failure in failures) {
    stderr.writeln('- $failure');
  }
  exitCode = 1;
}

Iterable<String> _checkReleaseGuide() sync* {
  final file = File('RELEASE.md');
  if (!file.existsSync()) {
    yield 'RELEASE.md is missing.';
    return;
  }

  final contents = file.readAsStringSync();
  for (final phrase in _requiredReleasePhrases) {
    if (!contents.contains(phrase)) {
      yield 'RELEASE.md must mention "$phrase".';
    }
  }
}

Iterable<String> _checkContributingGuide() sync* {
  final file = File('CONTRIBUTING.md');
  if (!file.existsSync()) {
    yield 'CONTRIBUTING.md is missing.';
    return;
  }

  final contents = file.readAsStringSync();
  if (!contents.contains('RELEASE.md')) {
    yield 'CONTRIBUTING.md must link release candidates to RELEASE.md.';
  }
  if (!contents.contains('melos run release:validate')) {
    yield 'CONTRIBUTING.md must include melos run release:validate.';
  }
}

Iterable<String> _checkPubspec() sync* {
  final file = File('$_packageRoot/pubspec.yaml');
  if (!file.existsSync()) {
    yield 'Package pubspec is missing.';
    return;
  }

  final contents = file.readAsStringSync();
  for (final field in _requiredPubspecFields) {
    if (!contents.contains(field)) {
      yield 'pubspec.yaml must include $field';
    }
  }
  if (contents.contains('publish_to: none')) {
    yield 'pubspec.yaml must not contain publish_to: none for releases.';
  }
  final version = _packageVersion();
  if (!_isSemver(version)) {
    yield 'pubspec.yaml version "$version" is not SemVer-compatible.';
  }
}

Iterable<String> _checkChangelog() sync* {
  final file = File('$_packageRoot/CHANGELOG.md');
  if (!file.existsSync()) {
    yield 'Package CHANGELOG.md is missing.';
    return;
  }

  final contents = file.readAsStringSync();
  final version = _packageVersion();
  if (!contents.contains('## $version')) {
    yield 'CHANGELOG.md must include an entry for $version.';
  }
  for (final section in _requiredChangelogSections) {
    if (!contents.contains('### $section')) {
      yield 'CHANGELOG.md must include a "$section" subsection.';
    }
  }
}

Iterable<String> _checkCi() sync* {
  final file = File('.github/workflows/ci.yaml');
  if (!file.existsSync()) {
    yield 'CI workflow is missing.';
    return;
  }

  final contents = file.readAsStringSync();
  if (!contents.contains('melos run release:validate')) {
    yield 'CI must run melos run release:validate.';
  }
  if (!contents.contains('melos run publish:dry-run')) {
    yield 'CI must run melos run publish:dry-run.';
  }
}

Iterable<String> _checkNightly() sync* {
  final file = File('.github/workflows/nightly.yaml');
  if (!file.existsSync()) {
    yield 'Nightly workflow is missing.';
    return;
  }

  final contents = file.readAsStringSync();
  if (!contents.contains('melos run test:long-random')) {
    yield 'Nightly workflow must run melos run test:long-random.';
  }
  if (!contents.contains('melos run js:smoke')) {
    yield 'Nightly workflow must run melos run js:smoke.';
  }
  if (!contents.contains('benchmark/benchmark.dart --mode=full')) {
    yield 'Nightly workflow must run the full benchmark suite.';
  }
}

String _packageVersion() {
  final pubspec = File('$_packageRoot/pubspec.yaml').readAsLinesSync();
  for (final line in pubspec) {
    final trimmed = line.trim();
    if (trimmed.startsWith('version:')) {
      return trimmed.substring('version:'.length).trim();
    }
  }
  return '';
}

bool _isSemver(String version) {
  final expression = RegExp(
    r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
    r'(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?'
    r'(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$',
  );
  return expression.hasMatch(version);
}
