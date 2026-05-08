import 'dart:io';

import 'src/benchmark_runner.dart';
import 'src/benchmark_thresholds.dart';

void main(List<String> arguments) {
  final options = _BenchmarkOptions.parse(arguments);
  if (options.showHelp) {
    stdout.writeln(_usage);
    return;
  }

  final result = runDartCrdtBenchmarks(mode: options.mode);
  final output = result.encode(pretty: options.pretty);
  final outputPath = options.outputPath;

  if (outputPath == null) {
    stdout.writeln(output);
  } else {
    final outputFile = File(outputPath);
    outputFile.parent.createSync(recursive: true);
    outputFile.writeAsStringSync('$output\n');
  }

  final thresholdPath = options.thresholdPath ??
      (options.mode == BenchmarkMode.smoke ? defaultSmokeThresholdPath : null);
  if (thresholdPath != null) {
    final failures = validateBenchmarkThresholds(
      result,
      loadBenchmarkThresholds(thresholdPath),
    );
    if (failures.isNotEmpty) {
      stderr.writeln('Benchmark thresholds failed:');
      for (final failure in failures) {
        stderr.writeln('- ${failure.message}');
      }
      exitCode = 1;
    }
  }
}

const _usage = '''
Usage: dart run benchmark/benchmark.dart [options]

Options:
  --mode=<smoke|full>  Benchmark suite mode. Defaults to smoke.
  --smoke              Alias for --mode=smoke.
  --full               Alias for --mode=full.
  --pretty             Emit pretty-printed JSON.
  --output=<path>      Write JSON to a file instead of stdout.
  --thresholds=<path>  Validate results against a threshold fixture.
  --help               Show this help.
''';

final class _BenchmarkOptions {
  const _BenchmarkOptions({
    required this.mode,
    required this.pretty,
    required this.showHelp,
    this.outputPath,
    this.thresholdPath,
  });

  final BenchmarkMode mode;
  final bool pretty;
  final bool showHelp;
  final String? outputPath;
  final String? thresholdPath;

  static _BenchmarkOptions parse(List<String> arguments) {
    var mode = BenchmarkMode.smoke;
    var pretty = false;
    var showHelp = false;
    String? outputPath;
    String? thresholdPath;

    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      if (argument == '--help' || argument == '-h') {
        showHelp = true;
      } else if (argument == '--pretty') {
        pretty = true;
      } else if (argument == '--smoke') {
        mode = BenchmarkMode.smoke;
      } else if (argument == '--full') {
        mode = BenchmarkMode.full;
      } else if (argument.startsWith('--mode=')) {
        mode = parseBenchmarkMode(argument.substring('--mode='.length));
      } else if (argument == '--mode') {
        index++;
        _requireValue(arguments, index, '--mode');
        mode = parseBenchmarkMode(arguments[index]);
      } else if (argument.startsWith('--output=')) {
        outputPath = argument.substring('--output='.length);
      } else if (argument == '--output') {
        index++;
        _requireValue(arguments, index, '--output');
        outputPath = arguments[index];
      } else if (argument.startsWith('--thresholds=')) {
        thresholdPath = argument.substring('--thresholds='.length);
      } else if (argument == '--thresholds') {
        index++;
        _requireValue(arguments, index, '--thresholds');
        thresholdPath = arguments[index];
      } else {
        throw ArgumentError.value(argument, 'argument', 'Unknown option.');
      }
    }

    return _BenchmarkOptions(
      mode: mode,
      pretty: pretty,
      showHelp: showHelp,
      outputPath: outputPath,
      thresholdPath: thresholdPath,
    );
  }
}

void _requireValue(List<String> arguments, int index, String option) {
  if (index >= arguments.length) {
    throw ArgumentError.value(option, 'option', 'Expected a value.');
  }
}
