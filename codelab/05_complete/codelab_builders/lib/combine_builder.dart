// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:build/build.dart';
import 'package:glob/glob.dart';

class CombineBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => {
    r'$lib$': ['../tool/actions.sh'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final output = StringBuffer();

    await for (final dartAsset in buildStep.findAssets(Glob('**.dart'))) {
      final actionsAsset = dartAsset.changeExtension('.actions');

      if (await buildStep.canRead(actionsAsset)) {
        output.write(await buildStep.readAsString(actionsAsset));
      }
    }

    await buildStep.writeAsString(
      AssetId(buildStep.inputId.package, 'tool/actions.sh'),
      output.toString(),
    );
  }
}
