// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import '../asset/id.dart';

class AssetSetHolder extends SetBase<AssetId> implements Set<AssetId> {
  AssetSet _set;

  factory AssetSetHolder() => AssetSetHolder._(AssetSet());

  factory AssetSetHolder.of(Iterable<AssetId> other) =>
      AssetSetHolder()..addAll(other);

  AssetSetHolder._(this._set);

  AssetSet get assetSet => _set;

  @override
  bool add(AssetId value) {
    final oldSet = _set;
    _set = _set.copyWith(value);
    return _set != oldSet;
  }

  @override
  bool contains(Object? element) => _set.contains(element);

  @override
  Iterator<AssetId> get iterator => _set.iterator;

  @override
  int get length => _set.length;

  @override
  AssetId? lookup(Object? element) => throw UnimplementedError();

  @override
  bool remove(covariant AssetId value) {
    final oldSet = _set;
    _set = _set.copyWithout(value);
    return _set != oldSet;
  }

  @override
  Set<AssetId> toSet() => AssetSetHolder._(_set);
}

class AssetSet extends IterableBase<AssetId> {
  final HashSet<AssetId> _set;
  final HashSet<AssetSet> _seen;

  factory AssetSet() => AssetSet._(HashSet(), HashSet());

  factory AssetSet.of(Iterable<AssetId> ids) =>
      AssetSet._(HashSet.of(ids), HashSet());

  AssetSet._(HashSet<AssetId> set, HashSet<AssetSet> seen)
      : _set = set,
        _seen = seen;

  AssetSet _copy() => AssetSet._(HashSet.of(_set), HashSet.of(_seen));

  AssetSet copyWith(AssetId id) {
    final result = AssetSet.of(_set);
    result._set.add(id);
    return result;
  }

  AssetSet copyWithout(AssetId id) {
    final result = _copy();
    result._set.remove(id);
    return result;
  }

  AssetSet copyWithAll(Iterable<AssetId> other) {
    final result = _copy();
    result._set.addAll(other);
    return result;
  }

  AssetSet copyWithAssetSet(AssetSet other) {
    if (_seen.contains(other)) return this;
    final result = _copy();
    result._set.addAll(other);
    result._seen.add(other);
    return result;
  }

  AssetSet difference(AssetSet other) {
    final result = AssetSet.of(_set);
    result._set.removeAll(other._set);
    return result;
  }

  @override
  bool contains(Object? element) {
    return _set.contains(element);
  }

  @override
  Iterator<AssetId> get iterator => _set.iterator;

  @override
  int get length => _set.length;

  @override
  String toString() => 'AssetSet($_set, $_seen)';
}
