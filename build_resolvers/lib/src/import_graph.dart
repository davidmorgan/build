import 'dart:collection';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:build/build.dart';
import 'package:graphs/graphs.dart';
import 'package:pool/pool.dart';

class ImportGraph {
  final pool = Pool(1);

  final Map<AssetId, ImportGraphNode> _nodes = {};

  Map<AssetId, List<AssetId>>? _loops;

  void resolve(AssetReader reader, Iterable<AssetId> entryPoints) {
    _resolve(reader, entryPoints);
  }

  void _resolve(AssetReader reader, Iterable<AssetId> entryPoints) {
    final nextIds = Queue.of(entryPoints);
    var anyChanges = false;
    while (nextIds.isNotEmpty) {
      final nextId = nextIds.removeFirst();
      if (_nodes.containsKey(nextId)) continue;
      final node = ImportGraphNode.read(reader, nextId);
      _nodes[nextId] = node;
      anyChanges = true;
      nextIds.addAll(node.dependencies.where((id) => !_nodes.containsKey(id)));
    }

    if (anyChanges) {
      print('Resolved $entryPoints with ${_nodes.length} nodes');
      _loops = null;
    }
  }

  Iterable<ImportGraphNode> get nodes => _nodes.values;

  AssetId? loopOwner(AssetId id) {
    return _loopOwner(id);
  }

  AssetId? _loopOwner(AssetId id) {
    if (_loops == null) findLoops();
    return _loops![id]?.first;
  }

  static Duration totalDuration = Duration.zero;

  void findLoops() {
    final stopwatch = Stopwatch()..start();
    _loops = {};
    final loops = stronglyConnectedComponents(
      _nodes.keys,
      (id) => _nodes[id]!.dependencies,
    );

    for (final loop in loops) {
      if (loop.length == 1) continue;
      loop.sort();
      for (final id in loop) {
        _loops![id] = loop;
      }
    }
    final elapsed = stopwatch.elapsed;
    totalDuration += elapsed;
    print(
      'Computed loops in ${elapsed.inMilliseconds}ms,'
      ' total ${totalDuration.inMilliseconds}ms',
    );
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

  static ImportGraphNode read(AssetReader reader, AssetId id) {
    if (reader.canRead(id)) {
      return ImportGraphNode(
        id: id,
        dependencies: _parseDependencies(reader.readAsString(id), id),
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
