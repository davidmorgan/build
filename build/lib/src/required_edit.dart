// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// An edit to a build step's primary input that is required to fix the error
/// [message].
///
/// The edit replaces [length] characters at [offset] with [replacement].
///
/// Experimental, may change following feedback and discussion at
/// https://github.com/dart-lang/build/discussions.
class RequiredEdit {
  final String message;
  final int offset;
  final int length;
  final String replacement;

  const RequiredEdit({
    required this.message,
    required this.offset,
    required this.length,
    required this.replacement,
  });
}
