// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

import '../../contracts.dart';

part '../../../_br_/src/build/build_state/required_edit_result.part.dart';

/// A `RequiredEdit` reported by a build step, kept so that a reused failed
/// step reports it again.
@Invariant('offset >= 0')
@Invariant('length >= 0')
abstract class RequiredEditResult
    implements Built<RequiredEditResult, RequiredEditResultBuilder> {
  static Serializer<RequiredEditResult> get serializer =>
      _$requiredEditResultSerializer;

  String get message;
  int get offset;
  int get length;
  String get replacement;

  factory RequiredEditResult({
    required String message,
    required int offset,
    required int length,
    required String replacement,
  }) = _$RequiredEditResult._;
  RequiredEditResult._();
}
