// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/file_system/memory_file_system.dart';
// ignore: implementation_imports
import 'package:analyzer/src/clients/build_resolvers/build_resolvers.dart';
import 'package:build/build.dart';
import 'package:path/path.dart' as p;

import 'analysis_driver_model_uri_resolver.dart';

/// Manages analysis driver and related build state.
///
/// - Tracks the import graph of all sources needed for analysis.
/// - Given a set of entrypoints, adds them to known sources, optionally with
///   their transitive imports.
/// - Given a set of entrypoints, informs a `BuildStep` which inputs it now
///   depends on because of analysis.
/// - Maintains an in-memory filesystem that is the analyzer's view of the
///   build.
/// - Notifies the analyzer of changes to that in-memory filesystem.
///
/// TODO(davidmorgan): the implementation here is unfinished and not used
/// anywhere; finish it. See `build_asset_uri_resolver.dart` for the current
/// implementation.
class AnalysisDriverModel {
  /// In-memory filesystem for the analyzer.
  final MemoryResourceProvider resourceProvider =
      MemoryResourceProvider(context: p.posix);

  final _Graph _graph = _Graph();
  final Set<AssetId> _readForAnalyzer = <AssetId>{};

  /// Notifies that [step] has completed.
  ///
  /// All build steps must complete before [reset] is called.
  void notifyComplete(BuildStep step) {}

  /// Clear cached information specific to an individual build.
  void reset() {
    _graph.clear();
    _readForAnalyzer.clear();
  }

  /// Attempts to parse [uri] into an [AssetId] and returns it if it is cached.
  ///
  /// Handles 'package:' or 'asset:' URIs, as well as 'file:' URIs of the form
  /// `/$packageName/$assetPath`.
  ///
  /// Returns null if the `Uri` cannot be parsed or is not cached.
  AssetId? lookupCachedAsset(Uri uri) {
    final assetId = AnalysisDriverModelUriResolver.parseAsset(uri);
    // TODO(davidmorgan): not clear if this is the right "exists" check.
    if (assetId == null || !resourceProvider.getFile(assetId.asPath).exists) {
      return null;
    }

    return assetId;
  }

  /// Updates [resourceProvider] and the analysis driver given by
  /// `withDriverResource`  with updated versions of [entryPoints].
  ///
  /// If [transitive], then all the transitive imports from [entryPoints] are
  /// also updated.
  ///
  /// Notifies [buildStep] of all inputs that result from analysis. If
  /// [transitive], this includes all transitive dependencies.
  ///
  /// If while finding transitive deps a `.transitive_deps` file is
  /// encountered next to a source file then this cuts off the reporting
  /// of deps to the [buildStep], but does not affect the reporting of
  /// files to the analysis driver.
  Future<void> performResolve(
      BuildStep buildStep,
      List<AssetId> entryPoints,
      Future<void> Function(
              FutureOr<void> Function(AnalysisDriverForPackageBuild))
          withDriverResource,
      {required bool transitive}) async {
    var analyzerIds = entryPoints;
    Iterable<AssetId> inputIds = entryPoints;

    // If requested, find transitive imports.
    if (transitive) {
      await _loadGraph(buildStep, entryPoints);
      // TODO(davidmorgan): use just the set for the entrypoints.
      analyzerIds = _graph.nodes.keys.toList();
      inputIds = _graph.inputsFor(entryPoints);

      // Check for missing inputs that were written during the build.
      for (final id
          in inputIds.where((id) => !id.path.endsWith('.transitive_digest'))) {
        if (_graph.nodes[id]!.isMissing) {
          if (await buildStep.canRead(id)) {
            analyzerIds.add(id);
            _readForAnalyzer.remove(id);
          }
        }
      }
    }

    // Notify [buildStep] of its inputs.
    for (final id in inputIds) {
      await buildStep.canRead(id);
    }

    // Apply changes to in-memory filesystem.
    final changedIds = <AssetId>[];
    for (final id in analyzerIds) {
      if (!_readForAnalyzer.add(id)) continue;

      final content =
          await buildStep.canRead(id) ? await buildStep.readAsString(id) : null;
      final inMemoryFile = resourceProvider.getFile(id.asPath);
      final inMemoryContent =
          inMemoryFile.exists ? inMemoryFile.readAsStringSync() : null;

      if (content != inMemoryContent) {
        if (content == null) {
          // TODO(davidmorgan): per "globallySeenAssets" in
          // BuildAssetUriResolver, deletes should only be applied at the end of
          // the build, in case the file is actually there but not visible to
          // the current reader.
          resourceProvider.deleteFile(id.asPath);
          changedIds.add(id);
        } else {
          resourceProvider.newFile(id.asPath, content);
          changedIds.add(id);
        }
      }
    }

    // Notify the analyzer of changes.
    await withDriverResource((driver) async {
      for (final id in changedIds) {
        driver.changeFile(id.asPath);
      }
      await driver.applyPendingFileChanges();
    });
  }

  /// Walks the import graph from [ids], reading into [_graph].
  Future<void> _loadGraph(AssetReader reader, Iterable<AssetId> ids) async {
    final completer = Completer<void>();
    final previousFuture = _graph._doneLoading;
    _graph._doneLoading = completer.future;
    await previousFuture;

    final nextIds = Queue.of(ids);
    while (nextIds.isNotEmpty) {
      final nextId = nextIds.removeFirst();

      // Skip if already seen.
      if (_graph.nodes.containsKey(nextId)) continue;

      final hasTransitiveDigestAsset =
          await reader.canRead(nextId.addExtension('.transitive_digest'));

      // Skip if not readable.
      if (!await reader.canRead(nextId)) {
        _graph.nodes[nextId] = _Node(
            id: nextId,
            deps: null,
            hasTransitiveDigestAsset: hasTransitiveDigestAsset);
        continue;
      }

      final content = await reader.readAsString(nextId);
      final deps = _parseDependencies(content, nextId);
      _graph.nodes[nextId] = _Node(
          id: nextId,
          deps: deps,
          hasTransitiveDigestAsset: hasTransitiveDigestAsset);
      nextIds.addAll(deps.where((id) => !_graph.nodes.containsKey(id)));
    }

    completer.complete();
  }
}

const _ignoredSchemes = ['dart', 'dart-ext'];

/// Parses Dart source in [content], returns all depedencies: all assets
/// mentioned in directives, excluding `dart:` and `dart-ext` schemes.
List<AssetId> _parseDependencies(String content, AssetId from) =>
    parseString(content: content, throwIfDiagnostics: false)
        .unit
        .directives
        .whereType<UriBasedDirective>()
        .map((directive) => directive.uri.stringValue)
        // Uri.stringValue can be null for strings that use interpolation.
        .nonNulls
        .where(
          (uriContent) => !_ignoredSchemes.any(Uri.parse(uriContent).isScheme),
        )
        .map((content) => AssetId.resolve(Uri.parse(content), from: from))
        .toList();

extension _AssetIdExtensions on AssetId {
  /// Asset path for the in-memory filesystem.
  String get asPath => AnalysisDriverModelUriResolver.assetPath(this);
}

class _Graph {
  final Map<AssetId, _Node> nodes = {};
  Future<void> _doneLoading = Future.value(null);

  void clear() {
    nodes.clear();
  }

  Set<AssetId> inputsFor(Iterable<AssetId> entryPoints) {
    final result = <AssetId>{};
    _inputsFor(entryPoints, result);
    return result;
  }

  void _inputsFor(Iterable<AssetId> entryPoints, Set<AssetId> result) {
    final nextIds = Queue.of(entryPoints);

    while (nextIds.isNotEmpty) {
      final nextId = nextIds.removeFirst();

      // Add to result, or skip if already seen.
      if (!result.add(nextId)) continue;

      final node = nodes[nextId]!;

      // Add the transitive digest file as an input. If it exists, skip deps.
      result.add(nextId.addExtension('.transitive_digest'));
      if (node.hasTransitiveDigestAsset) {
        continue;
      }

      // Skip if there are no deps because the file is missing.
      if (node.deps == null) continue;

      nextIds.addAll(node.deps!.where((id) => !result.contains(id)));
    }
  }

  @override
  String toString() => nodes.toString();
}

class _Node {
  final AssetId id;
  final List<AssetId>? deps;
  final bool hasTransitiveDigestAsset;

  _Node(
      {required this.id,
      required this.deps,
      required this.hasTransitiveDigestAsset});

  bool get isMissing => deps == null;

  @override
  String toString() => '$id:'
      '${hasTransitiveDigestAsset ? 'digest:' : ''}'
      '${deps?.toString() ?? 'missing'}';
}
