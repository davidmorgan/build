// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:build/build.dart';
import 'package:built_collection/built_collection.dart';
import 'package:crypto/crypto.dart';

import '../constants.dart';
import '../io/reader_writer.dart';
import '../logging/build_log.dart';

/// The required edits builders reported for one source, and the md5 [digest]
/// of the source content they were reported for.
class SourceRequiredEdits {
  final Digest digest;
  final BuiltList<RequiredEdit> edits;

  SourceRequiredEdits(this.digest, this.edits);

  /// Applies [requiredEdits] to their sources and reports them, or with
  /// [onlyCheck] only reports them.
  ///
  /// As for `part` directives, a source that changed since the build read it
  /// is not edited, and the next build decides again. Edits that overlap a
  /// later one in the same source are left for the next build.
  static Future<void> apply(
    BuiltMap<AssetId, SourceRequiredEdits> requiredEdits,
    ReaderWriter readerWriter, {
    required bool onlyCheck,
  }) async {
    String lines(Iterable<AssetId> ids) => [
      for (final id in ids)
        for (final edit in requiredEdits[id]!.edits)
          '${buildLog.renderId(id)}: ${edit.message}',
    ].join('\n');

    final ids = requiredEdits.keys.toList()
      ..sort((a, b) => '$a'.compareTo('$b'));
    if (onlyCheck) {
      buildLog.error('Fix errors in sources:\n\n${lines(ids)}');
      return;
    }
    final editedIds = <AssetId>[];
    final changedDuringBuildIds = <AssetId>[];
    for (final id in ids) {
      final bytes = await readerWriter.readAsBytes(id);
      if (md5.convert(bytes) != requiredEdits[id]!.digest) {
        changedDuringBuildIds.add(id);
        continue;
      }
      var source = utf8.decode(bytes);
      final edits = requiredEdits[id]!.edits.toList()
        ..sort((a, b) => b.offset.compareTo(a.offset));
      int? lowestOffset;
      for (final edit in edits) {
        final end = edit.offset + edit.length;
        if (end > source.length) continue;
        if (lowestOffset != null && end > lowestOffset) continue;
        source = source.replaceRange(edit.offset, end, edit.replacement);
        lowestOffset = edit.offset;
      }
      await readerWriter.writeAsString(id, source);
      editedIds.add(id);
    }
    if (editedIds.isNotEmpty) {
      buildLog.error('Fixed errors in sources:\n\n${lines(editedIds)}');
    }
    if (changedDuringBuildIds.isNotEmpty) {
      buildLog.error(
        'Not fixing errors in sources that changed during the build:\n\n'
        '${changedDuringBuildIds.map(buildLog.renderId).join('\n')}',
      );
    }
  }

  /// Writes [requiredEdits] to [sourceEditsPath] in [outputRoot] as JSON, for
  /// tools to read.
  static Future<void> write(
    Map<AssetId, Iterable<RequiredEdit>> requiredEdits,
    ReaderWriter readerWriter, {
    required String outputRoot,
  }) async {
    final ids = requiredEdits.keys.toList()
      ..sort((a, b) => '$a'.compareTo('$b'));
    final edits = <Map<String, Object?>>[];
    for (final id in ids) {
      final sorted = requiredEdits[id]!.toList()
        ..sort((a, b) => a.offset.compareTo(b.offset));
      for (final edit in sorted) {
        edits.add({
          'package': id.package,
          'path': id.path,
          'message': edit.message,
          'offset': edit.offset,
          'length': edit.length,
          'replacement': edit.replacement,
        });
      }
    }
    await readerWriter.writeAsString(
      AssetId(outputRoot, sourceEditsPath),
      const JsonEncoder.withIndent('  ').convert({'edits': edits}),
    );
  }
}
