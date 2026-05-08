import 'dart:io';

const _packageRoot = 'packages/ycrdt';
const _longRandomTests = [
  'test/integration/random_sequence_convergence_test.dart',
  'test/integration/random_map_convergence_test.dart',
  'test/integration/random_text_convergence_test.dart',
  'test/integration/shared/sequence_regression_test.dart',
  'test/integration/shared/map_regression_test.dart',
  'test/integration/shared/text_regression_test.dart',
];
const _longFuzzTests = [
  'test/integration/fuzz/invalid_input_fuzz_test.dart',
];

Future<void> main(List<String> args) async {
  final skipFuzz = args.contains('--skip-fuzz');
  final failures = <String>[];

  failures.addAll(
    await _runSuite(
      label: 'long random convergence',
      tests: _longRandomTests,
      environment: const {'YCRDT_LONG_RANDOM': '1'},
    ),
  );

  if (!skipFuzz) {
    failures.addAll(
      await _runSuite(
        label: 'long invalid-input fuzz',
        tests: _longFuzzTests,
        environment: const {'YCRDT_LONG_FUZZ': '1'},
      ),
    );
  }

  if (failures.isEmpty) {
    stdout.writeln('Long random validation passed.');
    return;
  }

  stderr.writeln('Long random validation failed:');
  for (final failure in failures) {
    stderr.writeln('- $failure');
  }
  exitCode = 1;
}

Future<List<String>> _runSuite({
  required String label,
  required List<String> tests,
  required Map<String, String> environment,
}) async {
  stdout.writeln('Running $label...');
  final result = await Process.run(
    Platform.resolvedExecutable,
    ['test', ...tests],
    workingDirectory: _packageRoot,
    environment: environment,
  );

  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode == 0) {
    return const [];
  }
  return ['$label exited with ${result.exitCode}.'];
}
