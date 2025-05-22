// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:end_to_end_test/value.dart';
import 'package:test/test.dart';

void main() {
  group('Value', () {
    test('has value equality', () {
      expect(Value(1, 2), Value(1, 2));
      expect(Value(1, 2), isNot(Value(2, 3)));
    });
  });
}
