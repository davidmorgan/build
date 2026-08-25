// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:built_value/serializer.dart';
import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

/// Asset data and digests.
///
/// On serialization the content is dropped leaving only the digest.
class AssetData {
  List<int>? _bytes;
  final String? _string;
  final Encoding? _encoding;
  Digest? _digest;

  AssetData.bytes(List<int> bytes, {Digest? digest})
    : _bytes = bytes,
      _string = null,
      _encoding = null,
      _digest = digest;

  AssetData.string(String string, {Encoding encoding = utf8, Digest? digest})
    : _bytes = null,
      _string = string,
      _encoding = encoding,
      _digest = digest;

  // Only test instances and deserialized instances can be created without
  // content; visibleForTesting allows calls from the same file, which allows
  // calls from the serializer below.
  @visibleForTesting
  AssetData.digest(Digest digest)
    : _bytes = null,
      _string = null,
      _encoding = null,
      _digest = digest;

  bool get hasContent => _bytes != null || _string != null;

  List<int> get bytes {
    if (!hasContent) {
      throw StateError('AssetData has no content, only digest.');
    }
    return _bytes ??= _encoding!.encode(_string!);
  }

  String stringValue({Encoding encoding = utf8}) {
    if (!hasContent) {
      throw StateError('AssetData has no content, only digest.');
    }
    if (_string != null && _encoding == encoding) return _string;
    return encoding.decode(bytes);
  }

  /// Returns a copy with [newBytes].
  ///
  /// If this instance has a digest, it is copied without checking that
  /// [newBytes] matches the digest. This supports the current build_runner
  /// behavior that manual changes to output content are ignored, see
  /// https://github.com/dart-lang/build/issues/4985.
  AssetContent withBytes(List<int> newBytes) {
    if (_bytes == newBytes) return AssetContent._(this);
    final result = AssetData.bytes(newBytes);
    if (_digest != null) result._digest = _digest;
    return AssetContent._(result);
  }

  Digest get digest => _digest ??= md5.convert(bytes);
}

/// Asset content guaranteed to have bytes or string in memory.
extension type AssetContent._(AssetData _data) implements AssetData {
  AssetContent.bytes(List<int> bytes, {Digest? digest})
    : _data = AssetData.bytes(bytes, digest: digest);

  AssetContent.string(String string, {Encoding encoding = utf8, Digest? digest})
    : _data = AssetData.string(string, encoding: encoding, digest: digest);

  /// Creates an [AssetContent] from [data].
  ///
  /// Throws [StateError] if [data] does not have content.
  static AssetContent fromData(AssetData data) {
    if (!data.hasContent) {
      throw StateError('AssetData has no content.');
    }
    return AssetContent._(data);
  }

  /// Creates an [AssetContent] from [data] if content is present, otherwise
  /// null.
  static AssetContent? fromDataOrNull(AssetData? data) {
    if (data == null || !data.hasContent) return null;
    return AssetContent._(data);
  }
}

class AssetDataSerializer implements PrimitiveSerializer<AssetData> {
  @override
  Iterable<Type> get types => [AssetData];

  @override
  String get wireName => 'AssetData';

  @override
  AssetData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AssetData.digest(
    serializers.deserialize(serialized, specifiedType: const FullType(Digest))
        as Digest,
  );

  @override
  Object serialize(
    Serializers serializers,
    AssetData object, {
    FullType specifiedType = FullType.unspecified,
  }) => serializers.serialize(
    object.digest,
    specifiedType: const FullType(Digest),
  )!;
}
