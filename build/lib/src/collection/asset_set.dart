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

  void replace(AssetSet other) {
    _set = other;
    _builder = null;
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
  final Set<AssetComponent> _components;
  final Set<AssetId> _added;
  Iterable<AssetComponent> get components => _components;
  Iterable<AssetId> get otherIds => _added;

  factory AssetSet() => AssetSet._({}, {});

  factory AssetSet.of(Iterable<AssetId> ids) => AssetSet._({}, ids.toSet());

  AssetSet._(this._components, this._added);

  AssetSetBuilder toBuilder() => AssetSetBuilder._(_components, _added, this);

  AssetSet rebuild(void Function(AssetSetBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  AssetSet difference(AssetSet other) =>
      (toBuilder()..removeAssetSet(other)).build();

  @override
  bool contains(Object? element) {
    return _added.contains(element) ||
        _components.any((component) => component.contains(element));
  }

  @override
  Iterator<AssetId> get iterator =>
      _added.followedBy(_components.expand((component) => component)).iterator;

  @override
  int get length =>
      _added.length +
      _components.fold(0, (total, component) => total + component.length);

  @override
  String toString() => 'AssetSet($_components, $_added)';
}

class AssetSetBuilder {
  Set<AssetComponent> _components;
  Set<AssetId> _added;
  AssetSet? _stateOwner;

  factory AssetSetBuilder() =>
      AssetSetBuilder._(Set<AssetComponent>.identity(), {}, null);

  AssetSetBuilder._(this._components, this._added, this._stateOwner);

  AssetSet build() {
    if (_stateOwner != null) return _stateOwner!;
    return AssetSet._(_components, _added);
  }

  void update(void Function(AssetSetBuilder) updates) {
    updates(this);
  }

  void _disownState() {
    if (_stateOwner != null) {
      _components = _components.toSet();
      _added = _added.toSet();
      _stateOwner = null;
    }
  }

  bool add(AssetId id) {
    if (_contains(id)) return false;
    _disownState();
    _added.add(id);
    return true;
  }

  void addAll(Iterable<AssetId> ids) {
    for (final id in ids) {
      add(id);
    }
  }

  bool remove(AssetId id) {
    if (!_contains(id)) return false;
    _disownState();
    if (!_added.remove(id)) {
      throw StateError(
          '$id is in a component and cannot be removed individually');
    }
    return true;
  }

  void removeAll(Iterable<AssetId> ids) {
    _disownState();
    for (final id in ids) {
      remove(id);
    }
  }

  void clear() {
    _disownState();
    _components.clear();
    _added.clear();
  }

  bool addComponent(AssetComponent component) {
    if (_components.contains(component)) return false;
    _disownState();
    _components.add(component);
    return true;
  }

  void addAssetSet(AssetSet assetSet) {
    _disownState();
    _components.addAll(assetSet.components);
    addAll(assetSet.otherIds);
  }

  void removeAssetSet(AssetSet assetSet) {
    _disownState();
    _components.removeAll(assetSet.components);
    removeAll(assetSet.otherIds);
  }

  bool _contains(Object? element) {
    return _added.contains(element) ||
        _components.any((component) => component.contains(element));
  }
}

class AssetComponent extends IterableBase<AssetId> {
  final HashSet<AssetId> _set;

  factory AssetComponent() => AssetComponent._(HashSet());

  factory AssetComponent.of(Iterable<AssetId> ids) =>
      AssetComponent._(HashSet.of(ids));

  AssetComponent._(HashSet<AssetId> set) : _set = set;

  @override
  bool contains(Object? element) {
    return _set.contains(element);
  }

  @override
  Iterator<AssetId> get iterator => _set.iterator;

  @override
  int get length => _set.length;

  @override
  String toString() => 'AssetComponent($_set)';
}
