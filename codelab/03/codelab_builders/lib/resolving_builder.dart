// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:build/build.dart';

class ResolvingBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => {
    '.dart': ['.count'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final content = await buildStep.readAsString(buildStep.inputId);

    if (!content.contains('@count')) return;

    final count = content.length;
    await buildStep.writeAsString(
      buildStep.inputId.changeExtension('.count'),
      '$count\n',
    );
  }
}
