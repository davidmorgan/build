// ignore_for_file: unused_import
import 'package:built_value/built_value.dart';

import 'app.dart';

part 'bv1.g.dart';

// CACHE_BUSTER941179130229

abstract class Value implements Built<Value, ValueBuilder> {
  Value._();
  factory Value(void Function(ValueBuilder) updates) = _$Value;
}
