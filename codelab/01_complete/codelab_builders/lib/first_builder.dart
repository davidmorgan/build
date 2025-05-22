// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:build/build.dart';

class FirstBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => {
    r'$lib$': ['first_builder_output.txt'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = AssetId(buildStep.inputId.package, 'lib/input.dart');

    String? contents;
    if (await buildStep.canRead(inputId)) {
      contents = await buildStep.readAsString(inputId);
    }
    final output =
        contents == null
            ? 'missing\n'
            : 'read with length ${contents.length}\n';
    await buildStep.writeAsString(
      AssetId(buildStep.inputId.package, 'lib/first_builder_output.txt'),
      output,
    );
  }
}
