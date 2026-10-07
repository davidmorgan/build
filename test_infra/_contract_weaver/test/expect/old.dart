// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'contracts.dart';

@Invariant('count >= 0')
class Counter {
  int count = 0;

  @Ensures('count == old(count) + delta')
  @ThrowEnsures(StateError, 'count == old(count)')
  void add(int delta) {
    if (delta < 0) throw StateError('negative');
    count += delta;
  }

  @Ensures('result == old(count)')
  int reset() {
    final before = count;
    count = 0;
    return before;
  }
}
