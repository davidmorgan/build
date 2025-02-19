// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:_test_common/build_configs.dart';
import 'package:_test_common/common.dart';
import 'package:async/async.dart';
import 'package:build/build.dart';
import 'package:build_config/build_config.dart';
import 'package:build_runner/src/generate/watch_impl.dart' as watch_impl;
import 'package:build_runner_core/build_runner_core.dart';
import 'package:build_runner_core/src/asset_graph/graph.dart';
import 'package:build_runner_core/src/asset_graph/node.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:watcher/watcher.dart';

void main() {
  /// Basic phases/phase groups which get used in many tests
  final copyABuildApplication = applyToRoot(
      TestBuilder(buildExtensions: appendExtension('.copy', from: '.txt')));
  final defaultBuilderOptions = const BuilderOptions({});
  final packageConfigId = makeAssetId('a|.dart_tool/package_config.json');
  final packageGraph =
      buildPackageGraph({rootPackage('a', path: path.absolute('a')): []});
  late InMemoryRunnerAssetReaderWriter readerWriter;

  setUp(() async {
    readerWriter =
        InMemoryRunnerAssetReaderWriter(rootPackage: packageGraph.root.name);
    await readerWriter.writeAsString(
        packageConfigId, jsonEncode(_packageConfig));
  });

  group('watch', () {
    setUp(() {
      _terminateWatchController = StreamController();
    });

    tearDown(() {
      FakeWatcher.watchers.clear();
      return terminateWatch();
    });

    group('simple', () {
      test('rebuilds once on file updates', () async {
        var buildState = await startWatch(
            [copyABuildApplication], {'a|web/a.txt': 'a'}, readerWriter,
            packageGraph: packageGraph);
        var results = StreamQueue(buildState.buildResults);

        var result = await results.next;
        checkBuild(result,
            outputs: {'a|web/a.txt.copy': 'a'}, writer: readerWriter);

        await readerWriter.writeAsString(makeAssetId('a|web/a.txt'), 'b');

        result = await results.next;
        checkBuild(result,
            outputs: {'a|web/a.txt.copy': 'b'}, writer: readerWriter);

        // Wait for the `_debounceDelay` before terminating.
        await Future<void>.delayed(_debounceDelay);

        await terminateWatch();
        expect(await results.hasNext, isFalse);
      });

      test('emits an error message when no builders are specified', () async {
        var logs = <LogRecord>[];
        var buildState = await startWatch(
          [],
          {'a|web/a.txt.copy': 'a'},
          readerWriter,
          packageGraph: packageGraph,
          onLog: logs.add,
          logLevel: Level.SEVERE,
        );
        var result = await buildState.buildResults.first;
        expect(result.status, BuildStatus.success);
        expect(
            logs,
            contains(predicate((LogRecord record) => record.message.contains(
                'Nothing can be built, yet a build was requested.'))));
      });

      test('rebuilds on file updates outside hardcoded sources', () async {
        var buildState = await startWatch(
            [copyABuildApplication], {'a|test_files/a.txt': 'a'}, readerWriter,
            packageGraph: packageGraph,
            overrideBuildConfig: parseBuildConfigs({
              'a': {
                'targets': {
                  'a': {
                    'sources': ['test_files/**']
                  }
                }
              }
            }));
        var results = StreamQueue(buildState.buildResults);

        var result = await results.next;
        checkBuild(result,
            outputs: {'a|test_files/a.txt.copy': 'a'}, writer: readerWriter);

        await readerWriter.writeAsString(
            makeAssetId('a|test_files/a.txt'), 'b');

        result = await results.next;
        checkBuild(result,
            outputs: {'a|test_files/a.txt.copy': 'b'}, writer: readerWriter);
      });

      test('rebuilds on new files', () async {
        var buildState = await startWatch(
          [copyABuildApplication],
          {'a|web/a.txt': 'a'},
          readerWriter,
          packageGraph: packageGraph,
        );
        var results = StreamQueue(buildState.buildResults);

        var result = await results.next;
        checkBuild(result,
            outputs: {'a|web/a.txt.copy': 'a'}, writer: readerWriter);

        await readerWriter.writeAsString(makeAssetId('a|web/b.txt'), 'b');

        result = await results.next;
        checkBuild(result,
            outputs: {'a|web/b.txt.copy': 'b'}, writer: readerWriter);
        // Previous outputs should still exist.
        expect(readerWriter.assets[makeAssetId('a|web/a.txt.copy')],
            decodedMatches('a'));
      });

      test('rebuilds on new files outside hardcoded sources', () async {
        var buildState = await startWatch(
            [copyABuildApplication], {'a|test_files/a.txt': 'a'}, readerWriter,
            packageGraph: packageGraph,
            overrideBuildConfig: parseBuildConfigs({
              'a': {
                'targets': {
                  'a': {
                    'sources': ['test_files/**']
                  }
                }
              }
            }));
        var results = StreamQueue(buildState.buildResults);

        var result = await results.next;
        checkBuild(result,
            outputs: {'a|test_files/a.txt.copy': 'a'}, writer: readerWriter);

        await readerWriter.writeAsString(
            makeAssetId('a|test_files/b.txt'), 'b');

        result = await results.next;
        checkBuild(result,
            outputs: {'a|test_files/b.txt.copy': 'b'}, writer: readerWriter);
        // Previous outputs should still exist.
        expect(readerWriter.assets[makeAssetId('a|test_files/a.txt.copy')],
            decodedMatches('a'));
      });

      test('rebuilds on deleted files', () async {
        var buildState = await startWatch(
          [copyABuildApplication],
          {
            'a|web/a.txt': 'a',
            'a|web/b.txt': 'b',
          },
          readerWriter,
          packageGraph: packageGraph,
        );
        var results = StreamQueue(buildState.buildResults);

        var result = await results.next;
        checkBuild(result,
            outputs: {'a|web/a.txt.copy': 'a', 'a|web/b.txt.copy': 'b'},
            writer: readerWriter);

        // Don't call writer.delete, that has side effects.
        readerWriter.assets.remove(makeAssetId('a|web/a.txt'));
        FakeWatcher.notifyWatchers(
            WatchEvent(ChangeType.REMOVE, path.absolute('a', 'web', 'a.txt')));

        result = await results.next;

        // Shouldn't rebuild anything, no outputs.
        checkBuild(result, outputs: {}, writer: readerWriter);

        // The old output file should no longer exist either.
        expect(readerWriter.assets[makeAssetId('a|web/a.txt.copy')], isNull);
        // Previous outputs should still exist.
        expect(readerWriter.assets[makeAssetId('a|web/b.txt.copy')],
            decodedMatches('b'));
      });

      test('rebuilds on deleted files outside hardcoded sources', () async {
        var buildState = await startWatch([
          copyABuildApplication
        ], {
          'a|test_files/a.txt': 'a',
          'a|test_files/b.txt': 'b',
        }, readerWriter,
            packageGraph: packageGraph,
            overrideBuildConfig: parseBuildConfigs({
              'a': {
                'targets': {
                  'a': {
                    'sources': ['test_files/**']
                  }
                }
              }
            }));
        var results = StreamQueue(buildState.buildResults);

        var result = await results.next;
        checkBuild(result,
            outputs: {
              'a|test_files/a.txt.copy': 'a',
              'a|test_files/b.txt.copy': 'b'
            },
            writer: readerWriter);

        // Don't call writer.delete, that has side effects.
        readerWriter.assets.remove(makeAssetId('a|test_files/a.txt'));
        FakeWatcher.notifyWatchers(WatchEvent(
            ChangeType.REMOVE, path.absolute('a', 'test_files', 'a.txt')));

        result = await results.next;

        // Shouldn't rebuild anything, no outputs.
        checkBuild(result, outputs: {}, writer: readerWriter);

        // The old output file should no longer exist either.
        expect(readerWriter.assets[makeAssetId('a|test_files/a.txt.copy')],
            isNull);
        // Previous outputs should still exist.
        expect(readerWriter.assets[makeAssetId('a|test_files/b.txt.copy')],
            decodedMatches('b'));
      });

      test('rebuilds properly update asset_graph.json', () async {
        var buildState = await startWatch(
          [copyABuildApplication],
          {'a|web/a.txt': 'a', 'a|web/b.txt': 'b'},
          readerWriter,
          packageGraph: packageGraph,
        );
        var results = StreamQueue(buildState.buildResults);

        var result = await results.next;
        checkBuild(result,
            outputs: {'a|web/a.txt.copy': 'a', 'a|web/b.txt.copy': 'b'},
            writer: readerWriter);

        await readerWriter.writeAsString(makeAssetId('a|web/c.txt'), 'c');

        await readerWriter.writeAsString(makeAssetId('a|web/b.txt'), 'b2');

        // Don't call writer.delete, that has side effects.
        readerWriter.assets.remove(makeAssetId('a|web/a.txt'));
        FakeWatcher.notifyWatchers(
            WatchEvent(ChangeType.REMOVE, path.absolute('a', 'web', 'a.txt')));

        result = await results.next;
        checkBuild(result,
            outputs: {'a|web/b.txt.copy': 'b2', 'a|web/c.txt.copy': 'c'},
            writer: readerWriter);

        var cachedGraph = AssetGraph.deserialize(
            readerWriter.assets[makeAssetId('a|$assetGraphPath')]!);

        var expectedGraph = await AssetGraph.build(
            [],
            <AssetId>{},
            {packageConfigId},
            buildPackageGraph({rootPackage('a'): []}),
            readerWriter);

        var builderOptionsId = makeAssetId('a|Phase0.builderOptions');
        var builderOptionsNode = BuilderOptionsAssetNode(builderOptionsId,
            computeBuilderOptionsDigest(defaultBuilderOptions));
        expectedGraph.add(builderOptionsNode);

        var bCopyId = makeAssetId('a|web/b.txt.copy');
        var bTxtId = makeAssetId('a|web/b.txt');
        var bCopyNode = GeneratedAssetNode(bCopyId,
            phaseNumber: 0,
            primaryInput: makeAssetId('a|web/b.txt'),
            state: NodeState.upToDate,
            wasOutput: true,
            isFailure: false,
            builderOptionsId: builderOptionsId,
            lastKnownDigest: computeDigest(bCopyId, 'b2'),
            inputs: [makeAssetId('a|web/b.txt')],
            isHidden: false);
        builderOptionsNode.outputs.add(bCopyNode.id);
        expectedGraph
          ..add(bCopyNode)
          ..add(makeAssetNode(
              'a|web/b.txt', [bCopyNode.id], computeDigest(bTxtId, 'b2')));

        var cCopyId = makeAssetId('a|web/c.txt.copy');
        var cTxtId = makeAssetId('a|web/c.txt');
        var cCopyNode = GeneratedAssetNode(cCopyId,
            phaseNumber: 0,
            primaryInput: cTxtId,
            state: NodeState.upToDate,
            wasOutput: true,
            isFailure: false,
            builderOptionsId: builderOptionsId,
            lastKnownDigest: computeDigest(cCopyId, 'c'),
            inputs: [makeAssetId('a|web/c.txt')],
            isHidden: false);
        builderOptionsNode.outputs.add(cCopyNode.id);
        expectedGraph
          ..add(cCopyNode)
          ..add(makeAssetNode(
              'a|web/c.txt', [cCopyNode.id], computeDigest(cTxtId, 'c')));

        // TODO: We dont have a shared way of computing the combined input
        // hashes today, but eventually we should test those here too.
        expect(cachedGraph,
            equalsAssetGraph(expectedGraph, checkPreviousInputsDigest: false));
      });

      test('ignores events from nested packages', () async {
        final packageGraph = buildPackageGraph({
          rootPackage('a', path: path.absolute('a')): ['b'],
          package('b', path: path.absolute('a', 'b')): []
        });

        var buildState = await startWatch([
          copyABuildApplication,
        ], {
          'a|web/a.txt': 'a',
          'b|web/b.txt': 'b'
        }, readerWriter, packageGraph: packageGraph);
        var results = StreamQueue(buildState.buildResults);

        var result = await results.next;
        // Should ignore the files under the `b` package, even though they
        // match the input set.
        checkBuild(result,
            outputs: {'a|web/a.txt.copy': 'a'}, writer: readerWriter);

        await readerWriter.writeAsString(makeAssetId('a|web/a.txt'), 'b');
        await readerWriter.writeAsString(makeAssetId('b|web/b.txt'), 'c');
        // Have to manually notify here since the path isn't standard.
        FakeWatcher.notifyWatchers(WatchEvent(
            ChangeType.MODIFY, path.absolute('a', 'b', 'web', 'a.txt')));

        result = await results.next;
        // Ignores the modification under the `b` package, even though it
        // matches the input set.
        checkBuild(result,
            outputs: {'a|web/a.txt.copy': 'b'}, writer: readerWriter);
      });

      test('rebuilds on file updates during first build', () async {
        var blocker = Completer<void>();
        var buildAction =
            applyToRoot(TestBuilder(extraWork: (_, __) => blocker.future));
        var buildState = await startWatch(
          [buildAction],
          {'a|web/a.txt': 'a'},
          readerWriter,
          packageGraph: packageGraph,
        );
        var results = StreamQueue(buildState.buildResults);

        FakeWatcher.notifyWatchers(
            WatchEvent(ChangeType.MODIFY, path.absolute('a', 'web', 'a.txt')));
        blocker.complete();

        var result = await results.next;
        // TODO: Move this up above the call to notifyWatchers once
        // https://github.com/dart-lang/build/issues/526 is fixed.
        await readerWriter.writeAsString(makeAssetId('a|web/a.txt'), 'b');

        checkBuild(result,
            outputs: {'a|web/a.txt.copy': 'a'}, writer: readerWriter);

        result = await results.next;
        checkBuild(result,
            outputs: {'a|web/a.txt.copy': 'b'}, writer: readerWriter);
      });

      test(
          'edits to .dart_tool/package_config.json prevent future builds '
          'and ask you to restart', () async {
        var logs = <LogRecord>[];
        var buildState = await startWatch(
            [copyABuildApplication], {'a|web/a.txt': 'a'}, readerWriter,
            packageGraph: packageGraph,
            logLevel: Level.SEVERE,
            onLog: logs.add);
        var results = StreamQueue(buildState.buildResults);

        var result = await results.next;
        checkBuild(result,
            outputs: {'a|web/a.txt.copy': 'a'}, writer: readerWriter);

        var newConfig = Map.of(_packageConfig);
        newConfig['extra'] = 'stuff';
        await readerWriter.writeAsString(
            packageConfigId, jsonEncode(newConfig));

        expect(await results.hasNext, isFalse);
        expect(logs, hasLength(1));
        expect(
            logs.first.message,
            contains('Terminating builds due to package graph update, '
                'please restart the build.'));
      });

      test('Gives the package config a chance to be re-written before failing',
          () async {
        var logs = <LogRecord>[];
        var buildState = await startWatch(
            [copyABuildApplication], {'a|web/a.txt': 'a'}, readerWriter,
            packageGraph: packageGraph,
            logLevel: Level.SEVERE,
            onLog: logs.add);
        buildState.buildResults
            .handleError((Object e, StackTrace s) => print('$e\n$s'));
        buildState.buildResults.listen(print);
        var results = StreamQueue(buildState.buildResults);

        var result = await results.next;
        checkBuild(result,
            outputs: {'a|web/a.txt.copy': 'a'}, writer: readerWriter);

        await readerWriter.delete(packageConfigId);

        // Wait for it to try reading the file twice to ensure it will retry.
        await _readerForState[buildState]!
            .onCanRead
            .where((id) => id == packageConfigId)
            .take(2)
            .drain<void>();

        var newConfig = Map.of(_packageConfig);
        newConfig['extra'] = 'stuff';
        await readerWriter.writeAsString(
            packageConfigId, jsonEncode(newConfig));

        expect(await results.hasNext, isFalse);
        expect(logs, hasLength(1));
        expect(
            logs.first.message,
            contains('Terminating builds due to package graph update, '
                'please restart the build.'));
      });

      group('build.yaml', () {
        final packageGraph = buildPackageGraph({
          rootPackage('a', path: path.absolute('a')): ['b'],
          package('b', path: path.absolute('b'), type: DependencyType.path): []
        });
        late List<LogRecord> logs;
        late StreamQueue<BuildResult> results;

        group('is added', () {
          setUp(() async {
            logs = <LogRecord>[];
            var buildState = await startWatch(
                [copyABuildApplication], {}, readerWriter,
                logLevel: Level.SEVERE,
                onLog: logs.add,
                packageGraph: packageGraph);
            results = StreamQueue(buildState.buildResults);
            await results.next;
          });

          test('to the root package', () async {
            await readerWriter.writeAsString(
                AssetId('a', 'build.yaml'), '# New build.yaml file');
            expect(await results.hasNext, isTrue);
            var next = await results.next;
            expect(next.status, BuildStatus.failure);
            expect(next.failureType, FailureType.buildConfigChanged);
            expect(logs, hasLength(1));
            expect(logs.first.message,
                contains('Terminating builds due to a:build.yaml update'));
          });

          test('to a dependency', () async {
            await readerWriter.writeAsString(
                AssetId('b', 'build.yaml'), '# New build.yaml file');

            expect(await results.hasNext, isTrue);
            var next = await results.next;
            expect(next.status, BuildStatus.failure);
            expect(next.failureType, FailureType.buildConfigChanged);
            expect(logs, hasLength(1));
            expect(logs.first.message,
                contains('Terminating builds due to b:build.yaml update'));
          });

          test('<package>.build.yaml', () async {
            await readerWriter.writeAsString(
                AssetId('a', 'b.build.yaml'), '# New b.build.yaml file');
            expect(await results.hasNext, isTrue);
            var next = await results.next;
            expect(next.status, BuildStatus.failure);
            expect(next.failureType, FailureType.buildConfigChanged);
            expect(logs, hasLength(1));
            expect(logs.first.message,
                contains('Terminating builds due to a:b.build.yaml update'));
          });
        });

        group('is edited', () {
          setUp(() async {
            logs = <LogRecord>[];
            var buildState = await startWatch([copyABuildApplication],
                {'a|build.yaml': '', 'b|build.yaml': ''}, readerWriter,
                logLevel: Level.SEVERE,
                onLog: logs.add,
                packageGraph: packageGraph);
            results = StreamQueue(buildState.buildResults);
            await results.next;
          });

          test('in the root package', () async {
            await readerWriter.writeAsString(
                AssetId('a', 'build.yaml'), '# Edited build.yaml file');

            expect(await results.hasNext, isTrue);
            var next = await results.next;
            expect(next.status, BuildStatus.failure);
            expect(next.failureType, FailureType.buildConfigChanged);
            expect(logs, hasLength(1));
            expect(logs.first.message,
                contains('Terminating builds due to a:build.yaml update'));
          });

          test('in a dependency', () async {
            await readerWriter.writeAsString(
                AssetId('b', 'build.yaml'), '# Edited build.yaml file');

            expect(await results.hasNext, isTrue);
            var next = await results.next;
            expect(next.status, BuildStatus.failure);
            expect(next.failureType, FailureType.buildConfigChanged);
            expect(logs, hasLength(1));
            expect(logs.first.message,
                contains('Terminating builds due to b:build.yaml update'));
          });
        });

        group('with --config', () {
          setUp(() async {
            logs = <LogRecord>[];
            var buildState = await startWatch([copyABuildApplication],
                {'a|build.yaml': '', 'a|build.cool.yaml': ''}, readerWriter,
                configKey: 'cool',
                logLevel: Level.SEVERE,
                onLog: logs.add,
                overrideBuildConfig: {
                  'a': BuildConfig.useDefault('a', ['b'])
                },
                packageGraph: packageGraph);
            results = StreamQueue(buildState.buildResults);
            await results.next;
          });

          test('original is edited', () async {
            await readerWriter.writeAsString(
                AssetId('a', 'build.yaml'), '# Edited build.yaml file');

            expect(await results.hasNext, isTrue);
            var next = await results.next;
            expect(next.status, BuildStatus.failure);
            expect(next.failureType, FailureType.buildConfigChanged);
            expect(logs, hasLength(1));
            expect(logs.first.message,
                contains('Terminating builds due to a:build.yaml update'));
          });

          test('build.<config>.yaml in dependencies are ignored', () async {
            await readerWriter.writeAsString(
                AssetId('b', 'build.cool.yaml'), '# New build.yaml file');

            await Future<void>.delayed(_debounceDelay);
            expect(logs, isEmpty);

            await terminateWatch();
          });

          test('build.<config>.yaml is edited', () async {
            await readerWriter.writeAsString(AssetId('a', 'build.cool.yaml'),
                '# Edited build.cool.yaml file');

            expect(await results.hasNext, isTrue);
            var next = await results.next;
            expect(next.status, BuildStatus.failure);
            expect(next.failureType, FailureType.buildConfigChanged);
            expect(logs, hasLength(1));
            expect(logs.first.message,
                contains('Terminating builds due to a:build.cool.yaml update'));
          });
        });
      });
    });

    group('file updates to same contents', () {
      test('does not rebuild', () async {
        var runCount = 0;
        var buildState = await startWatch(
          [
            applyToRoot(TestBuilder(
                buildExtensions: appendExtension('.copy', from: '.txt'),
                build: (buildStep, _) {
                  runCount++;
                  buildStep.writeAsString(
                      buildStep.inputId.addExtension('.copy'),
                      buildStep.readAsString(buildStep.inputId));
                  throw StateError('Fail');
                }))
          ],
          {'a|web/a.txt': 'a'},
          readerWriter,
          packageGraph: packageGraph,
        );
        var results = StreamQueue(buildState.buildResults);

        var result = await results.next;
        expect(runCount, 1);
        checkBuild(result, status: BuildStatus.failure, writer: readerWriter);

        await readerWriter.writeAsString(makeAssetId('a|web/a.txt'), 'a');

        // Wait for the `_debounceDelay * 4` before terminating to
        // give it a chance to pick up the change.
        await Future<void>.delayed(_debounceDelay * 4);

        await terminateWatch();
        expect(await results.hasNext, isFalse);
      });
    });

    group('multiple phases', () {
      test('edits propagate through all phases', () async {
        var buildActions = [
          copyABuildApplication,
          applyToRoot(TestBuilder(
              buildExtensions: appendExtension('.copy', from: '.copy')))
        ];

        var buildState = await startWatch(
          buildActions,
          {'a|web/a.txt': 'a'},
          readerWriter,
          packageGraph: packageGraph,
        );
        var results = StreamQueue(buildState.buildResults);

        var result = await results.next;
        checkBuild(result,
            outputs: {'a|web/a.txt.copy': 'a', 'a|web/a.txt.copy.copy': 'a'},
            writer: readerWriter);

        await readerWriter.writeAsString(makeAssetId('a|web/a.txt'), 'b');

        result = await results.next;
        checkBuild(result,
            outputs: {'a|web/a.txt.copy': 'b', 'a|web/a.txt.copy.copy': 'b'},
            writer: readerWriter);
      });

      test('adds propagate through all phases', () async {
        var buildActions = [
          copyABuildApplication,
          applyToRoot(TestBuilder(
              buildExtensions: appendExtension('.copy', from: '.copy')))
        ];

        var buildState = await startWatch(
          buildActions,
          {'a|web/a.txt': 'a'},
          readerWriter,
          packageGraph: packageGraph,
        );
        var results = StreamQueue(buildState.buildResults);

        var result = await results.next;
        checkBuild(result,
            outputs: {'a|web/a.txt.copy': 'a', 'a|web/a.txt.copy.copy': 'a'},
            writer: readerWriter);

        await readerWriter.writeAsString(makeAssetId('a|web/b.txt'), 'b');

        result = await results.next;
        checkBuild(result,
            outputs: {'a|web/b.txt.copy': 'b', 'a|web/b.txt.copy.copy': 'b'},
            writer: readerWriter);
        // Previous outputs should still exist.
        expect(readerWriter.assets[makeAssetId('a|web/a.txt.copy')],
            decodedMatches('a'));
        expect(readerWriter.assets[makeAssetId('a|web/a.txt.copy.copy')],
            decodedMatches('a'));
      });

      test('deletes propagate through all phases', () async {
        var buildActions = [
          copyABuildApplication,
          applyToRoot(TestBuilder(
              buildExtensions: appendExtension('.copy', from: '.copy')))
        ];

        var buildState = await startWatch(
          buildActions,
          {'a|web/a.txt': 'a', 'a|web/b.txt': 'b'},
          readerWriter,
          packageGraph: packageGraph,
        );
        var results = StreamQueue(buildState.buildResults);

        var result = await results.next;
        checkBuild(result,
            outputs: {
              'a|web/a.txt.copy': 'a',
              'a|web/a.txt.copy.copy': 'a',
              'a|web/b.txt.copy': 'b',
              'a|web/b.txt.copy.copy': 'b'
            },
            writer: readerWriter);

        // Don't call writer.delete, that has side effects.
        readerWriter.assets.remove(makeAssetId('a|web/a.txt'));

        FakeWatcher.notifyWatchers(
            WatchEvent(ChangeType.REMOVE, path.absolute('a', 'web', 'a.txt')));

        result = await results.next;
        // Shouldn't rebuild anything, no outputs.
        checkBuild(result, outputs: {}, writer: readerWriter);

        // Derived outputs should no longer exist.
        expect(readerWriter.assets[makeAssetId('a|web/a.txt.copy')], isNull);
        expect(
            readerWriter.assets[makeAssetId('a|web/a.txt.copy.copy')], isNull);
        // Other outputs should still exist.
        expect(readerWriter.assets[makeAssetId('a|web/b.txt.copy')],
            decodedMatches('b'));
        expect(readerWriter.assets[makeAssetId('a|web/b.txt.copy.copy')],
            decodedMatches('b'));
      });

      test('deleted generated outputs are regenerated', () async {
        var buildActions = [
          copyABuildApplication,
          applyToRoot(TestBuilder(
              buildExtensions: appendExtension('.copy', from: '.copy')))
        ];

        var buildState = await startWatch(
          buildActions,
          {'a|web/a.txt': 'a'},
          readerWriter,
          packageGraph: packageGraph,
        );
        var results = StreamQueue(buildState.buildResults);

        var result = await results.next;
        checkBuild(result,
            outputs: {
              'a|web/a.txt.copy': 'a',
              'a|web/a.txt.copy.copy': 'a',
            },
            writer: readerWriter);

        // Don't call writer.delete, that has side effects.
        readerWriter.assets.remove(makeAssetId('a|web/a.txt.copy'));
        FakeWatcher.notifyWatchers(WatchEvent(
            ChangeType.REMOVE, path.absolute('a', 'web', 'a.txt.copy')));

        result = await results.next;
        // Should rebuild the generated asset, but not its outputs because its
        // content didn't change.
        checkBuild(result,
            outputs: {
              'a|web/a.txt.copy': 'a',
            },
            writer: readerWriter);
      });
    });

    /// Tests for updates
    group('secondary dependency', () {
      test('of an output file is edited', () async {
        var buildActions = [
          applyToRoot(TestBuilder(
              buildExtensions: appendExtension('.copy', from: '.a'),
              build: copyFrom(makeAssetId('a|web/file.b'))))
        ];

        var buildState = await startWatch(
          buildActions,
          {'a|web/file.a': 'a', 'a|web/file.b': 'b'},
          readerWriter,
          packageGraph: packageGraph,
        );
        var results = StreamQueue(buildState.buildResults);

        var result = await results.next;
        checkBuild(result,
            outputs: {'a|web/file.a.copy': 'b'}, writer: readerWriter);

        await readerWriter.writeAsString(makeAssetId('a|web/file.b'), 'c');

        result = await results.next;
        checkBuild(result,
            outputs: {'a|web/file.a.copy': 'c'}, writer: readerWriter);
      });

      test(
          'of an output which is derived from another generated file is edited',
          () async {
        var buildActions = [
          applyToRoot(TestBuilder(
              buildExtensions: appendExtension('.copy', from: '.a'))),
          applyToRoot(TestBuilder(
              buildExtensions: appendExtension('.copy', from: '.a.copy'),
              build: copyFrom(makeAssetId('a|web/file.b'))))
        ];

        var buildState = await startWatch(
          buildActions,
          {'a|web/file.a': 'a', 'a|web/file.b': 'b'},
          readerWriter,
          packageGraph: packageGraph,
        );
        var results = StreamQueue(buildState.buildResults);

        var result = await results.next;
        checkBuild(result,
            outputs: {'a|web/file.a.copy': 'a', 'a|web/file.a.copy.copy': 'b'},
            writer: readerWriter);

        await readerWriter.writeAsString(makeAssetId('a|web/file.b'), 'c');

        result = await results.next;
        checkBuild(result,
            outputs: {'a|web/file.a.copy.copy': 'c'}, writer: readerWriter);
      });
    });
  });
}

final _debounceDelay = const Duration(milliseconds: 10);
StreamController<ProcessSignal>? _terminateWatchController;

/// Start watching files and running builds.
Future<BuildState> startWatch(List<BuilderApplication> builders,
    Map<String, String> inputs, InMemoryRunnerAssetReaderWriter readerWriter,
    {required PackageGraph packageGraph,
    Map<String, BuildConfig> overrideBuildConfig = const {},
    void Function(LogRecord)? onLog,
    Level logLevel = Level.OFF,
    String? configKey}) async {
  onLog ??= (_) {};
  inputs.forEach((serializedId, contents) {
    readerWriter.writeAsString(makeAssetId(serializedId), contents);
  });
  FakeWatcher watcherFactory(String path) => FakeWatcher(path);

  var state = await watch_impl.watch(builders,
      configKey: configKey,
      deleteFilesByDefault: true,
      debounceDelay: _debounceDelay,
      directoryWatcherFactory: watcherFactory,
      overrideBuildConfig: overrideBuildConfig,
      reader: readerWriter,
      writer: readerWriter,
      packageGraph: packageGraph,
      terminateEventStream: _terminateWatchController!.stream,
      logLevel: logLevel,
      onLog: onLog,
      skipBuildScriptCheck: true);
  // Some tests need access to `reader` so we expose it through an expando.
  _readerForState[state] = readerWriter;
  return state;
}

/// Tells the program to stop watching files and terminate.
Future terminateWatch() async {
  var terminateWatchController = _terminateWatchController;
  if (terminateWatchController == null) return;

  /// Can add any type of event.
  terminateWatchController.add(ProcessSignal.sigabrt);
  await terminateWatchController.close();
  _terminateWatchController = null;
}

const _packageConfig = {
  'configVersion': 2,
  'packages': [
    {'name': 'a', 'rootUri': 'file://fake/pkg/path', 'packageUri': 'lib/'},
  ],
};

/// Store the private in memory asset reader for a given [BuildState] object
/// here so we can get access to it.
final _readerForState = Expando<InMemoryRunnerAssetReaderWriter>();
