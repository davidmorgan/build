// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Thrown by `BuildStep.failRequiringEdit` to end a build step that has
/// already logged why it failed.
class BuildStepFailedException implements Exception {
  const BuildStepFailedException();

  @override
  String toString() => 'BuildStepFailedException';
}
