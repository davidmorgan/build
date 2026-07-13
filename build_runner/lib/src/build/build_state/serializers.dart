// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:build/build.dart' show AssetId;
import 'package:built_collection/built_collection.dart';
import 'package:built_value/serializer.dart';
import 'package:crypto/crypto.dart';

import '../../build_plan/build_spec_digest.dart';
import '../asset_content.dart';
import '../library_cycle_graph/asset_deps.dart';
import '../library_cycle_graph/phased_asset_deps.dart';
import '../library_cycle_graph/phased_value.dart';
import 'build_step_id.dart';
import 'build_step_result.dart';
import 'glob_id.dart';
import 'glob_result.dart';
import 'identity_serializer.dart';
import 'post_process_build_step_id.dart';
import 'post_process_build_step_result.dart';

part 'serializers.g.dart';

final postProcessBuildStepResultsFullType = const FullType(BuiltMap, [
  .new(PostProcessBuildStepId),
  .new(PostProcessBuildStepResult),
]);

final assetIdSerializer = AssetIdSerializer();
final identityAssetIdSerializer = IdentitySerializer<AssetId>(
  assetIdSerializer,
);

@SerializersFor([
  AssetDeps,
  BuildSpecDigest,
  BuildStepId,
  BuildStepResult,
  GlobId,
  GlobResult,
  PhasedAssetDeps,
  PostProcessBuildStepId,
  PostProcessBuildStepResult,
])
final Serializers serializers =
    (_$serializers.toBuilder()
          ..add(identityAssetIdSerializer)
          ..add(AssetContentSerializer())
          ..add(DigestSerializer())
          ..addBuilderFactory(
            const .new(BuiltSet, [.new(AssetId)]),
            SetBuilder<AssetId>.new,
          )
          ..addBuilderFactory(
            const .new(BuiltList, [.new(String)]),
            ListBuilder<String>.new,
          )
          ..addBuilderFactory(
            const .new(BuiltMap, [.new(BuildStepId), .new(BuildStepResult)]),
            MapBuilder<BuildStepId, BuildStepResult>.new,
          )
          ..addBuilderFactory(
            const .new(BuiltMap, [.new(GlobId), .new(GlobResult)]),
            MapBuilder<GlobId, GlobResult>.new,
          )
          ..addBuilderFactory(
            const .new(BuiltMap, [.new(AssetId), .new(BuildStepId)]),
            MapBuilder<AssetId, BuildStepId>.new,
          )
          ..addBuilderFactory(
            const .new(BuiltMap, [
              .new(AssetId),
              .new(BuiltSet, [.new(AssetId)]),
            ]),
            MapBuilder<AssetId, BuiltSet<AssetId>>.new,
          )
          ..addBuilderFactory(
            const .new(Set, [.new(AssetId)]),
            () => <AssetId>{},
          )
          ..addBuilderFactory(
            postProcessBuildStepResultsFullType,
            MapBuilder<PostProcessBuildStepId, PostProcessBuildStepResult>.new,
          )
          ..addBuilderFactory(
            const .new(BuiltMap, [.new(AssetId), .new(AssetContent)]),
            MapBuilder<AssetId, AssetContent>.new,
          )
          ..addBuilderFactory(
            const .new(BuiltList, [.new(AssetContent)]),
            ListBuilder<AssetContent>.new,
          )
          ..addBuilderFactory(
            const .new(PhasedValue, [.new(AssetDeps)]),
            PhasedValueBuilder<AssetDeps>.new,
          )
          ..addBuilderFactory(
            const .new(ExpiringValue, [.new(AssetDeps)]),
            ExpiringValueBuilder<AssetDeps>.new,
          )
          ..addBuilderFactory(
            const .new(BuiltList, [
              .new(ExpiringValue, [.new(AssetDeps)]),
            ]),
            ListBuilder<ExpiringValue<AssetDeps>>.new,
          ))
        .build();

/// Serializer for [AssetId].
///
/// It would also work to make `AssetId` a `built_value` class, but there's
/// little benefit and it's nicer to keep codegen local to this package.
class AssetIdSerializer implements PrimitiveSerializer<AssetId> {
  @override
  Iterable<Type> get types => [AssetId];

  @override
  String get wireName => 'AssetId';

  @override
  AssetId deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = .unspecified,
  }) => .parse(serialized as String);

  @override
  Object serialize(
    Serializers serializers,
    AssetId object, {
    FullType specifiedType = .unspecified,
  }) => object.toString();
}

/// Serializer for [Digest].
class DigestSerializer implements PrimitiveSerializer<Digest> {
  @override
  Iterable<Type> get types => [Digest];

  @override
  String get wireName => 'Digest';

  @override
  Digest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = .unspecified,
  }) => .new(base64.decode(serialized as String));

  @override
  Object serialize(
    Serializers serializers,
    Digest object, {
    FullType specifiedType = .unspecified,
  }) => base64.encode(object.bytes);
}
