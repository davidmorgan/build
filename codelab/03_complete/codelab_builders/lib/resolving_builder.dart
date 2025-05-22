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
    final resolvedContent = await buildStep.resolver.libraryFor(
      buildStep.inputId,
    );

    var found = false;
    for (final metadata in resolvedContent.metadata) {
      if (metadata.element?.library?.source.uri.toString() ==
          'package:codelab_annotations/codelab_annotations.dart') {
        if (metadata.computeConstantValue()?.toStringValue() == 'count') {
          found = true;
        }
      }
    }
    if (!found) return;

    final content = await buildStep.readAsString(buildStep.inputId);
    final count = content.length;
    await buildStep.writeAsString(
      buildStep.inputId.changeExtension('.count'),
      '$count\n',
    );
  }
}
