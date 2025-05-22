// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';

class EqualityBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => {
    '.dart': ['.equality.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final resolvedContent = await buildStep.resolver.libraryFor(
      buildStep.inputId,
    );

    final classElements = <ClassElement>[];
    for (final classElement
        in resolvedContent.topLevelElements.whereType<ClassElement>()) {
      for (final metadata in classElement.metadata) {
        if (metadata.element?.library?.source.uri.toString() ==
            'package:codelab_annotations/codelab_annotations.dart') {
          if (metadata.computeConstantValue()?.toStringValue() == 'equality') {
            classElements.add(classElement);
            break;
          }
        }
      }
    }
    if (classElements.isEmpty) return;

    final filename = buildStep.inputId.pathSegments.last;
    final buffer = StringBuffer("part of '$filename';\n");

    for (final classElement in classElements) {
      buffer.writeln('// TODO: generate for ${classElement.displayName}');
    }

    await buildStep.writeAsString(
      buildStep.inputId.changeExtension('.equality.dart'),
      '$buffer',
    );
  }
}
