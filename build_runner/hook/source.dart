// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Proof of concept: a source hook for `build_runner`.
//
// A package opts in by listing `build_runner` under `source_hooks:` in its
// `pubspec.yaml`. A tool then runs this file with `--config=INPUT`, where
// INPUT is a JSON file shaped like a `package:hooks` input:
//
//     {
//       "package_root": "/path/to/package/",
//       "package_name": "my_package",
//       "out_file": "/path/to/output.json",
//       "config": {"mode": "complete"}
//     }
//
// Mode `complete` makes the source complete, by running `build`. Mode `check`
// writes nothing and reports whether the source is complete, by running
// `build --only-check`.
//
// The output JSON has `status`, which is `complete`, `incomplete` or `failed`,
// plus what is stale and the `part` directives to add or remove. The details
// are parsed from the log, which is enough for a proof of concept; a real
// hook would get them from the build result.

import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final configPath = _configPath(arguments);
  final input =
      json.decode(await File(configPath).readAsString())
          as Map<String, Object?>;
  final packageRoot = Uri.parse(input['package_root'] as String);
  final outFile = Uri.parse(input['out_file'] as String);
  final config = input['config'] as Map<String, Object?>;
  final mode = config['mode'] as String;
  if (mode != 'complete' && mode != 'check') {
    stderr.writeln('Unknown mode: $mode');
    exit(64);
  }

  final process = await Process.run(Platform.resolvedExecutable, [
    'run',
    'build_runner',
    'build',
    if (mode == 'check') '--only-check',
  ], workingDirectory: packageRoot.toFilePath());
  final log = '${process.stdout}${process.stderr}';

  final output = _parseLog(log, mode: mode, exitCode: process.exitCode);
  await File.fromUri(
    outFile,
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(output));
}

String _configPath(List<String> arguments) {
  for (var i = 0; i != arguments.length; ++i) {
    final argument = arguments[i];
    if (argument.startsWith('--config=')) {
      return argument.substring('--config='.length);
    }
    if (argument == '--config' && i + 1 < arguments.length) {
      return arguments[i + 1];
    }
  }
  stderr.writeln('Usage: source.dart --config=INPUT');
  exit(64);
}

/// Parses the `build_runner` log into the hook's output.
Map<String, Object?> _parseLog(
  String log, {
  required String mode,
  required int exitCode,
}) {
  final staleOutputs = <Map<String, String>>[];
  final partDirectivesToAdd = <String>[];
  final partDirectivesToRemove = <String>[];
  final staleStates = {'I': 'incorrect', 'M': 'missing', 'U': 'unexpected'};

  List<String>? currentList;
  for (final rawLine in const LineSplitter().convert(log)) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    if (line.contains('missing `part` directives')) {
      currentList = partDirectivesToAdd;
      continue;
    }
    if (line.contains('unused `part` directives')) {
      currentList = partDirectivesToRemove;
      continue;
    }
    if (line.length > 2 && line[1] == ' ' && staleStates.containsKey(line[0])) {
      staleOutputs.add({
        'path': line.substring(2),
        'state': staleStates[line[0]]!,
      });
      continue;
    }
    if (currentList != null && line.contains(": part '")) {
      currentList.add(line);
      continue;
    }
    currentList = null;
  }

  final String status;
  if (exitCode == 0 &&
      staleOutputs.isEmpty &&
      (mode == 'complete' ||
          partDirectivesToAdd.isEmpty && partDirectivesToRemove.isEmpty)) {
    status = 'complete';
  } else if (staleOutputs.isNotEmpty ||
      partDirectivesToAdd.isNotEmpty ||
      partDirectivesToRemove.isNotEmpty) {
    status = 'incomplete';
  } else {
    status = 'failed';
  }

  return {
    'status': status,
    'mode': mode,
    'stale_outputs': staleOutputs,
    'part_directives_to_add': partDirectivesToAdd,
    'part_directives_to_remove': partDirectivesToRemove,
    if (status == 'failed') 'log': log,
  };
}
