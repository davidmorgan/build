// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'source_edit.dart';

/// An error reported by a builder, with an [edit] to its primary input that
/// fixes it.
class ErrorFix {
  final String message;
  final SourceEdit edit;

  ErrorFix.of({required this.message, required this.edit});
}
