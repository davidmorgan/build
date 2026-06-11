// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:crypto/crypto.dart';

class DigestedFile {
  final Digest digest;
  final String? content;

  DigestedFile(this.digest, [this.content]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DigestedFile && digest == other.digest;

  @override
  int get hashCode => digest.hashCode;

  @override
  String toString() => 'DigestedFile($digest, content: ${content != null})';
}
