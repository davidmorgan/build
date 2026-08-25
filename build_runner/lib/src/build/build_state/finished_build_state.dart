// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:build/build.dart' hide Builder;
import 'package:built_collection/built_collection.dart';
import 'package:crypto/crypto.dart';

import '../../build_plan/build_step_plan.dart';
import '../asset_content.dart';
import 'build_step_id.dart';
import 'build_step_result.dart';
import 'glob_id.dart';
import 'glob_result.dart';
import 'incremental_build_state.dart';
import 'post_process_build_step_id.dart';
import 'post_process_build_step_result.dart';

/// State of a finished build, pairing the [IncrementalBuildState] with the
/// [BuildStepPlan], and providing guaranteed in-memory content when available.
///
/// Offers functionality used after the build, for example in serving files,
/// and in preparation for the next build.
class FinishedBuildState {
  final IncrementalBuildState incremental;
  final BuildStepPlan buildStepPlan;
  final BuiltMap<AssetId, AssetContent> sourceContents;
  final BuiltMap<AssetId, AssetContent> outputContents;

  FinishedBuildState({
    required this.incremental,
    required this.buildStepPlan,
    required this.sourceContents,
    required this.outputContents,
  });

  /// An empty [FinishedBuildState] with no sources and an empty plan.
  FinishedBuildState.empty()
    : incremental = IncrementalBuildState(),
      buildStepPlan = BuildStepPlan.empty(),
      sourceContents = BuiltMap<AssetId, AssetContent>(),
      outputContents = BuiltMap<AssetId, AssetContent>();

  BuiltSet<AssetId> get sources => incremental.sources;
  BuiltMap<AssetId, Digest> get sourceDigests => incremental.sourceDigests;
  BuiltMap<AssetId, Digest> get outputDigests => incremental.outputDigests;
  BuiltSet<AssetId> get missingSources => incremental.missingSources;
  BuiltMap<BuildStepId, BuildStepResult> get buildStepResults =>
      incremental.buildStepResults;
  BuiltMap<PostProcessBuildStepId, PostProcessBuildStepResult>
  get postProcessResults => incremental.postProcessResults;
  BuiltMap<GlobId, GlobResult> get globResults => incremental.globResults;

  late final BuiltSet<AssetId> assetsDeletedByPostProcess = () {
    final builder = SetBuilder<AssetId>();
    for (final entry in postProcessResults.entries) {
      if (entry.value.deletedPrimaryInput) {
        builder.add(entry.key.input);
      }
    }
    return builder.build();
  }();

  late final BuiltMap<AssetId, PostProcessBuildStepId> postProcessOutputs = () {
    final builder = MapBuilder<AssetId, PostProcessBuildStepId>();
    for (final entry in postProcessResults.entries) {
      for (final id in entry.value.outputs) {
        builder[id] = entry.key;
      }
    }
    return builder.build();
  }();

  bool isSource(AssetId id) => sources.contains(id);
  bool isMissingSource(AssetId id) => missingSources.contains(id);
  Digest? digestOfSource(AssetId id) => sourceDigests[id];
  AssetContent? contentOfSource(AssetId id) => sourceContents[id];

  BuildStepResult? stepResultOrNull(BuildStepId step) => buildStepResults[step];
  BuildStepResult stepResult(BuildStepId step) => stepResultOrNull(step)!;
  PostProcessBuildStepResult? postProcessBuildStepResultFor(
    PostProcessBuildStepId step,
  ) => postProcessResults[step];
  GlobResult? globResultFor(GlobId id) => globResults[id];

  Iterable<BuildStepResult> get actualStepResults => buildStepResults.values;
  Iterable<PostProcessBuildStepResult> get actualPostProcessResults =>
      postProcessResults.values;

  Iterable<AssetId> get actualOutputs =>
      buildStepResults.values.expand((r) => r.outputs);
  Iterable<AssetId> get actualPostOutputs => postProcessOutputs.keys;

  bool isActualPostOutput(AssetId id) => postProcessOutputs.containsKey(id);

  bool isActualOutput(AssetId id) {
    final step = buildStepPlan.stepForDeclaredOutputOrNull(id);
    if (step == null) return false;
    return stepResultOrNull(step)?.outputs.contains(id) ?? false;
  }

  bool isHiddenPostProcessOutput(AssetId id) {
    final step = postProcessOutputs[id];
    if (step == null) return false;
    return postProcessResults[step]?.hidden ?? false;
  }

  bool isHidden(AssetId id) =>
      buildStepPlan.isHidden(id) || isHiddenPostProcessOutput(id);

  bool isFile(AssetId id) =>
      isSource(id) ||
      buildStepPlan.isDeclaredOutput(id) ||
      isActualPostOutput(id);

  Digest? digestOf(AssetId id) {
    if (isSource(id)) return digestOfSource(id);
    return outputDigests[id];
  }

  AssetContent? contentOf(AssetId id) {
    if (isSource(id)) return contentOfSource(id);
    return outputContents[id];
  }
}
