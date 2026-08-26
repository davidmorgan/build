import 'package:build/build.dart' hide Builder;
import 'package:built_collection/built_collection.dart';
import 'package:meta/meta.dart';

import '../../build_plan/build_step_plan.dart';
import '../asset_content.dart';
import 'build_step_id.dart';
import 'build_step_result.dart';
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
  final BuiltMap<AssetId, AssetContent> contents;

  FinishedBuildState({
    required this.incremental,
    required this.buildStepPlan,
    required this.contents,
  });

  /// An empty [FinishedBuildState] with no sources and an empty plan.
  @visibleForTesting
  FinishedBuildState.empty()
    : incremental = IncrementalBuildState(),
      buildStepPlan = BuildStepPlan.empty(),
      contents = BuiltMap<AssetId, AssetContent>();

  BuiltSet<AssetId> get sources => incremental.sources;
  BuiltMap<BuildStepId, BuildStepResult> get buildStepResults =>
      incremental.buildStepResults;
  BuiltMap<PostProcessBuildStepId, PostProcessBuildStepResult>
  get postProcessResults => incremental.postProcessResults;

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

  BuildStepResult? stepResultOrNull(BuildStepId step) => buildStepResults[step];

  Iterable<AssetId> get actualPostOutputs => postProcessOutputs.keys;

  bool isActualPostOutput(AssetId id) => postProcessOutputs.containsKey(id);

  bool isActualOutput(AssetId id) {
    final step = buildStepPlan.stepForDeclaredOutputOrNull(id);
    if (step == null) return false;
    return stepResultOrNull(step)?.outputs.contains(id) ?? false;
  }

  bool _isHiddenPostProcessOutput(AssetId id) {
    final step = postProcessOutputs[id];
    if (step == null) return false;
    return postProcessResults[step]?.hidden ?? false;
  }

  bool isHidden(AssetId id) =>
      buildStepPlan.isHidden(id) || _isHiddenPostProcessOutput(id);

  bool isFile(AssetId id) =>
      isSource(id) ||
      buildStepPlan.isDeclaredOutput(id) ||
      isActualPostOutput(id);

  AssetContent? contentOf(AssetId id) => contents[id];
}
