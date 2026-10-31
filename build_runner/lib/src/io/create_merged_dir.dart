// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:build/build.dart';
import 'package:built_collection/built_collection.dart';
import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';

import '../build_plan/build_directory.dart';
import '../build_plan/build_packages.dart';
import '../logging/build_log.dart';
import '../logging/timed_activities.dart';
import 'build_output_reader.dart';

/// Pool for async file operations, we don't want to use too many file handles.
final _descriptorPool = Pool(32);

const _manifestName = '.build.manifest';
const _manifestSeparator = '\n';

/// Creates merged output directories for each [OutputLocation].
///
/// Returns whether it succeeded or not.
Future<bool> createMergedOutputDirectories({
  required BuiltSet<BuildDirectory> buildDirs,
  required BuildPackages buildPackages,
  required bool outputSymlinksOnly,
  required BuildOutputReader buildOutputReader,
}) async {
  return await TimedActivity.write.runAsync(() async {
    final conflictingOutputs = _conflicts(buildDirs);
    if (conflictingOutputs.isNotEmpty) {
      buildLog.error(
        'Unable to create merged directory. '
        'Conflicting outputs for $conflictingOutputs',
      );
      return false;
    }

    for (final target in buildDirs) {
      final outputLocation = target.outputLocation;
      if (outputLocation != null) {
        if (!await _createMergedOutputDir(
          buildOutputReader: buildOutputReader,
          buildPackages: buildPackages,
          outputPath: outputLocation.path,
          root: target.directory,
          // TODO(grouma) - retrieve symlink information from target only.
          symlinkOnly: outputSymlinksOnly || outputLocation.useSymlinks,
          hoist: outputLocation.hoist,
        )) {
          return false;
        }
      }
    }
    return true;
  });
}

Set<String> _conflicts(BuiltSet<BuildDirectory> buildDirs) {
  final seen = <String>{};
  final conflicts = <String>{};
  final outputLocations = buildDirs
      .map((d) => d.outputLocation?.path)
      .nonNulls
      .map(p.normalize);
  for (final location in outputLocations) {
    if (!seen.add(location)) conflicts.add(location);
  }
  return conflicts;
}

Future<bool> _createMergedOutputDir({
  required String outputPath,
  required String root,
  required BuildPackages buildPackages,
  required bool symlinkOnly,
  required bool hoist,
  required BuildOutputReader buildOutputReader,
}) async {
  try {
    final outputRootPackage = buildPackages[buildPackages.outputRoot]!;
    final absoluteRoot = p.join(outputRootPackage.path, root);
    if (absoluteRoot != outputRootPackage.path &&
        !p.isWithin(outputRootPackage.path, absoluteRoot)) {
      buildLog.error(
        'Invalid dir to build `$root`, must be within the package root.',
      );
      return false;
    }
    final outputDir = Directory(outputPath);
    final outputDirExists = await outputDir.exists();
    var previousOutputs = <String>[];
    if (outputDirExists) {
      final outputs = _previousOutputs(outputDir);
      if (outputs == null) return false;
      previousOutputs = outputs;
    }
    final builtAssets = buildOutputReader.allAssets(rootDir: root).toList();
    if (root != '' &&
        !builtAssets
            .where((id) => id.package == buildPackages.outputRoot)
            .any((id) => p.isWithin(root, id.path))) {
      _deleteOutputs(outputDir, previousOutputs);
      buildLog.error('No assets exist in $root, skipping output.');
      return false;
    }

    final packageConfigPath = '.dart_tool/package_config.json';
    // Delete removed outputs before writing, so that a path which changes
    // between file and directory is free when it is written.
    _deleteOutputs(
      outputDir,
      previousOutputs.toSet().difference({
        packageConfigPath,
        for (final id in builtAssets)
          _normalize(_assetPath(id, root, buildPackages, hoist)),
      }),
    );

    final outputPaths = <String>[];
    if (!outputDirExists) {
      await outputDir.create(recursive: true);
    }

    outputPaths.addAll(
      await Future.wait([
        for (final id in builtAssets)
          _writeAsset(
            buildOutputReader,
            id,
            outputDir,
            root,
            buildPackages,
            symlinkOnly,
            hoist,
          ),
        _writeModifiedPackageConfig(
          buildPackages.outputRoot,
          buildPackages,
          outputDir,
          packageConfigPath,
        ),
      ]),
    );

    if (!hoist) {
      for (final dir in _findRootDirs(builtAssets, outputPath)) {
        final link = Link(p.join(outputDir.path, dir, 'packages'));
        if (!link.existsSync()) {
          link.createSync(p.join('..', 'packages'), recursive: true);
        }
      }
    }

    final manifestPaths = outputPaths.map(_normalize).toList()..sort();
    await _writeAsString(
      outputDir,
      _manifestName,
      manifestPaths.join(_manifestSeparator),
    );

    return true;
  } on FileSystemException catch (e) {
    if (e.osError?.errorCode != 1314) rethrow;
    final devModeLink =
        'https://docs.microsoft.com/en-us/windows/uwp/get-started/'
        'enable-your-device-for-development';
    buildLog.error(
      'Failed to create merged output directory with symlinks. '
      'To allow creation of symlinks run in a console with admin privileges '
      'or enable developer mode following $devModeLink.',
    );
    return false;
  }
}

/// Creates a modified `.dart_tool/package_config.json` file in [outputDir]
/// based on the current one but with modified root and package uris.
///
/// All `rootUri`s are of the form `packages/<package>` and the `packageUri`
/// is always the empty string. This is because only the lib directory is
/// exposed when using a `packages` directory layout so the root uri and
/// package uri are equivalent.
///
/// All other fields are left as is.
///
/// Returns the relative path that was written to.
Future<String> _writeModifiedPackageConfig(
  String rootPackage,
  BuildPackages buildPackages,
  Directory outputDir,
  String packageConfigPath,
) async {
  final packageConfig = <String, Object?>{
    'configVersion': 2,
    'packages': [
      for (final package in buildPackages.packages.values)
        {
          'name': package.name,
          'rootUri': package.name == rootPackage
              ? '../'
              : '../packages/${package.name}',
          'packageUri': package.name == rootPackage
              ? 'packages/${package.name}'
              : '',
          if (package.languageVersion != null)
            'languageVersion': '${package.languageVersion}',
        },
    ],
  };
  await _writeAsString(outputDir, packageConfigPath, jsonEncode(packageConfig));
  return packageConfigPath;
}

Set<String> _findRootDirs(Iterable<AssetId> allAssets, String outputPath) {
  final rootDirs = <String>{};
  for (final id in allAssets) {
    final parts = p.url.split(id.path);
    if (parts.length == 1) continue;
    final dir = parts.first;
    if (dir == outputPath || dir == 'lib') continue;
    rootDirs.add(parts.first);
  }
  return rootDirs;
}

/// Writes [id] to [outputDir].
///
/// Returns the relative path under [outputDir] that it was written to.
Future<String> _writeAsset(
  BuildOutputReader buildOutputReader,
  AssetId id,
  Directory outputDir,
  String root,
  BuildPackages buildPackages,
  bool symlinkOnly,
  bool hoist,
) {
  return _descriptorPool.withResource(() async {
    final assetPath = _assetPath(id, root, buildPackages, hoist);

    try {
      if (symlinkOnly) {
        final linkPath = _filePathFor(outputDir, assetPath);
        final target = buildOutputReader.pathFor(id);
        final link = Link(linkPath);
        switch (FileSystemEntity.typeSync(linkPath, followLinks: false)) {
          case FileSystemEntityType.notFound:
            break;
          case FileSystemEntityType.link:
            if (link.targetSync() == target) return assetPath;
            link.deleteSync();
          default:
            File(linkPath).deleteSync();
        }
        await link.create(target, recursive: true);
      } else {
        await _writeAsBytes(
          outputDir,
          assetPath,
          (await buildOutputReader.read(id)).bytes,
        );
      }
    } on AssetNotFoundException catch (e) {
      if (!p.basename(id.path).startsWith('.')) {
        buildLog.error(
          'Missing asset ${e.assetId}, it may have been deleted during the '
          'build. Please try rebuilding and if you continue to see the '
          'error then file a bug at '
          'https://github.com/dart-lang/build/issues/new.',
        );
        rethrow;
      }
    }
    return assetPath;
  });
}

/// Returns the path under the output directory that [id] is written to.
String _assetPath(
  AssetId id,
  String root,
  BuildPackages buildPackages,
  bool hoist,
) {
  if (id.path.startsWith('lib/')) {
    return p.url.join('packages', id.package, id.path.substring('lib/'.length));
  }
  assert(id.package == buildPackages.outputRoot);
  if (hoist && p.isWithin(root, id.path)) {
    return p.relative(id.path, from: root);
  }
  return id.path;
}

/// Normalizes path separators for the manifest.
String _normalize(String path) => path.replaceAll(r'\', '/');

/// Writes [bytes] to [path] under [outputDir], unless the file there already
/// has exactly those bytes.
///
/// Leaving unchanged files alone keeps their modification times, so tools
/// watching the output directory see only what changed.
Future<void> _writeAsBytes(
  Directory outputDir,
  String path,
  List<int> bytes,
) async {
  final filePath = _filePathFor(outputDir, path);
  final file = File(filePath);
  switch (FileSystemEntity.typeSync(filePath, followLinks: false)) {
    case FileSystemEntityType.notFound:
      break;
    case FileSystemEntityType.file:
      if (_bytesEqual(await file.readAsBytes(), bytes)) return;
    default:
      // Most likely a symlink from a previous `--symlink` build: writing
      // through it would change the file it points to.
      Link(filePath).deleteSync();
  }
  await file.create(recursive: true);
  await file.writeAsBytes(bytes);
}

Future<void> _writeAsString(
  Directory outputDir,
  String path,
  String contents,
) => _writeAsBytes(outputDir, path, utf8.encode(contents));

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _filePathFor(Directory outputDir, String path) {
  return p.join(outputDir.path, path);
}

/// Returns the paths listed in the manifest file in [outputDir].
///
/// Returns an empty list if there is no manifest and [outputDir] is empty.
/// Logs an error and returns `null` if there is no manifest but [outputDir]
/// has other files in it.
List<String>? _previousOutputs(Directory outputDir) {
  final outputPath = outputDir.resolveSymbolicLinksSync();
  final manifestFile = File(p.join(outputPath, _manifestName));
  if (!manifestFile.existsSync()) {
    if (outputDir.listSync(recursive: false).isNotEmpty) {
      buildLog.error(
        'Unable to create merged directory $outputPath. Choose a different '
        'directory or delete the contents of that directory.',
      );
      return null;
    }
    return [];
  }
  return manifestFile.readAsStringSync().split(_manifestSeparator);
}

/// Deletes [paths] under [outputDir], then any directories they leave empty.
void _deleteOutputs(Directory outputDir, Iterable<String> paths) {
  if (paths.isEmpty) return;
  final outputPath = outputDir.resolveSymbolicLinksSync();
  for (final path in paths) {
    final filePath = p.join(outputPath, path);
    // Check the parent rather than the file itself: a link from a
    // `--symlink` build resolves outside the output directory, and may be
    // broken.
    final parent = Directory(p.dirname(filePath));
    if (!parent.existsSync()) continue;
    final resolvedParent = parent.resolveSymbolicLinksSync();
    if (resolvedParent != outputPath &&
        !p.isWithin(outputPath, resolvedParent)) {
      continue;
    }
    switch (FileSystemEntity.typeSync(filePath, followLinks: false)) {
      case FileSystemEntityType.link:
        Link(filePath).deleteSync();
      case FileSystemEntityType.file:
        File(filePath).deleteSync();
      default:
        break;
    }
  }
  _cleanEmptyDirectories(outputPath, paths);
}

/// Deletes all the directories which used to contain any path in
/// [removedFilePaths] if that directory is now empty.
void _cleanEmptyDirectories(
  String outputPath,
  Iterable<String> removedFilePaths,
) {
  for (final directory
      in removedFilePaths
          .map((path) => p.join(outputPath, p.dirname(path)))
          .toSet()) {
    _deleteUp(directory, outputPath);
  }
}

/// Deletes the directory at [from] and and any parent directories which are
/// subdirectories of [to] if they are empty.
void _deleteUp(String from, String to) {
  var directoryPath = from;
  while (p.isWithin(to, directoryPath)) {
    final directory = Directory(directoryPath);
    if (!_existsResolvedWithin(directory, to) ||
        directory.listSync().isNotEmpty) {
      return;
    }
    directory.deleteSync();
    directoryPath = p.dirname(directoryPath);
  }
}

bool _existsResolvedWithin(FileSystemEntity entity, String rootPath) {
  if (!entity.existsSync()) return false;
  return p.isWithin(rootPath, entity.resolveSymbolicLinksSync());
}
