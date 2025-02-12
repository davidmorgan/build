// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

import '../asset/id.dart';

/// The filesystem the build is running on.
abstract interface class Filesystem {
  bool existsSync(AssetId id);
  String readAsStringSync(AssetId id);
  Uint8List readAsBytesSync(AssetId id);
}
