// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'previous_build.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PreviousBuild extends PreviousBuild {
  @override
  final IncrementalBuildState? incrementalState;
  @override
  final BuildStepPlan? buildStepPlan;
  @override
  final BuiltMap<AssetId, AssetContent> sourceContents;
  @override
  final BuiltMap<AssetId, AssetContent> outputContents;
  @override
  final PhasedAssetDeps? phasedAssetDeps;
  @override
  final bool triggersChanged;
  @override
  final BuiltList<bool> phaseOptionsChangedList;
  @override
  final BuiltList<bool> postBuildOptionsChangedList;
  @override
  final BuiltList<AssetId> incompatibleBuildOutputsToDelete;

  factory _$PreviousBuild([void Function(PreviousBuildBuilder)? updates]) =>
      (PreviousBuildBuilder()..update(updates))._build();

  _$PreviousBuild._({
    this.incrementalState,
    this.buildStepPlan,
    required this.sourceContents,
    required this.outputContents,
    this.phasedAssetDeps,
    required this.triggersChanged,
    required this.phaseOptionsChangedList,
    required this.postBuildOptionsChangedList,
    required this.incompatibleBuildOutputsToDelete,
  }) : super._() {
    BuiltValueNullFieldError.checkNotNull(
      sourceContents,
      r'PreviousBuild',
      'sourceContents',
    );
    BuiltValueNullFieldError.checkNotNull(
      outputContents,
      r'PreviousBuild',
      'outputContents',
    );
    BuiltValueNullFieldError.checkNotNull(
      triggersChanged,
      r'PreviousBuild',
      'triggersChanged',
    );
    BuiltValueNullFieldError.checkNotNull(
      phaseOptionsChangedList,
      r'PreviousBuild',
      'phaseOptionsChangedList',
    );
    BuiltValueNullFieldError.checkNotNull(
      postBuildOptionsChangedList,
      r'PreviousBuild',
      'postBuildOptionsChangedList',
    );
    BuiltValueNullFieldError.checkNotNull(
      incompatibleBuildOutputsToDelete,
      r'PreviousBuild',
      'incompatibleBuildOutputsToDelete',
    );
  }

  @override
  PreviousBuild rebuild(void Function(PreviousBuildBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PreviousBuildBuilder toBuilder() => PreviousBuildBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PreviousBuild &&
        incrementalState == other.incrementalState &&
        buildStepPlan == other.buildStepPlan &&
        sourceContents == other.sourceContents &&
        outputContents == other.outputContents &&
        phasedAssetDeps == other.phasedAssetDeps &&
        triggersChanged == other.triggersChanged &&
        phaseOptionsChangedList == other.phaseOptionsChangedList &&
        postBuildOptionsChangedList == other.postBuildOptionsChangedList &&
        incompatibleBuildOutputsToDelete ==
            other.incompatibleBuildOutputsToDelete;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, incrementalState.hashCode);
    _$hash = $jc(_$hash, buildStepPlan.hashCode);
    _$hash = $jc(_$hash, sourceContents.hashCode);
    _$hash = $jc(_$hash, outputContents.hashCode);
    _$hash = $jc(_$hash, phasedAssetDeps.hashCode);
    _$hash = $jc(_$hash, triggersChanged.hashCode);
    _$hash = $jc(_$hash, phaseOptionsChangedList.hashCode);
    _$hash = $jc(_$hash, postBuildOptionsChangedList.hashCode);
    _$hash = $jc(_$hash, incompatibleBuildOutputsToDelete.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PreviousBuild')
          ..add('incrementalState', incrementalState)
          ..add('buildStepPlan', buildStepPlan)
          ..add('sourceContents', sourceContents)
          ..add('outputContents', outputContents)
          ..add('phasedAssetDeps', phasedAssetDeps)
          ..add('triggersChanged', triggersChanged)
          ..add('phaseOptionsChangedList', phaseOptionsChangedList)
          ..add('postBuildOptionsChangedList', postBuildOptionsChangedList)
          ..add(
            'incompatibleBuildOutputsToDelete',
            incompatibleBuildOutputsToDelete,
          ))
        .toString();
  }
}

class PreviousBuildBuilder
    implements Builder<PreviousBuild, PreviousBuildBuilder> {
  _$PreviousBuild? _$v;

  IncrementalBuildState? _incrementalState;
  IncrementalBuildState? get incrementalState => _$this._incrementalState;
  set incrementalState(IncrementalBuildState? incrementalState) =>
      _$this._incrementalState = incrementalState;

  BuildStepPlanBuilder? _buildStepPlan;
  BuildStepPlanBuilder get buildStepPlan =>
      _$this._buildStepPlan ??= BuildStepPlanBuilder();
  set buildStepPlan(BuildStepPlanBuilder? buildStepPlan) =>
      _$this._buildStepPlan = buildStepPlan;

  MapBuilder<AssetId, AssetContent>? _sourceContents;
  MapBuilder<AssetId, AssetContent> get sourceContents =>
      _$this._sourceContents ??= MapBuilder<AssetId, AssetContent>();
  set sourceContents(MapBuilder<AssetId, AssetContent>? sourceContents) =>
      _$this._sourceContents = sourceContents;

  MapBuilder<AssetId, AssetContent>? _outputContents;
  MapBuilder<AssetId, AssetContent> get outputContents =>
      _$this._outputContents ??= MapBuilder<AssetId, AssetContent>();
  set outputContents(MapBuilder<AssetId, AssetContent>? outputContents) =>
      _$this._outputContents = outputContents;

  PhasedAssetDepsBuilder? _phasedAssetDeps;
  PhasedAssetDepsBuilder get phasedAssetDeps =>
      _$this._phasedAssetDeps ??= PhasedAssetDepsBuilder();
  set phasedAssetDeps(PhasedAssetDepsBuilder? phasedAssetDeps) =>
      _$this._phasedAssetDeps = phasedAssetDeps;

  bool? _triggersChanged;
  bool? get triggersChanged => _$this._triggersChanged;
  set triggersChanged(bool? triggersChanged) =>
      _$this._triggersChanged = triggersChanged;

  ListBuilder<bool>? _phaseOptionsChangedList;
  ListBuilder<bool> get phaseOptionsChangedList =>
      _$this._phaseOptionsChangedList ??= ListBuilder<bool>();
  set phaseOptionsChangedList(ListBuilder<bool>? phaseOptionsChangedList) =>
      _$this._phaseOptionsChangedList = phaseOptionsChangedList;

  ListBuilder<bool>? _postBuildOptionsChangedList;
  ListBuilder<bool> get postBuildOptionsChangedList =>
      _$this._postBuildOptionsChangedList ??= ListBuilder<bool>();
  set postBuildOptionsChangedList(
    ListBuilder<bool>? postBuildOptionsChangedList,
  ) => _$this._postBuildOptionsChangedList = postBuildOptionsChangedList;

  ListBuilder<AssetId>? _incompatibleBuildOutputsToDelete;
  ListBuilder<AssetId> get incompatibleBuildOutputsToDelete =>
      _$this._incompatibleBuildOutputsToDelete ??= ListBuilder<AssetId>();
  set incompatibleBuildOutputsToDelete(
    ListBuilder<AssetId>? incompatibleBuildOutputsToDelete,
  ) => _$this._incompatibleBuildOutputsToDelete =
      incompatibleBuildOutputsToDelete;

  PreviousBuildBuilder();

  PreviousBuildBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _incrementalState = $v.incrementalState;
      _buildStepPlan = $v.buildStepPlan?.toBuilder();
      _sourceContents = $v.sourceContents.toBuilder();
      _outputContents = $v.outputContents.toBuilder();
      _phasedAssetDeps = $v.phasedAssetDeps?.toBuilder();
      _triggersChanged = $v.triggersChanged;
      _phaseOptionsChangedList = $v.phaseOptionsChangedList.toBuilder();
      _postBuildOptionsChangedList = $v.postBuildOptionsChangedList.toBuilder();
      _incompatibleBuildOutputsToDelete = $v.incompatibleBuildOutputsToDelete
          .toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PreviousBuild other) {
    _$v = other as _$PreviousBuild;
  }

  @override
  void update(void Function(PreviousBuildBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PreviousBuild build() => _build();

  _$PreviousBuild _build() {
    _$PreviousBuild _$result;
    try {
      _$result =
          _$v ??
          _$PreviousBuild._(
            incrementalState: incrementalState,
            buildStepPlan: _buildStepPlan?.build(),
            sourceContents: sourceContents.build(),
            outputContents: outputContents.build(),
            phasedAssetDeps: _phasedAssetDeps?.build(),
            triggersChanged: BuiltValueNullFieldError.checkNotNull(
              triggersChanged,
              r'PreviousBuild',
              'triggersChanged',
            ),
            phaseOptionsChangedList: phaseOptionsChangedList.build(),
            postBuildOptionsChangedList: postBuildOptionsChangedList.build(),
            incompatibleBuildOutputsToDelete: incompatibleBuildOutputsToDelete
                .build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'buildStepPlan';
        _buildStepPlan?.build();
        _$failedField = 'sourceContents';
        sourceContents.build();
        _$failedField = 'outputContents';
        outputContents.build();
        _$failedField = 'phasedAssetDeps';
        _phasedAssetDeps?.build();

        _$failedField = 'phaseOptionsChangedList';
        phaseOptionsChangedList.build();
        _$failedField = 'postBuildOptionsChangedList';
        postBuildOptionsChangedList.build();
        _$failedField = 'incompatibleBuildOutputsToDelete';
        incompatibleBuildOutputsToDelete.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'PreviousBuild',
          _$failedField,
          e.toString(),
        );
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
