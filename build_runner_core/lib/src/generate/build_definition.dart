// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:build/build.dart';

import '../asset/writer.dart';
import '../asset_graph/graph.dart';
import '../changes/build_script_updates.dart';
import '../environment/build_environment.dart';
import '../package_graph/build_phases.dart';
import '../package_graph/package_graph.dart';
import '../package_graph/target_graph.dart';
import 'build_definition_loader.dart';
import 'options.dart';

class BuildDefinition {
  final AssetGraph assetGraph;
  final TargetGraph targetGraph;

  final AssetReader reader;
  final RunnerAssetWriter writer;

  final PackageGraph packageGraph;
  final bool deleteFilesByDefault;
  final ResourceManager resourceManager;

  final BuildScriptUpdates? buildScriptUpdates;

  /// Whether or not to run in a mode that conserves RAM at the cost of build
  /// speed.
  final bool enableLowResourcesMode;

  final BuildEnvironment environment;

  BuildDefinition.using(
    this.assetGraph,
    this.targetGraph,
    this.reader,
    this.writer,
    this.packageGraph,
    this.deleteFilesByDefault,
    this.resourceManager,
    this.buildScriptUpdates,
    this.enableLowResourcesMode,
    this.environment,
  );

  static Future<BuildDefinition> prepareWorkspace(
    BuildEnvironment environment,
    BuildOptions options,
    BuildPhases buildPhases,
  ) =>
      BuildDefinitionLoader(
        environment,
        options,
        buildPhases,
      ).prepareWorkspace();
}
