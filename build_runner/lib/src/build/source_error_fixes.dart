// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:build/build.dart';
import 'package:built_collection/built_collection.dart';
import 'package:crypto/crypto.dart';

import '../io/reader_writer.dart';
import '../logging/build_log.dart';
import 'error_fix.dart';

/// The errors with fixes builders reported for one source, and the md5
/// [digest] of the source content they were reported for.
class SourceErrorFixes {
  final Digest digest;
  final BuiltList<ErrorFix> fixes;

  SourceErrorFixes(this.digest, this.fixes);

  /// Applies [fixes] to their sources and reports them, or with [onlyCheck]
  /// only reports them.
  ///
  /// As for `part` directives, a source that changed since the build read it
  /// is not edited, and the next build decides again. Fixes that overlap an
  /// earlier one in the same source are left for the next build.
  static Future<void> apply(
    BuiltMap<AssetId, SourceErrorFixes> fixes,
    ReaderWriter readerWriter, {
    required bool onlyCheck,
  }) async {
    String lines(Iterable<AssetId> ids) => [
      for (final id in ids)
        for (final fix in fixes[id]!.fixes)
          '${buildLog.renderId(id)}: ${fix.message}',
    ].join('\n');

    final ids = fixes.keys.toList()..sort((a, b) => '$a'.compareTo('$b'));
    if (onlyCheck) {
      buildLog.error('Fix errors in sources:\n\n${lines(ids)}');
      return;
    }
    final fixedIds = <AssetId>[];
    final changedDuringBuildIds = <AssetId>[];
    for (final id in ids) {
      final bytes = await readerWriter.readAsBytes(id);
      if (md5.convert(bytes) != fixes[id]!.digest) {
        changedDuringBuildIds.add(id);
        continue;
      }
      var source = utf8.decode(bytes);
      final edits = [for (final fix in fixes[id]!.fixes) fix.edit]
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
      fixedIds.add(id);
    }
    if (fixedIds.isNotEmpty) {
      buildLog.error('Fixed errors in sources:\n\n${lines(fixedIds)}');
    }
    if (changedDuringBuildIds.isNotEmpty) {
      buildLog.error(
        'Not fixing errors in sources that changed during the build:\n\n'
        '${changedDuringBuildIds.map(buildLog.renderId).join('\n')}',
      );
    }
  }
}
