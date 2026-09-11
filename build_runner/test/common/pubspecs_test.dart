// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:test/test.dart';

import 'build_runner_tester.dart';

void main() {
  late Directory copiedPackagesDirectory;

  test('Pubspecs.load copies packages to a temp directory', () async {
    final pubspecs = await Pubspecs.load();
    copiedPackagesDirectory = pubspecs.copiedPackagesDirectory;
    expect(copiedPackagesDirectory.existsSync(), isTrue);
  });

  test('Pubspecs.load deletes the temp directory when the test ends', () {
    expect(copiedPackagesDirectory.existsSync(), isFalse);
  });
}
