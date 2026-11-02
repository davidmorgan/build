// Copyright (c) 2018, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'built_value_generator.dart';

/// Generates with `BuildStep.librarySourceSink`.
///
/// Generated code goes to the shared part `lib/_br_/<path>.part.dart` that
/// `build_runner` writes and adds the `part` directive for.
///
/// `BuildStep.librarySourceSink` is experimental, so this package allows only
/// one minor version of `build_runner`.
Builder builtValue(BuilderOptions _) => const _LibrarySourceSinkBuilder();

class _LibrarySourceSinkBuilder implements Builder {
  const _LibrarySourceSinkBuilder();

  @override
  Map<String, List<String>> get buildExtensions => const {'.dart': []};

  @override
  Future<void> build(BuildStep buildStep) async {
    if (!await buildStep.resolver.isLibrary(buildStep.inputId)) return;
    final library = LibraryReader(await buildStep.inputLibrary);
    final code = await const BuiltValueGenerator().generate(library, buildStep);
    if (code == null || code.trim().isEmpty) return;
    final sink = await buildStep.librarySourceSink;
    if (sink == null) {
      throw StateError(
        'No `librarySourceSink`: the builder definition must set '
        '`adds_to_library: true`.',
      );
    }
    sink.add(code);
  }
}
