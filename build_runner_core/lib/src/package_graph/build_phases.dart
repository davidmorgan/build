// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:built_collection/built_collection.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';

import '../generate/exceptions.dart';
import '../generate/phase.dart';

class BuildPhases {
  BuiltList<BuildPhase> buildPhases;

  BuildPhases(Iterable<BuildPhase> buildPhases)
    : buildPhases = buildPhases.toBuiltList();

  int get length => buildPhases.length;

  BuildPhase operator [](int index) => buildPhases[index];

  /// Checks that the [buildPhases] are valid based on whether they are
  /// written to the build cache.
  ///
  /// If any are invalid, logs at `severe` level then throws
  /// [CannotBuildException].
  void checkBuildPhases(String root, Logger logger) {
    for (final action in buildPhases) {
      if (!action.hideOutput) {
        // Only `InBuildPhase`s can be not hidden.
        if (action is InBuildPhase && action.package != root) {
          // This should happen only with a manual build script since the build
          // script generation filters these out.
          logger.severe(
            'A build phase (${action.builderLabel}) is attempting '
            'to operate on package "${action.package}", but the build script '
            'is located in package "$root". It\'s not valid to attempt to '
            'generate files for another package unless the BuilderApplication'
            'specified "hideOutput".'
            '\n\n'
            'Did you mean to write:\n'
            '  new BuilderApplication(..., toRoot())\n'
            'or\n'
            '  new BuilderApplication(..., hideOutput: true)\n'
            '... instead?',
          );
          throw const CannotBuildException();
        }
      }
    }
  }

  Digest computeDigest() {
    var digestSink = AccumulatorSink<Digest>();
    md5.startChunkedConversion(digestSink)
      ..add(buildPhases.map((phase) => phase.identity).toList())
      ..close();
    assert(digestSink.events.length == 1);
    return digestSink.events.first;
  }
}
