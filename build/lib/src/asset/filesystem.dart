// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'id.dart';
import 'reader.dart';

void LOG(String message) {
  File('/tmp/filesystem.txt')
      .writeAsStringSync('$message\n', mode: FileMode.append);
}

/// State corresponding 1:1 with an underlying filesystem.
abstract interface class Filesystem {
  bool existsSync(AssetId id);
  String readAsStringSync(AssetId id);
}

abstract interface class HasFilesystem {
  Filesystem get filesystem;
}

extension AssetReaderExtension on AssetReader {
  Filesystem get filesystem {
    if (this is HasFilesystem) {
      return (this as HasFilesystem).filesystem;
    }
    LOG('Does not implement HasFilesystem: $this');
    return FakeFilesystem();
  }
}

class FakeFilesystem implements Filesystem {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
