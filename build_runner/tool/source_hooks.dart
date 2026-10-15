// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Proof of concept: runs the source hooks a package declares.
//
// Usage: dart tool/source_hooks.dart PACKAGE_DIR complete|check
//
// This stands in for a tool such as an IDE, the analyzer or CI. It reads the
// source hooks pub recorded in `.dart_tool/package_graph.json`, resolves each
// named package through `.dart_tool/package_config.json`, runs that package's
// `hook/source.dart` with an input JSON file and prints the output JSON.
//
// Exits 0 if every hook reports `complete`, 1 if any reports `incomplete`
// and 2 if any fails.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2 ||
      (arguments[1] != 'complete' && arguments[1] != 'check')) {
    stderr.writeln('Usage: source_hooks.dart PACKAGE_DIR complete|check');
    exit(64);
  }
  final packageDir = Directory(arguments[0]).absolute.path;
  final mode = arguments[1];

  final pubspec =
      loadYaml(await File(p.join(packageDir, 'pubspec.yaml')).readAsString())
          as YamlMap;
  final packageName = pubspec['name'] as String;
  final (:packageRoots, :sourceHooks) = await _readPubOutput(packageDir);
  final hooks = sourceHooks[packageName] ?? const <String>[];
  if (hooks.isEmpty) {
    print('$packageName declares no source hooks.');
    return;
  }

  final tempDir = await Directory.systemTemp.createTemp('source_hooks');
  var worstExitCode = 0;
  try {
    for (final hook in hooks) {
      final hookRoot = packageRoots[hook];
      if (hookRoot == null) {
        stderr.writeln('Source hook package not found: $hook');
        worstExitCode = 2;
        continue;
      }
      final hookFile = File(p.join(hookRoot, 'hook', 'source.dart'));
      if (!hookFile.existsSync()) {
        stderr.writeln('Package $hook has no hook/source.dart.');
        worstExitCode = 2;
        continue;
      }

      final inputFile = File(p.join(tempDir.path, '$hook.input.json'));
      final outFile = File(p.join(tempDir.path, '$hook.output.json'));
      await inputFile.writeAsString(
        json.encode({
          'package_root': Directory(packageDir).uri.toString(),
          'package_name': packageName,
          'out_file': outFile.uri.toString(),
          'config': {'mode': mode},
        }),
      );

      final process = await Process.run(Platform.resolvedExecutable, [
        hookFile.path,
        '--config=${inputFile.path}',
      ]);
      if (process.exitCode != 0 || !outFile.existsSync()) {
        stderr
          ..writeln(
            'Source hook $hook failed with exit code '
            '${process.exitCode}.',
          )
          ..write(process.stdout)
          ..write(process.stderr);
        worstExitCode = 2;
        continue;
      }

      final output =
          json.decode(await outFile.readAsString()) as Map<String, Object?>;
      print('== $hook ($mode)');
      print(const JsonEncoder.withIndent('  ').convert(output));
      final exitCode = switch (output['status']) {
        'complete' => 0,
        'incomplete' => 1,
        _ => 2,
      };
      if (exitCode > worstExitCode) worstExitCode = exitCode;
    }
  } finally {
    await tempDir.delete(recursive: true);
  }
  exit(worstExitCode);
}

/// Package roots from `package_config.json` and source hooks from
/// `package_graph.json`, both as written by pub, found above [packageDir].
Future<
  ({Map<String, String> packageRoots, Map<String, List<String>> sourceHooks})
>
_readPubOutput(String packageDir) async {
  var directory = Directory(packageDir);
  while (true) {
    final dartTool = p.join(directory.path, '.dart_tool');
    final configFile = File(p.join(dartTool, 'package_config.json'));
    if (configFile.existsSync()) {
      final config =
          json.decode(await configFile.readAsString()) as Map<String, Object?>;
      final packageRoots = <String, String>{};
      for (final package in config['packages'] as List<Object?>) {
        package as Map<String, Object?>;
        final rootUri = configFile.uri.resolve(package['rootUri'] as String);
        packageRoots[package['name'] as String] = rootUri.toFilePath();
      }
      final sourceHooks = <String, List<String>>{};
      final graphFile = File(p.join(dartTool, 'package_graph.json'));
      if (graphFile.existsSync()) {
        final graph =
            json.decode(await graphFile.readAsString()) as Map<String, Object?>;
        for (final package in graph['packages'] as List<Object?>) {
          package as Map<String, Object?>;
          final hooks = package['sourceHooks'] as List<Object?>?;
          if (hooks != null) {
            sourceHooks[package['name'] as String] = hooks.cast<String>();
          }
        }
      }
      return (packageRoots: packageRoots, sourceHooks: sourceHooks);
    }
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('No .dart_tool/package_config.json above $packageDir.');
    }
    directory = parent;
  }
}
