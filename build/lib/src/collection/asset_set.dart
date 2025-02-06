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
  final Set<AssetSetLeaf> _leaves;
  Set<AssetSetLeaf> get leaves => _leaves;

  factory AssetSet() => AssetSet._({AssetSetLeaf()});

  factory AssetSet.of(Iterable<AssetId> ids) =>
      AssetSet._({AssetSetLeaf.of(ids)});

  AssetSet._(Set<AssetSetLeaf> leaves) : _leaves = leaves;

  AssetSet _copy() => AssetSet._(_leaves.toSet());

  AssetSet copyWith(AssetId id) {
    if (contains(id)) return this;
    final result = _copy();
    final first = result._leaves.first;
    result._leaves.remove(first);
    final updatedFirst = first.copyWith(id);
    result._leaves.add(updatedFirst);
    return result;
  }

  AssetSet copyWithout(AssetId id) {
    if (!contains(id)) return this;
    final result = _copy();
    for (final set in _leaves) {
      if (set.contains(id)) {
        result._leaves.remove(set);
        result._leaves.add(set.copyWithout(id));
        return result;
      }
    }
    return result;
  }

  AssetSet copyWithAll(Iterable<AssetId> other) {
    final result = _copy();
    final first = result._leaves.first;
    result._leaves.remove(first);
    final updatedFirst = first.copyWithAll(other);
    result._leaves.add(updatedFirst);
    return result;
  }

  AssetSet copyWithAssetSet(AssetSet other) {
    final result = _copy();
    result._leaves.addAll(other._leaves);
    return result;
  }

  AssetSet difference(AssetSet other) {
    final result = _copy();
    for (final set in _leaves) {
      if (other.any(set.contains)) {
        result._leaves.remove(set);
        result._leaves.add(set.difference(other));
        return result;
      }
    }
    return result;
  }

  @override
  bool contains(Object? element) {
    return _leaves.any((leaf) => leaf.contains(element));
  }

  @override
  Iterator<AssetId> get iterator => _leaves.expand((leaf) => leaf).iterator;

  @override
  int get length => _leaves.fold(0, (total, leaf) => total + leaf.length);

  @override
  String toString() => 'AssetSet($_leaves)';
}

class AssetSetLeaf extends IterableBase<AssetId> {
  final HashSet<AssetId> _set;

  factory AssetSetLeaf() => AssetSetLeaf._(HashSet());

  factory AssetSetLeaf.of(Iterable<AssetId> ids) =>
      AssetSetLeaf._(HashSet.of(ids));

  AssetSetLeaf._(HashSet<AssetId> set) : _set = set;

  AssetSetLeaf _copy() => AssetSetLeaf._(HashSet.of(_set));

  AssetSetLeaf copyWith(AssetId id) {
    final result = AssetSetLeaf.of(_set);
    result._set.add(id);
    return result;
  }

  AssetSetLeaf copyWithout(AssetId id) {
    final result = _copy();
    result._set.remove(id);
    return result;
  }

  AssetSetLeaf copyWithAll(Iterable<AssetId> other) {
    final result = _copy();
    result._set.addAll(other);
    return result;
  }

  AssetSetLeaf difference(Iterable<AssetId> other) {
    final result = AssetSetLeaf.of(_set);
    result._set.removeAll(other);
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
  String toString() => 'AssetSetLeaf($_set)';
}
