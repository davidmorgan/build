// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@Tags(['integration4'])
library;

import 'package:build_runner/src/logging/build_log.dart';
import 'package:test/test.dart';

import '../common/common.dart';

void main() {
  test('build command required edits', () async {
    final pubspecs = await Pubspecs.load();
    final tester = BuildRunnerTester(pubspecs);

    tester.writePackage(
      name: 'edit_pkg',
      dependencies: ['build', 'build_runner'],
      files: {
        'build.yaml': r'''
builders:
  edit_builder:
    import: 'package:edit_pkg/builder.dart'
    builder_factories: ['editBuilderFactory']
    build_extensions: {'.dart': ['.txt']}
    build_to: 'source'
    auto_apply: root_package
''',
        'lib/builder.dart': r'''
import 'package:build/build.dart';

Builder editBuilderFactory(BuilderOptions options) => EditBuilder();

/// Requires every `oldName` in the input to be renamed, then writes `.txt`.
///
/// Adds a required edit for each `oldName` but the last, then fails
/// requiring the last.
class EditBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => {'.dart': ['.txt']};

  @override
  Future<void> build(BuildStep buildStep) async {
    final source = await buildStep.readAsString(buildStep.inputId);
    final offsets = [
      for (final match in 'oldName'.allMatches(source)) match.start,
    ];
    if (offsets.isNotEmpty) {
      for (final offset in offsets.take(offsets.length - 1)) {
        buildStep.addRequiredEdit(_rename(offset));
      }
      log.warning('Still running after addRequiredEdit.');
      buildStep.failRequiringEdit(_rename(offsets.last));
      // ignore: dead_code
      log.warning('Still running after failRequiringEdit.');
    }
    await buildStep.writeAsString(
      buildStep.inputId.changeExtension('.txt'),
      'ok',
    );
  }

  RequiredEdit _rename(int offset) => RequiredEdit(
    message: 'Rename oldName at $offset to newName.',
    offset: offset,
    length: 'oldName'.length,
    replacement: 'newName',
  );
}
''',
      },
    );

    tester.writePackage(
      name: 'root_pkg',
      dependencies: ['build_runner'],
      pathDependencies: ['edit_pkg'],
      files: {
        'lib/a.dart': 'class A { int oldName = 0; int oldName2 = 0; }\n',
        'lib/b.dart': 'class B {}\n',
      },
    );

    // With `--only-check`, the required edits are reported and nothing is
    // changed.
    var output = await tester.run(
      'root_pkg',
      'dart run build_runner build --force-jit --only-check',
      expectExitCode: 1,
    );
    expect(output, contains(BuildLog.failurePattern));
    expect(output, contains('Still running after addRequiredEdit.'));
    expect(output, isNot(contains('Still running after failRequiringEdit.')));
    expect(output, isNot(contains('Exception')));
    expect(output, contains('Fix errors in sources:'));
    expect(output, contains('lib/a.dart: Rename oldName at 14 to newName.'));
    expect(output, contains('lib/a.dart: Rename oldName at 31 to newName.'));
    expect(
      tester.read('root_pkg/lib/a.dart'),
      'class A { int oldName = 0; int oldName2 = 0; }\n',
    );
    expect(tester.read('root_pkg/lib/a.txt'), isNull);
    expect(tester.read('root_pkg/lib/b.txt'), isNull);

    // With `--no-edit-sources`, outputs are written but the required edits
    // are only reported, and the build fails.
    output = await tester.run(
      'root_pkg',
      'dart run build_runner build --force-jit --no-edit-sources',
      expectExitCode: 1,
    );
    expect(output, contains(BuildLog.failurePattern));
    expect(output, contains('Fix errors in sources:'));
    expect(output, contains('lib/a.dart: Rename oldName at 14 to newName.'));
    expect(output, contains('lib/a.dart: Rename oldName at 31 to newName.'));
    expect(
      tester.read('root_pkg/lib/a.dart'),
      'class A { int oldName = 0; int oldName2 = 0; }\n',
    );
    expect(tester.read('root_pkg/lib/a.txt'), isNull);
    expect(tester.read('root_pkg/lib/b.txt'), 'ok');

    // Otherwise the edits are applied and the build reruns.
    output = await tester.run(
      'root_pkg',
      'dart run build_runner build --force-jit',
    );
    expect(output, contains('Fixed errors in sources:'));
    expect(output, contains('lib/a.dart: Rename oldName at 14 to newName.'));
    expect(output, contains('lib/a.dart: Rename oldName at 31 to newName.'));
    expect(output, contains(BuildLog.successPattern));
    expect(
      tester.read('root_pkg/lib/a.dart'),
      'class A { int newName = 0; int newName2 = 0; }\n',
    );
    expect(tester.read('root_pkg/lib/a.txt'), 'ok');
  });
}
