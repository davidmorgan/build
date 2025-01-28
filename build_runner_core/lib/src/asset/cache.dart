// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:build/build.dart';
import 'package:crypto/crypto.dart';
import 'package:glob/glob.dart';

import 'lru_cache.dart';
import 'reader.dart';

/// An [AssetReader] that caches all results from the delegate.
///
/// Assets are cached until [invalidate] is invoked.
///
/// Does not implement [findAssets].
class CachingAssetReader implements AssetReader {
  /// Cached results of [readAsBytes].
  final _bytesContentCache = LruCache<AssetId, List<int>>(
    1024 * 1024,
    1024 * 1024 * 512,
    (value) => value is Uint8List ? value.lengthInBytes : value.length * 8,
  );

  /// Cached results of [canRead].
  ///
  /// Don't bother using an LRU cache for this since it's just booleans.
  final _canReadCache = <AssetId, bool>{};

  /// Cached results of [readAsString].
  ///
  /// These are computed and stored lazily using [readAsBytes].
  ///
  /// Only files read with [utf8] encoding (the default) will ever be cached.
  final _stringContentCache = LruCache<AssetId, String>(
    1024 * 1024,
    1024 * 1024 * 512,
    (value) => value.length,
  );

  final AssetReader _delegate;

  CachingAssetReader._(this._delegate);

  factory CachingAssetReader(AssetReader delegate) =>
      delegate is PathProvidingAssetReader
          ? _PathProvidingCachingAssetReader._(delegate)
          : CachingAssetReader._(delegate);

  @override
  bool canRead(AssetId id) =>
      _canReadCache.putIfAbsent(id, () => _delegate.canRead(id));

  @override
  Future<Digest> digest(AssetId id) => _delegate.digest(id);

  @override
  Stream<AssetId> findAssets(Glob glob) =>
      throw UnimplementedError('unimplemented!');

  @override
  List<int> readAsBytes(AssetId id, {bool cache = true}) {
    var cached = _bytesContentCache[id];
    if (cached != null) return cached;
    final result = _delegate.readAsBytes(id);
    if (cache) _bytesContentCache[id] = result;
    return result;
  }

  @override
  String readAsString(AssetId id, {Encoding encoding = utf8}) {
    if (encoding != utf8) {
      // Fallback case, we never cache the String value for the non-default,
      // encoding but we do allow it to cache the bytes.
      return encoding.decode(readAsBytes(id));
    }

    var cached = _stringContentCache[id];
    if (cached != null) return cached;
    final bytes = readAsBytes(id, cache: false);
    var decoded = encoding.decode(bytes);
    _stringContentCache[id] = decoded;
    return decoded;
  }

  /// Clears all [ids] from all caches.
  void invalidate(Iterable<AssetId> ids) {
    for (var id in ids) {
      _bytesContentCache.remove(id);
      _canReadCache.remove(id);
      _stringContentCache.remove(id);
    }
  }
}

/// A version of a [CachingAssetReader] that implements
/// [PathProvidingAssetReader].
class _PathProvidingCachingAssetReader extends CachingAssetReader
    implements PathProvidingAssetReader {
  @override
  PathProvidingAssetReader get _delegate =>
      super._delegate as PathProvidingAssetReader;

  _PathProvidingCachingAssetReader._(super.delegate) : super._();

  @override
  String pathTo(AssetId id) => _delegate.pathTo(id);
}
