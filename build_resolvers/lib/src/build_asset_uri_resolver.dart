// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

// ignore: deprecated_member_use
import 'package:analyzer/analyzer.dart' show parseDirectives;
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/file_system/memory_file_system.dart';
import 'package:analyzer/src/dart/analysis/driver.dart' show AnalysisDriver;
import 'package:analyzer/src/generated/source.dart';
import 'package:build/build.dart' show AssetId, BuildStep, log;
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

const _ignoredSchemes = ['dart', 'dart-ext'];

class BuildAssetUriResolver extends UriResolver {
  final _cachedAssetDependencies = <AssetId, Set<AssetId>>{};
  final _cachedAssetContents = <AssetId, Digest>{};
  final resourceProvider = MemoryResourceProvider(context: p.posix);

  /// The assets which are known to be readable at some point during the build.
  ///
  /// When actions can run out of order an asset can move from being readable
  /// (in the later phase) to being unreadable (in the earlier phase which ran
  /// later). If this happens we don't want to hide the asset from the analyzer.
  final seenAssets = HashSet<AssetId>();

  Future<void> performResolve(
      BuildStep buildStep, List<AssetId> entryPoints, AnalysisDriver driver) {
    // Basic approach is to start at the first file, update it's contents
    // and see if it changed, then walk all files accessed by it.
    final visited = HashSet<AssetId>();
    final visiting = _FutureGroup();

    final changedPaths = HashSet<String>();

    void processAsset(AssetId assetId) {
      visited.add(assetId);

      visiting.add(() async {
        if (!await buildStep.canRead(assetId)) {
          if (!seenAssets.contains(assetId)) {
            _cachedAssetDependencies.remove(assetId);
            _cachedAssetContents.remove(assetId);
            final path = assetPath(assetId);
            if (resourceProvider.getFile(path).exists) {
              resourceProvider.deleteFile(path);
            }
          }
          return;
        }
        final digest = await buildStep.digest(assetId);
        if (_cachedAssetContents[assetId] != digest) {
          final contents = await buildStep.readAsString(assetId);
          if (_cachedAssetContents.containsKey(assetId)) {
            var path = assetPath(assetId);
            resourceProvider.updateFile(path, contents);
            changedPaths.add(path);
          } else {
            resourceProvider.newFile(assetPath(assetId), contents);
          }
          _cachedAssetContents[assetId] = digest;
          _cachedAssetDependencies[assetId] =
              _parseDirectives(contents, assetId);
        }
        _cachedAssetDependencies[assetId]
            .where((id) => !visited.contains(id))
            .forEach(processAsset);
      }());
    }

    entryPoints.forEach(processAsset);
    return visiting.future.whenComplete(() {
      changedPaths.forEach(driver.changeFile);
    });
  }

  /// Attempts to parse [uri] into an [AssetId] and returns it if it is cached.
  ///
  /// Handles 'package:' or 'asset:' URIs, as well as 'file:' URIs that have the
  /// same pattern used by [assetPath].
  ///
  /// Returns null if the Uri cannot be parsed or is not cached.
  AssetId lookupAsset(Uri uri) {
    if (_ignoredSchemes.any(uri.isScheme)) return null;
    if (uri.isScheme('package') || uri.isScheme('asset')) {
      final assetId = AssetId.resolve('$uri');
      return _cachedAssetContents.containsKey(assetId) ? assetId : null;
    }
    if (uri.isScheme('file')) {
      final parts = p.split(uri.path);
      final assetId = AssetId(parts[1], p.posix.joinAll(parts.skip(2)));
      return _cachedAssetContents.containsKey(assetId) ? assetId : null;
    }
    return null;
  }

  @override
  Source resolveAbsolute(Uri uri, [Uri actualUri]) {
    final cachedId = lookupAsset(uri);
    if (cachedId == null) return null;
    return resourceProvider
        .getFile(assetPath(cachedId))
        .createSource(cachedId.uri);
  }

  @override
  Uri restoreAbsolute(Source source) =>
      lookupAsset(source.uri)?.uri ?? source.uri;
}

Set<AssetId> _parseDirectives(String contents, AssetId from) =>
    HashSet.of(parseDirectives(contents, suppressErrors: true)
        .directives
        .whereType<UriBasedDirective>()
        .where((directive) =>
            !_ignoredSchemes.any(Uri.parse(directive.uri.stringValue).isScheme))
        .map((d) => AssetId.resolve(d.uri.stringValue, from: from))
        .where((id) => id != null));

String assetPath(AssetId assetId) =>
    p.posix.join('/${assetId.package}', assetId.path);

/// A completer that waits until all added [Future]s complete.
class _FutureGroup<E> {
  static const _FINISHED = -1;

  int _pending = 0;
  Future _failedTask;
  final Completer<List<E>> _completer = Completer<List<E>>();
  final List<E> results = [];

  /// The task that failed, if any.
  Future get failedTask => _failedTask;

  /// Wait for [task] to complete.
  ///
  /// If this group has already been marked as completed, a [StateError] will
  /// be thrown.
  ///
  /// If this group has a [failedTask], new tasks will be ignored, because the
  /// error has already been signaled.
  void add(Future<E> task) {
    if (_failedTask != null) return;
    if (_pending == _FINISHED) throw StateError('Future already completed');

    _pending++;
    var i = results.length;
    results.add(null);
    task.then((res) {
      results[i] = res;
      if (_failedTask != null) return;
      _pending--;
      if (_pending == 0) {
        _pending = _FINISHED;
        _completer.complete(results);
      }
    }, onError: (e, s) {
      if (_failedTask != null) return;
      _failedTask = task;
      _completer.completeError(e, s as StackTrace);
    });
  }

  /// A Future that completes with a List of the values from all the added
  /// tasks, when they have all completed.
  ///
  /// If any task fails, this Future will receive the error. Only the first
  /// error will be sent to the Future.
  Future<List<E>> get future => _completer.future;
}
