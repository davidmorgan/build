// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bv1.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$Value extends Value {
  @override
  final int b;

  factory _$Value([void Function(ValueBuilder)? updates]) =>
      (new ValueBuilder()..update(updates))._build();

  _$Value._({required this.b}) : super._() {
    BuiltValueNullFieldError.checkNotNull(b, r'Value', 'b');
  }

  @override
  Value rebuild(void Function(ValueBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ValueBuilder toBuilder() => new ValueBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Value && b == other.b;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, b.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Value')..add('b', b)).toString();
  }
}

class ValueBuilder implements Builder<Value, ValueBuilder> {
  _$Value? _$v;

  int? _b;
  int? get b => _$this._b;
  set b(int? b) => _$this._b = b;

  ValueBuilder();

  ValueBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _b = $v.b;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Value other) {
    ArgumentError.checkNotNull(other, 'other');
    _$v = other as _$Value;
  }

  @override
  void update(void Function(ValueBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Value build() => _build();

  _$Value _build() {
    final _$result = _$v ??
        new _$Value._(
          b: BuiltValueNullFieldError.checkNotNull(b, r'Value', 'b'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
