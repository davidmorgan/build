// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:build/build.dart';
import 'package:build_runner/src/build/source_required_edits.dart';
import 'package:test/test.dart';

void main() {
  RequiredEdit edit(int offset, int length, String replacement) => RequiredEdit(
    message: 'm',
    offset: offset,
    length: length,
    replacement: replacement,
  );

  group('SourceRequiredEdits.applyTo', () {
    test('applies edits in any order', () {
      expect(
        SourceRequiredEdits.applyTo('abcdef', [
          edit(0, 1, 'A'),
          edit(4, 2, 'EF'),
          edit(2, 0, '-'),
        ]),
        'Ab-cdEF',
      );
    });

    test('applies adjacent edits', () {
      expect(
        SourceRequiredEdits.applyTo('abcd', [edit(0, 2, 'X'), edit(2, 2, 'Y')]),
        'XY',
      );
    });

    test('skips an edit that overlaps a later one', () {
      expect(
        SourceRequiredEdits.applyTo('abcd', [edit(0, 3, 'X'), edit(2, 2, 'Y')]),
        'abY',
      );
    });

    test('skips an edit past the end', () {
      expect(
        SourceRequiredEdits.applyTo('abcd', [edit(3, 2, 'X'), edit(0, 1, 'A')]),
        'Abcd',
      );
    });

    test('keeps insertions at one offset in the order reported', () {
      expect(
        SourceRequiredEdits.applyTo('ab', [edit(1, 0, '1'), edit(1, 0, '2')]),
        'a12b',
      );
    });
  });
}
