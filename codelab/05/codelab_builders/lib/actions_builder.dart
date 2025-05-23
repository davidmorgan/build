// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:build/build.dart';

class ActionsBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => {
    '.dart': ['.actions'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final resolvedContent = await buildStep.resolver.libraryFor(
      buildStep.inputId,
    );

    var runFormat = false;
    for (final metadata in resolvedContent.metadata) {
      if (metadata.element?.library?.source.uri.toString() ==
          'package:codelab_annotations/codelab_annotations.dart') {
        if (metadata.computeConstantValue()?.toStringValue() == 'format') {
          runFormat = true;
        }
      }
    }
    if (!runFormat) return;

    final formattedAsset = buildStep.inputId.changeExtension('.formatted');

    if (await buildStep.canRead(formattedAsset)) {
      final formattedAssetCachedPath =
          '.dart_tool/build/generated/${formattedAsset.package}/${formattedAsset.path}';
      await buildStep.writeAsString(
        buildStep.inputId.changeExtension('.actions'),
        'cp $formattedAssetCachedPath ${buildStep.inputId.path}\n',
      );
    }
  }
}
