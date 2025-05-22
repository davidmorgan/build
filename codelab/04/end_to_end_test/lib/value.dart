// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:codelab_annotations/codelab_annotations.dart';

part 'value.equality.dart';

@equality
class Value {
  int x;
  int y;

  Value(this.x, this.y);

  @override
  String toString() => 'Value($x, $y)';
}
