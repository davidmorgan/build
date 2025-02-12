// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:convert';
import 'dart:typed_data';

import 'package:build/build.dart';
// ignore: implementation_imports
import 'package:build/src/internal.dart';
import 'package:glob/glob.dart';

/// An [AssetReader] that records which assets have been read to [assetsRead].
abstract class RecordingAssetReader implements AssetReader {
  Iterable<AssetId> get assetsRead;
}

/// An implementation of [AssetReader] with primed in-memory assets.
class InMemoryAssetReader extends AssetReader
    implements MultiPackageAssetReader, RecordingAssetReader, AssetReaderState {
  final String? rootPackage;

  @override
  final InputTracker inputTracker = InputTracker();
  final _Filesystem _filesystem;

  @override
  Set<AssetId> get assetsRead => inputTracker.assetsRead;

  /// Create a new asset reader that contains [sourceAssets].
  ///
  /// Any strings in [sourceAssets] will be converted into a `List<int>` of
  /// bytes.
  ///
  /// May optionally define a [rootPackage], which is required for some APIs.
  InMemoryAssetReader({Map<AssetId, dynamic>? sourceAssets, this.rootPackage})
      : _filesystem = _Filesystem(_assetsAsBytes(sourceAssets));

  /// Create a new asset reader backed by [assets].
  InMemoryAssetReader.shareAssetCache(Map<AssetId, List<int>> assets,
      {this.rootPackage})
      : _filesystem = _Filesystem(
            assets.map((key, value) => MapEntry(key, _toUint8List(value))));

  @override
  Filesystem get filesystem => _filesystem;

  static Map<AssetId, Uint8List> _assetsAsBytes(Map<AssetId, dynamic>? assets) {
    if (assets == null || assets.isEmpty) {
      return {};
    }
    final output = <AssetId, Uint8List>{};
    assets.forEach((id, stringOrBytes) {
      if (stringOrBytes is List<int>) {
        output[id] = _toUint8List(stringOrBytes);
      } else if (stringOrBytes is String) {
        output[id] = utf8.encode(stringOrBytes);
      } else {
        throw UnsupportedError('Invalid asset contents: $stringOrBytes.');
      }
    });
    return output;
  }

  @override
  Future<bool> canRead(AssetId id) async {
    inputTracker.assetsRead.add(id);
    return _filesystem.assets.containsKey(id);
  }

  @override
  Future<List<int>> readAsBytes(AssetId id) async {
    if (!await canRead(id)) throw AssetNotFoundException(id);
    inputTracker.assetsRead.add(id);
    return _filesystem.assets[id]!;
  }

  @override
  Future<String> readAsString(AssetId id, {Encoding encoding = utf8}) async {
    if (!await canRead(id)) throw AssetNotFoundException(id);
    inputTracker.assetsRead.add(id);
    return encoding.decode(_filesystem.assets[id]!);
  }

  @override
  Stream<AssetId> findAssets(Glob glob, {String? package}) {
    package ??= rootPackage;
    if (package == null) {
      throw UnsupportedError(
          'Root package is required to use findAssets without providing an '
          'explicit package.');
    }
    return Stream.fromIterable(_filesystem.assets.keys
        .where((id) => id.package == package && glob.matches(id.path)));
  }

  void cacheBytesAsset(AssetId id, List<int> bytes) {
    _filesystem.assets[id] = _toUint8List(bytes);
  }

  void cacheStringAsset(AssetId id, String contents, {Encoding? encoding}) {
    encoding ??= utf8;
    _filesystem.assets[id] = _toUint8List(encoding.encode(contents));
  }

  static Uint8List _toUint8List(List<int> bytes) =>
      bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
}

class _Filesystem implements Filesystem {
  final Map<AssetId, Uint8List> assets;

  _Filesystem(this.assets);

  @override
  bool existsSync(AssetId id) => assets.containsKey(id);

  @override
  Uint8List readAsBytesSync(AssetId id) => assets[id]!;

  @override
  String readAsStringSync(AssetId id) => utf8.decode(assets[id]!);
}
