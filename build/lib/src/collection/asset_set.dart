// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import '../asset/id.dart';

class AssetSetHolder extends SetBase<AssetId> implements Set<AssetId> {
  AssetSet? _set;
  AssetSetBuilder? _builder;

  factory AssetSetHolder() => AssetSetHolder._(AssetSet());

  factory AssetSetHolder.of(Iterable<AssetId> other) =>
      AssetSetHolder()..addAll(other);

  AssetSetHolder._(this._set);

  AssetSet get assetSet => _asSet();

  AssetSet _asSet() {
    final result = _set ??= _builder!.build();
    _builder = null;
    return result;
  }

  AssetSetBuilder _asBuilder() {
    final result = _builder ??= _set!.toBuilder();
    _set = null;
    return result;
  }

  @override
  bool add(AssetId value) => _asBuilder().add(value);

  @override
  bool contains(Object? element) => _asSet().contains(element);

  @override
  Iterator<AssetId> get iterator => _asSet().iterator;

  @override
  int get length => _asSet().length;

  @override
  AssetId? lookup(Object? element) => throw UnimplementedError();

  @override
  bool remove(covariant AssetId value) => _asBuilder().remove(value);

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

  AssetSetBuilder toBuilder() => AssetSetBuilder._(_leaves, this);

  AssetSet rebuild(void Function(AssetSetBuilder) updates) =>
      (toBuilder()..update(updates)).build();

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

class AssetSetBuilder {
  Set<AssetSetLeaf> _leaves;
  AssetSet? _leavesOwner;

  factory AssetSetBuilder() => AssetSetBuilder._({AssetSetLeaf()}, null);

  AssetSetBuilder._(this._leaves, this._leavesOwner);

  AssetSet build() {
    if (_leavesOwner != null) return _leavesOwner!;
    return AssetSet._(_leaves);
  }

  void update(void Function(AssetSetBuilder) updates) {
    updates(this);
  }

  Set<AssetSetLeaf> get _safeLeaves {
    if (_leavesOwner != null) {
      _leaves = _leaves.toSet();
      _leavesOwner = null;
    }
    return _leaves;
  }

  bool add(AssetId id) {
    if (_contains(id)) return false;
    final leaves = _safeLeaves;
    final first = leaves.first;
    _leaves.remove(first);
    final updatedFirst = first.copyWith(id);
    _leaves.add(updatedFirst);
    return true;
  }

  bool addAll(Iterable<AssetId> ids) {
    final leaves = _safeLeaves;
    final first = leaves.first;
    leaves.remove(first);
    final updatedFirst = first.copyWithAll(ids);
    leaves.add(updatedFirst);
    return true;
  }

  bool remove(AssetId id) {
    if (!_contains(id)) return false;
    final leaves = _safeLeaves;
    for (final leaf in leaves.toList()) {
      if (leaf.contains(id)) {
        leaves.remove(leaf);
        leaves.add(leaf.copyWithout(id));
      }
    }
    return true;
  }

  void removeAll(Iterable<AssetId> ids) {
    final leaves = _safeLeaves;
    for (final set in leaves.toList()) {
      if (ids.any(set.contains)) {
        leaves.remove(set);
        leaves.add(set.difference(ids));
      }
    }
  }

  void clear() {
    final leaves = _safeLeaves;
    leaves.clear();
    leaves.add(AssetSetLeaf());
  }

  bool addAssetSet(AssetSet ids) {
    if (!ids.leaves.any((leaf) => !_leaves.contains(leaf))) return false;
    _safeLeaves.addAll(ids.leaves);
    return true;
  }

  bool _contains(Object? element) {
    return _leaves.any((leaf) => leaf.contains(element));
  }
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
