// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:build/build.dart';
import 'package:built_collection/built_collection.dart';
import 'package:crypto/crypto.dart';

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
      await readerWriter.writeAsString(
        id,
        applyTo(utf8.decode(bytes), requiredEdits[id]!.edits),
      );
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

  /// Returns [source] with [edits] applied.
  ///
  /// Edits past the end of [source], and edits that overlap one at a higher
  /// offset, are skipped.
  static String applyTo(String source, Iterable<RequiredEdit> edits) {
    // From the end backwards, so offsets stay valid; at one offset, from the
    // last reported, so insertions there end up in the order reported.
    final reported = edits.toList(growable: false);
    final order = List.generate(reported.length, (i) => i, growable: false)
      ..sort((a, b) {
        final byOffset = reported[b].offset.compareTo(reported[a].offset);
        return byOffset != 0 ? byOffset : b.compareTo(a);
      });
    int? lowestOffset;
    for (final index in order) {
      final edit = reported[index];
      final end = edit.offset + edit.length;
      if (end > source.length) continue;
      if (lowestOffset != null && end > lowestOffset) continue;
      source = source.replaceRange(edit.offset, end, edit.replacement);
      lowestOffset = edit.offset;
    }
    return source;
  }
}
