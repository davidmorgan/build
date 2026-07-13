// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:build/build.dart';
import 'package:built_collection/built_collection.dart';

import '../io/build_output_reader.dart';
import 'build_state/build_state.dart';
import 'library_cycle_graph/phased_asset_deps.dart';

/// The result of an individual build, this may be an incremental build or
/// a full build.
class BuildResult {
  /// The status of this build.
  final BuildStatus status;

  /// The type of failure.
  final FailureType? failureType;

  /// Errors reported.
  final BuiltList<String> errors;

  /// All outputs created/updated during this build.
  final BuiltList<AssetId> outputs;

  /// The imports graph for resolved sources.
  final PhasedAssetDeps phasedAssetDeps;

  /// The build output.
  ///
  /// `null` if the build failed with no output.
  final BuildOutputReader? buildOutputReader;

  // The build state.
  final BuildState? buildState;

  BuildResult({
    required this.status,
    BuiltList<String>? errors,
    BuiltList<AssetId>? outputs,
    PhasedAssetDeps? phasedAssetDeps,
    required this.buildOutputReader,
    this.buildState,
    FailureType? failureType,
  }) : failureType = failureType == null && status == .failure
           ? .general
           : failureType,
       errors = errors ?? .new(),
       outputs = outputs ?? .new(),
       phasedAssetDeps = phasedAssetDeps ?? .new();

  BuildResult copyWith({
    BuildStatus? status,
    FailureType? failureType,
    BuiltList<String>? errors,
    BuiltList<AssetId>? outputs,
    PhasedAssetDeps? phasedAssetDeps,
    BuildOutputReader? buildOutputReader,
    BuildState? buildState,
  }) => .new(
    status: status ?? this.status,
    failureType: failureType ?? this.failureType,
    errors: errors ?? this.errors,
    outputs: outputs ?? this.outputs,
    phasedAssetDeps: phasedAssetDeps ?? this.phasedAssetDeps,
    buildOutputReader: buildOutputReader ?? this.buildOutputReader,
    buildState: buildState ?? this.buildState,
  );

  @override
  String toString() {
    if (status == .success) {
      return '''

Build Succeeded!
''';
    } else {
      return '''

Build Failed :(
''';
    }
  }

  factory BuildResult.buildScriptChanged() => .new(
    status: .failure,
    failureType: .buildScriptChanged,
    buildOutputReader: null,
  );
}

/// The status of a build.
enum BuildStatus { success, failure }

/// The type of failure
class FailureType {
  static final general = FailureType._(1);
  static final cantCreate = FailureType._(73);
  static final buildScriptChanged = FailureType._(75);
  final int exitCode;
  FailureType._(this.exitCode);
}
