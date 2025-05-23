// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';

class FormatBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => {
    '.dart': ['.formatted'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final content = await buildStep.readAsString(buildStep.inputId);

    final formattedContent = DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    ).format(content);

    if (content != formattedContent) {
      await buildStep.writeAsString(
        buildStep.inputId.changeExtension('.formatted'),
        formattedContent,
      );
    }
  }
}
