// Copyright (c) 2026, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:built_value_generator/builder.dart';
import 'package:logging/logging.dart';

/// Runs the `built_value` builder as `build_runner` does, with
/// `adds_to_library: true`, on `lib/$library.dart` in package `pkg`.
///
/// Returns the first severe log message if there is one, otherwise the shared
/// part that `build_runner` writes for the library.
Future<String> generateWithLibrarySourceSink(
  Map<String, String> sources,
  String library,
) async {
  final builder = builtValue(BuilderOptions.empty);
  String? error;
  void captureError(LogRecord logRecord) {
    if (logRecord.level != Level.SEVERE) return;
    // build_runner adds the `part` directive itself and reports it at severe.
    if (logRecord.message.startsWith('Added missing `part` directives')) return;
    error ??= logRecord.message;
  }

  final result = await testBuilders(
    [builder],
    sources,
    rootPackage: 'pkg',
    onLog: captureError,
    visibleOutputBuilders: {builder},
    addsToLibraryBuilders: {builder},
  );
  if (error != null) return error!;
  final parts = result.readerWriter.testing.assets
      .where((id) => id.path.endsWith('_br_/$library.part.dart'))
      .toList();
  if (parts.isEmpty) {
    return 'No shared part; assets: ${result.readerWriter.testing.assets}';
  }
  return result.readerWriter.testing.readString(parts.single);
}
