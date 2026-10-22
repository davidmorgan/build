// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@Tags(['integration4'])
library;

import 'package:build_runner/src/logging/build_log.dart';
import 'package:test/test.dart';

import '../common/common.dart';

void main() {
  test('build command error with fix', () async {
    final pubspecs = await Pubspecs.load();
    final tester = BuildRunnerTester(pubspecs);

    tester.writePackage(
      name: 'fix_pkg',
      dependencies: ['build', 'build_runner'],
      files: {
        'build.yaml': r'''
builders:
  fix_builder:
    import: 'package:fix_pkg/builder.dart'
    builder_factories: ['fixBuilderFactory']
    build_extensions: {'.dart': ['.txt']}
    build_to: 'source'
    auto_apply: root_package
''',
        'lib/builder.dart': r'''
import 'package:build/build.dart';

Builder fixBuilderFactory(BuilderOptions options) => FixBuilder();

/// Fails with a fix while the input says `oldName`; otherwise writes `.txt`.
class FixBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => {'.dart': ['.txt']};

  @override
  Future<void> build(BuildStep buildStep) async {
    final source = await buildStep.readAsString(buildStep.inputId);
    final offset = source.indexOf('oldName');
    if (offset != -1) {
      buildStep.reportErrorWithFix(
        'Rename oldName to newName.',
        offset: offset,
        length: 'oldName'.length,
        replacement: 'newName',
      );
      return;
    }
    await buildStep.writeAsString(
      buildStep.inputId.changeExtension('.txt'),
      'ok',
    );
  }
}
''',
      },
    );

    tester.writePackage(
      name: 'root_pkg',
      dependencies: ['build_runner'],
      pathDependencies: ['fix_pkg'],
      files: {'lib/a.dart': 'class A { int oldName = 0; }\n'},
    );

    // With `--only-check`, the error and its fix are reported and nothing
    // is changed.
    var output = await tester.run(
      'root_pkg',
      'dart run build_runner build --force-jit --only-check',
      expectExitCode: 1,
    );
    expect(output, contains(BuildLog.failurePattern));
    expect(output, contains('Fix errors in sources:'));
    expect(output, contains('lib/a.dart: Rename oldName to newName.'));
    expect(
      tester.read('root_pkg/lib/a.dart'),
      'class A { int oldName = 0; }\n',
    );
    expect(tester.read('root_pkg/lib/a.txt'), isNull);

    // Otherwise the fix is applied and the build reruns.
    output = await tester.run(
      'root_pkg',
      'dart run build_runner build --force-jit',
    );
    expect(output, contains('Fixed errors in sources:'));
    expect(output, contains('lib/a.dart: Rename oldName to newName.'));
    expect(output, contains(BuildLog.successPattern));
    expect(
      tester.read('root_pkg/lib/a.dart'),
      'class A { int newName = 0; }\n',
    );
    expect(tester.read('root_pkg/lib/a.txt'), 'ok');
  });
}
