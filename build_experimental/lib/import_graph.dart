import 'dart:collection';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:build/build.dart';
import 'package:pool/pool.dart';

class ImportGraph {
  final pool = Pool(1);

  final Map<AssetId, ImportGraphNode> _nodes = {};

  final Map<AssetId, Set<AssetId>> _transitiveDependencies = {};

  final Map<AssetId, List<AssetId>> _loops = {};

  Future<void> resolve(
    AssetReader reader,
    Iterable<AssetId> entryPoints,
  ) async {
    await pool.withResource(() => _resolve(reader, entryPoints));
  }

  Future<void> _resolve(
    AssetReader reader,
    Iterable<AssetId> entryPoints,
  ) async {
    final nextIds = Queue.of(entryPoints);
    var anyChanges = false;
    while (nextIds.isNotEmpty) {
      final nextId = nextIds.removeFirst();
      if (_nodes.containsKey(nextId)) continue;
      final node = await ImportGraphNode.read(reader, nextId);
      _nodes[nextId] = node;
      anyChanges = true;
      nextIds.addAll(node.dependencies.where((id) => !_nodes.containsKey(id)));
    }

    if (anyChanges) {
      print('Resolved $entryPoints with ${_nodes.length} nodes');
      if (anyChanges) findLoops();
    } else {
      print('No changes to import graph');
    }
  }

  Iterable<ImportGraphNode> get nodes => _nodes.values;

  AssetId? loopOwner(AssetId id) => _loops[id]?.first;

  void findLoops() {
    _loops.clear();
    _transitiveDependencies.clear();

    for (final id in _nodes.keys) {
      _computeTransitiveDependencies(id);
    }

    for (final id in _nodes.keys) {
      if (_loops.containsKey(id)) continue;
      final transitiveDeps = _transitiveDependencies[id]!;
      if (transitiveDeps.contains(id)) {
        final loop =
            transitiveDeps
                .where((dep) => _transitiveDependencies[dep]!.contains(id))
                .toList()
              ..sort();
        for (final loopMember in loop) {
          _loops[loopMember] = loop;
        }
        print('Found loop: $loop');
      }
    }
  }

  void _computeTransitiveDependencies(AssetId id) {
    if (_transitiveDependencies.containsKey(id)) return;
    final result = <AssetId>{};
    _addDepsRecursively(id, result);
    _transitiveDependencies[id] = result;
  }

  void _addDepsRecursively(AssetId id, Set<AssetId> result) {
    if (!_nodes.containsKey(id))
      print('wut? $id not in ${_nodes.keys.toList()..sort()}');
    final nextDeps = _nodes[id]!.dependencies;
    for (final nextDep in nextDeps) {
      if (result.add(nextDep)) {
        _addDepsRecursively(nextDep, result);
      }
    }
  }
}

class ImportGraphNode {
  final AssetId id;
  final bool missing;
  final List<AssetId> dependencies;

  ImportGraphNode({required this.id, required this.dependencies})
    : missing = false;
  ImportGraphNode.missing({required this.id})
    : missing = true,
      dependencies = [];

  static Future<ImportGraphNode> read(AssetReader reader, AssetId id) async {
    if (await reader.canRead(id)) {
      return ImportGraphNode(
        id: id,
        dependencies: _parseDependencies(await reader.readAsString(id), id),
      );
    } else {
      return ImportGraphNode.missing(id: id);
    }
  }
}

const _ignoredSchemes = ['dart', 'dart-ext'];

/// Returns all the directives from a Dart library that can be resolved to an
/// [AssetId].
List<AssetId> _parseDependencies(String content, AssetId from) =>
    SplayTreeSet.of(
      parseString(content: content, throwIfDiagnostics: false).unit.directives
          .whereType<UriBasedDirective>()
          .map((directive) => directive.uri.stringValue)
          // Filter out nulls. uri.stringValue can be null for strings that use
          // interpolation.
          .whereType<String>()
          .where(
            (uriContent) =>
                !_ignoredSchemes.any(Uri.parse(uriContent).isScheme),
          )
          .map((content) => AssetId.resolve(Uri.parse(content), from: from)),
    ).toList();
