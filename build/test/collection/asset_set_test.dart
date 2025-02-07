// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:build/build.dart';
import 'package:test/test.dart';

void main() {
  final id1 = AssetId.parse('foo|bar1.dart');
  final id2 = AssetId.parse('foo|bar2.dart');
  final id3 = AssetId.parse('foo|bar3.dart');

  group('AssetSet', () {
    test('empty', () {
      final set = AssetSet();
      expect(set, <AssetId>[]);
      expect(set.length, 0);
    });

    test('double add', () {
      final subset = AssetSet.of([id1, id2, id3]);
      final set = AssetSet();
      expect(set, <AssetId>{});

      final set1 = set.rebuild((b) => b..addAssetSet(subset));
      expect(set1, {id1, id2, id3});

      final set2 = set1.rebuild((b) => b..addAssetSet(subset));
      expect(set2, {id1, id2, id3});

      expect(identical(set1, set2), isTrue);
    });

    test('remove', () {
      final subset = AssetSet.of([id1, id2, id3]);
      var set = AssetSet().rebuild((b) => b..addAssetSet(subset));
      expect(set, {id1, id2, id3});

      set = set.rebuild((b) => b..remove(id2));
      expect(set, {id1, id3});
    });

    test('removeAll', () {
      final subset = AssetSet.of([id1, id2, id3]);
      var set = AssetSet().rebuild((b) => b..addAssetSet(subset));
      expect(set, {id1, id2, id3});

      set = set.rebuild((b) => b..removeAll({id1, id3}));
      expect(set, {id2});
    });
  });
}
