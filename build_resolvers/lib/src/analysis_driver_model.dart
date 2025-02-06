// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
// ignore: implementation_imports
import 'package:analyzer/src/clients/build_resolvers/build_resolvers.dart';
import 'package:build/build.dart';
import 'package:build/src/asset/filesystem.dart';
import 'package:graphs/graphs.dart';

import 'analysis_driver_filesystem.dart';

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
  final AnalysisDriverFilesystem filesystem = AnalysisDriverFilesystem();

  /// The import graph of all sources needed for analysis.
  final _graph = _Graph();

  /// Assets that have been synced into the in-memory filesystem
  /// [filesystem].
  final _syncedOntoFilesystem = <AssetId>{};

  /// Notifies that [step] has completed.
  ///
  /// All build steps must complete before [reset] is called.
  void notifyComplete(BuildStep step) {
    // This implementation doesn't keep state per `BuildStep`, nothing to do.
  }

  /// Clear cached information specific to an individual build.
  void reset() {
    _graph.clear();
    _syncedOntoFilesystem.clear();
  }

  /// Attempts to parse [uri] into an [AssetId] and returns it if it is cached.
  ///
  /// Handles 'package:' or 'asset:' URIs, as well as 'file:' URIs of the form
  /// `/$packageName/$assetPath`.
  ///
  /// Returns null if the `Uri` cannot be parsed or is not cached.
  AssetId? lookupCachedAsset(Uri uri) {
    final assetId = AnalysisDriverFilesystem.parseAsset(uri);
    // TODO(davidmorgan): not clear if this is the right "exists" check.
    if (assetId == null || !filesystem.getFile(assetId.asPath).exists) {
      return null;
    }

    return assetId;
  }

  /// Updates [filesystem] and the analysis driver given by
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
    // Immediately take the lock on `driver` so that the whole class state,
    // `_graph` and `_readForAnalyzir`, is only mutated by one build step at a
    // time. Otherwise, interleaved access complicates processing significantly.
    await withDriverResource((driver) async {
      return _performResolve(driver, buildStep, entryPoints, withDriverResource,
          transitive: transitive);
    });
  }

  Future<void> _performResolve(
      AnalysisDriverForPackageBuild driver,
      BuildStep buildStep,
      List<AssetId> entryPoints,
      Future<void> Function(
              FutureOr<void> Function(AnalysisDriverForPackageBuild))
          withDriverResource,
      {required bool transitive}) async {
    var idsToSyncOntoFilesystem = entryPoints;

    // If requested, find transitive imports.
    if (transitive) {
      final previouslyMissingFiles =
          _graph.load(buildStep.filesystem, entryPoints);
      _syncedOntoFilesystem.removeAll(previouslyMissingFiles);
      idsToSyncOntoFilesystem = _graph.nodes.keys.toList();
      final inputIds = _graph.inputsFor(entryPoints);
      //print('Input IDs: $inputIds');
      buildStep.inputTracker!.addAssetSet(inputIds);
    } else {
      for (final id in entryPoints) {
        buildStep.inputTracker!.add(id);
      }
    }

    // Sync changes onto the "URI resolver", the in-memory filesystem.
    for (final id in idsToSyncOntoFilesystem) {
      if (!_syncedOntoFilesystem.add(id)) continue;
      final content = buildStep.filesystem.existsSync(id)
          ? buildStep.filesystem.readAsStringSync(id)
          : null;
      if (content == null) {
        filesystem.deleteFile(id.asPath);
      } else {
        filesystem.writeFile(id.asPath, content);
      }
    }

    // Notify the analyzer of changes and wait for it to update its internal
    // state.
    for (final path in filesystem.changedPaths) {
      driver.changeFile(path);
    }
    filesystem.clearChangedPaths();
    await driver.applyPendingFileChanges();
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
  String get asPath => AnalysisDriverFilesystem.assetPath(this);
}

/// The directive graph of all known sources.
///
/// Also tracks whether there is a `.transitive_digest` file next to each source
/// asset, and tracks missing files.
class _Graph {
  final Map<AssetId, _Node> nodes = {};

  final List<AssetSet> components = [];
  final Map<AssetId, AssetSet> componentsById = {};
  final Map<AssetSet, Set<AssetSet>> componentDeps = Map.identity();

  /// Walks the import graph from [ids] loading into [nodes].
  ///
  /// Checks files that are in the graph as missing to determine whether they
  /// are now available.
  ///
  /// Returns the set of files that were in the graph as missing and have now
  /// been loaded.
  Set<AssetId> load(Filesystem filesystem, Iterable<AssetId> ids) {
    // TODO(davidmorgan): check if List is faster.
    final nextIds = Queue.of(ids);
    final processed = <AssetId>{};
    final previouslyMissingFiles = <AssetId>{};
    var anyChange = false;
    while (nextIds.isNotEmpty) {
      final id = nextIds.removeFirst();

      if (!processed.add(id)) continue;

      // Read nodes not yet loaded or that were missing when loaded.
      var node = nodes[id];
      if (node == null || node.isMissing) {
        if (filesystem.existsSync(id)) {
          // If it was missing when loaded, record that.
          if (node != null && node.isMissing) {
            previouslyMissingFiles.add(id);
          }
          // Load the node.
          final hasTransitiveDigestAsset = filesystem
              .existsSync(id.addExtension(_transitiveDigestExtension));
          final content = filesystem.readAsStringSync(id);
          final deps = _parseDependencies(content, id);
          node = _Node(
              id: id,
              deps: deps,
              hasTransitiveDigestAsset: hasTransitiveDigestAsset);
          anyChange = true;
        } else {
          if (node == null) anyChange = true;
          node ??= _Node.missing(id: id, hasTransitiveDigestAsset: false);
        }
        nodes[id] = node;
      }

      // Continue to deps even for already-loaded nodes, to check missing files.
      nextIds.addAll(node.deps.where((id) => !processed.contains(id)));
    }

    if (anyChange) {
      components.clear();
      componentsById.clear();
      for (final component in stronglyConnectedComponents(
        nodes.keys,
        (key) => nodes[key]!.deps,
      ).map(AssetSet.of)) {
        // TODO(davidmorgan): need to upgrade from set to tree to handle
        // generated parts efficiently.
        if (component.length == 1 &&
            component.single.path.contains('.g.dart')) {
          continue;
        }
        components.add(component);
        for (final id in component) {
          componentsById[id] = component;
        }
      }
      for (final component in components) {
        for (final id in component) {
          componentDeps[component] ??= Set.identity();
          for (final dep in nodes[id]!.deps) {
            // TODO(davidmorgan): need to upgrade from set to tree to handle
            // generated parts efficiently.
            if (dep.path.contains('.g.dart')) continue;
            final depComponent = componentsById[dep]!;
            if (depComponent != component) {
              componentDeps[component]!.add(depComponent);
            }
          }
        }
      }

      // print('Graph updated.\n$this');
    }

    return previouslyMissingFiles;
  }

  void clear() {
    nodes.clear();
  }

  /// The inputs for a build action analyzing [entryPoints].
  ///
  /// This is transitive deps, but cut off by the presence of any
  /// `.transitive_digest` file next to an asset.
  AssetSet inputsFor(Iterable<AssetId> entryPoints) {
    // TODO(davidmorgan): missing inputs need to be represented specially / differently.
    // Also maybe transitive digest files?

    var result = AssetSet();
    final startingComponents = Set<AssetSet>.identity();
    for (final id in entryPoints) {
      startingComponents.add(componentsById[id]!);
    }
    for (final startingComponent in startingComponents) {
      result = result.copyWithAssetSet(startingComponent);
    }
    final nextComponents = Queue.of(startingComponents);

    while (nextComponents.isNotEmpty) {
      final nextComponent = nextComponents.removeFirst();

      // Add the transitive digest file as an input. If it exists, skip deps.
      /*result.add(nextId.addExtension(_transitiveDigestExtension));
      if (node.hasTransitiveDigestAsset) {
        continue;
      }*/

      // Skip if there are no deps because the file is missing.
      // if (node.isMissing) continue;

      // For each dep, if it's not in `result` yet, it's newly-discovered:
      // add it to `nextIds`.
      for (final dep in componentDeps[nextComponent]!) {
        final oldResult = result;
        result = result.copyWithAssetSet(dep);
        if (result != oldResult) {
          nextComponents.add(dep);
        }
      }
    }
    return result;
  }

  @override
  String toString() {
    return '''
_Graph
      ${nodes.entries.map((e) => '${e.key}:${e.value}').join('\n  ')};

_Graph components by ID
      ${componentsById.entries.map((e) => '${e.key}:${e.value}').join('\n  ')};

_Graph components deps
      ${componentDeps.entries.map((e) => '${e.key}:${e.value}').join('\n  ')};
''';
  }
}

/// A node in the directive graph.
class _Node {
  final AssetId id;
  final List<AssetId> deps;
  final bool isMissing;
  final bool hasTransitiveDigestAsset;

  _Node(
      {required this.id,
      required this.deps,
      required this.hasTransitiveDigestAsset})
      : isMissing = false;

  _Node.missing({required this.id, required this.hasTransitiveDigestAsset})
      : isMissing = true,
        deps = const [];

  @override
  String toString() => '$id:'
      '${hasTransitiveDigestAsset ? 'digest:' : ''}'
      '${isMissing ? 'missing' : deps}';
}

// Transitive digest files are built next to source inputs. As the name
// suggests, they contain the transitive digest of all deps of the file.
// So, establishing a dependency on a transitive digest file is equivalent
// to establishing a dependency on all deps of the file.
const _transitiveDigestExtension = '.transitive_digest';
