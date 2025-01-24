import 'dart:collection';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:build/build.dart';

class ImportGraph {
  final Map<AssetId, ImportGraphNode> _nodes = {};

  Future<void> resolve(
    AssetReader reader,
    Iterable<AssetId> entryPoints,
  ) async {
    final nextIds = Queue.of(entryPoints);

    while (nextIds.isNotEmpty) {
      final nextId = nextIds.removeFirst();
      if (_nodes.containsKey(nextId)) continue;
      final node = await ImportGraphNode.read(reader, nextId);
      _nodes[nextId] = node;
      nextIds.addAll(node.dependencies.where((id) => !_nodes.containsKey(id)));
    }

    print('Resolved $entryPoints with ${_nodes.length} nodes');
  }

  Iterable<ImportGraphNode> get nodes => _nodes.values;
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
