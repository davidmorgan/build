// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';
import 'dart:io';

import 'id.dart';
import 'reader.dart';

void LOG(String message) {
  File('/tmp/filesystem.txt')
      .writeAsStringSync('$message\n', mode: FileMode.append);
}

/// State corresponding 1:1 with an underlying filesystem.
abstract interface class Filesystem {
  bool existsSync(AssetId id);
  String readAsStringSync(AssetId id);
}

abstract interface class HasFilesystem {
  Filesystem get filesystem;
}

class FakeFilesystem implements Filesystem {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

abstract interface class HasInputTracker {
  InputTracker get inputTracker;
}

class InputTracker {
  final Set<AssetId> _inputs = {};
  late final Set<AssetId> inputs = UnmodifiableSetView(_inputs);

  final Set<List<AssetId>> _components = Set.identity();
  late final Set<List<AssetId>> components = UnmodifiableSetView(_components);

  void add(AssetId id) {
    _inputs.add(id);
  }

  void addAll(Iterable<List<AssetId>> inputs) {
    _components.addAll(inputs);
  }

  // TODO(davidmorgan): get rid of this method.
  void clear() {
    _inputs.clear();
    _components.clear();
  }
}

extension AssetReaderExtension on AssetReader {
  Filesystem get filesystem {
    if (this is HasFilesystem) {
      return (this as HasFilesystem).filesystem;
    }
    LOG('Does not implement HasFilesystem: $this');
    return FakeFilesystem();
  }

  InputTracker? get inputTracker {
    if (this is HasInputTracker) {
      return (this as HasInputTracker).inputTracker;
    }
    LOG('Does not implement HasInputTracker: $this');
    return null;
  }
}
