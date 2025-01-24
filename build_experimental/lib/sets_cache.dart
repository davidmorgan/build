import 'dart:collection';

import 'package:build/build.dart';

class SetsCache {
  final Map<int, List<HashSet<AssetId>>> _cache = {};

  HashSet<AssetId> dedupe(HashSet<AssetId> ids) {
    if (ids.isEmpty) return ids;
    final hash = Object.hash(ids.length, ids.first.hashCode);
    final possibleMatches = _cache[hash] ??= [];
    for (final map in possibleMatches) {
      if (_matches(map, ids)) {
        // print('Deduped! ${ids.length} ${ids.first}');
        return map;
      }
    }
    possibleMatches.add(ids);
    /*print(
      'Failed to dedupe! ${ids.length} ${ids.first} against ${possibleMatches.length} possible',
    );*/
    //print(ids.toString());
    //print(possibleMatches.first);
    return ids;
  }

  bool _matches(HashSet<AssetId> left, HashSet<AssetId> right) {
    if (left.length != right.length) return false;
    final lefts = left.toList()..sort();
    final rights = right.toList()..sort();
    for (var i = 0; i != left.length; ++i) {
      if (lefts[i] != rights[i]) {
        // print('Left: ${lefts[i]}, right: ${rights[i]}');
        return false;
      }
    }
    return true;
  }
}
