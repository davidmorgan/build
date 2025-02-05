// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:build/build.dart';
import 'package:build/src/asset/filesystem.dart';
import 'package:crypto/crypto.dart';
import 'package:glob/glob.dart';

import '../asset_graph/graph.dart';
import '../asset_graph/node.dart';
import '../util/async.dart';

/// A [RunnerAssetReader] must implement [MultiPackageAssetReader].
abstract class RunnerAssetReader implements MultiPackageAssetReader {}

/// An [AssetReader] that can provide actual paths to assets on disk.
abstract class PathProvidingAssetReader implements AssetReader {
  String pathTo(AssetId id);
}

/// Describes if and how a [SingleStepReader] should read an [AssetId].
class Readability {
  final bool canRead;
  final bool inSamePhase;

  const Readability({required this.canRead, required this.inSamePhase});

  /// Determines readability for a node written in a previous build phase, which
  /// means that [ownOutput] is impossible.
  factory Readability.fromPreviousPhase(bool readable) =>
      readable ? Readability.readable : Readability.notReadable;

  static const Readability notReadable =
      Readability(canRead: false, inSamePhase: false);
  static const Readability readable =
      Readability(canRead: true, inSamePhase: false);
  static const Readability ownOutput =
      Readability(canRead: true, inSamePhase: true);
}

typedef IsReadable = FutureOr<Readability> Function(
    AssetNode node, int phaseNum, AssetWriterSpy? writtenAssets);

/// Signature of a function throwing an [InvalidInputException] if the given
/// asset [id] is an invalid input in a build.
typedef CheckInvalidInput = void Function(AssetId id);

/// An [AssetReader] with a lifetime equivalent to that of a single step in a
/// build.
///
/// A step is a single Builder and primary input (or package for package
/// builders) combination.
///
/// Limits reads to the assets which are sources or were generated by previous
/// phases.
///
/// Tracks the assets and globs read during this step for input dependency
/// tracking.
class SingleStepReader implements AssetReader, HasFilesystem {
  final AssetGraph _assetGraph;
  final Filesystem _filesystem;
  final AssetReader _delegate;
  final int _phaseNumber;
  final String _primaryPackage;
  final AssetWriterSpy? _writtenAssets;
  final IsReadable _isReadableNode;
  final CheckInvalidInput _checkInvalidInput;
  final FutureOr<GlobAssetNode> Function(
      Glob glob, String package, int phaseNum)? _getGlobNode;

  /// The assets read during this step.
  final assetsRead = HashSet<AssetId>();

  SingleStepReader(this._delegate, this._assetGraph, this._phaseNumber,
      this._primaryPackage, this._isReadableNode, this._checkInvalidInput,
      [this._getGlobNode, this._writtenAssets])
      : _filesystem = _delegate.filesystem;

  @override
  Filesystem get filesystem => _filesystem;

  /// Checks whether [id] can be read by this step - attempting to build the
  /// asset if necessary.
  ///
  /// If [catchInvalidInputs] is set to true and [_checkInvalidInput] throws an
  /// [InvalidInputException], this method will return `false` instead of
  /// throwing.
  FutureOr<bool> _isReadable(AssetId id, {bool catchInvalidInputs = false}) {
    try {
      _checkInvalidInput(id);
    } on InvalidInputException {
      if (catchInvalidInputs) return false;
      rethrow;
    } on PackageNotFoundException {
      if (catchInvalidInputs) return false;
      rethrow;
    }

    final node = _assetGraph.get(id);
    if (node == null) {
      assetsRead.add(id);
      _assetGraph.add(SyntheticSourceAssetNode(id));
      return false;
    }

    return doAfter(_isReadableNode(node, _phaseNumber, _writtenAssets),
        (Readability readability) {
      if (!readability.inSamePhase) {
        assetsRead.add(id);
      }

      return readability.canRead;
    });
  }

  @override
  Future<bool> canRead(AssetId id) {
    return toFuture(
        doAfter(_isReadable(id, catchInvalidInputs: true), (bool isReadable) {
      if (!isReadable) return false;
      var node = _assetGraph.get(id);
      FutureOr<bool> canRead() {
        if (node is GeneratedAssetNode) {
          // Short circut, we know this file exists because its readable and it
          // was output.
          return true;
        } else {
          return _delegate.canRead(id);
        }
      }

      return doAfter(canRead(), (bool canRead) {
        if (!canRead) return false;
        return doAfter(_ensureDigest(id), (_) => true);
      });
    }));
  }

  @override
  Future<Digest> digest(AssetId id) {
    return toFuture(doAfter(_isReadable(id), (bool isReadable) {
      if (!isReadable) {
        return Future.error(AssetNotFoundException(id));
      }
      return _ensureDigest(id);
    }));
  }

  @override
  Future<List<int>> readAsBytes(AssetId id) {
    return toFuture(doAfter(_isReadable(id), (bool isReadable) {
      if (!isReadable) {
        return Future.error(AssetNotFoundException(id));
      }
      return doAfter(_ensureDigest(id), (_) => _delegate.readAsBytes(id));
    }));
  }

  @override
  Future<String> readAsString(AssetId id, {Encoding encoding = utf8}) {
    return toFuture(doAfter(_isReadable(id), (bool isReadable) {
      if (!isReadable) {
        return Future.error(AssetNotFoundException(id));
      }
      return doAfter(_ensureDigest(id),
          (_) => _delegate.readAsString(id, encoding: encoding));
    }));
  }

  @override
  Stream<AssetId> findAssets(Glob glob) {
    if (_getGlobNode == null) {
      throw StateError('this reader does not support `findAssets`');
    }
    var streamCompleter = StreamCompleter<AssetId>();

    doAfter(_getGlobNode(glob, _primaryPackage, _phaseNumber),
        (GlobAssetNode globNode) {
      assetsRead.add(globNode.id);
      streamCompleter.setSourceStream(Stream.fromIterable(globNode.results!));
    });
    return streamCompleter.stream;
  }

  /// Returns the `lastKnownDigest` of [id], computing and caching it if
  /// necessary.
  ///
  /// Note that [id] must exist in the asset graph.
  FutureOr<Digest> _ensureDigest(AssetId id) {
    var node = _assetGraph.get(id)!;
    if (node.lastKnownDigest != null) return node.lastKnownDigest!;
    return _delegate.digest(id).then((digest) => node.lastKnownDigest = digest);
  }
}
