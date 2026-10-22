// dart format off
part of '../../../../src/build/build_state/required_edit_result.dart';

// === built_value_generator:br_part contribution.
Serializer<RequiredEditResult> _$requiredEditResultSerializer =
    _$RequiredEditResultSerializer();

class _$RequiredEditResultSerializer
    implements StructuredSerializer<RequiredEditResult> {
  @override
  final Iterable<Type> types = const [RequiredEditResult, _$RequiredEditResult];
  @override
  final String wireName = 'RequiredEditResult';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    RequiredEditResult object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'message',
      serializers.serialize(
        object.message,
        specifiedType: const FullType(String),
      ),
      'offset',
      serializers.serialize(object.offset, specifiedType: const FullType(int)),
      'length',
      serializers.serialize(object.length, specifiedType: const FullType(int)),
      'replacement',
      serializers.serialize(
        object.replacement,
        specifiedType: const FullType(String),
      ),
    ];

    return result;
  }

  @override
  RequiredEditResult deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RequiredEditResultBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'message':
          result.message =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'offset':
          result.offset =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'length':
          result.length =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'replacement':
          result.replacement =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
      }
    }

    return result.build();
  }
}

class _$RequiredEditResult extends RequiredEditResult {
  @override
  final String message;
  @override
  final int offset;
  @override
  final int length;
  @override
  final String replacement;

  factory _$RequiredEditResult([
    void Function(RequiredEditResultBuilder)? updates,
  ]) => (RequiredEditResultBuilder()..update(updates))._build();

  _$RequiredEditResult._({
    required this.message,
    required this.offset,
    required this.length,
    required this.replacement,
  }) : super._();
  @override
  RequiredEditResult rebuild(
    void Function(RequiredEditResultBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  RequiredEditResultBuilder toBuilder() =>
      RequiredEditResultBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RequiredEditResult &&
        message == other.message &&
        offset == other.offset &&
        length == other.length &&
        replacement == other.replacement;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, message.hashCode);
    _$hash = $jc(_$hash, offset.hashCode);
    _$hash = $jc(_$hash, length.hashCode);
    _$hash = $jc(_$hash, replacement.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RequiredEditResult')
          ..add('message', message)
          ..add('offset', offset)
          ..add('length', length)
          ..add('replacement', replacement))
        .toString();
  }
}

class RequiredEditResultBuilder
    implements Builder<RequiredEditResult, RequiredEditResultBuilder> {
  _$RequiredEditResult? _$v;

  String? _message;
  String? get message => _$this._message;
  set message(String? message) => _$this._message = message;

  int? _offset;
  int? get offset => _$this._offset;
  set offset(int? offset) => _$this._offset = offset;

  int? _length;
  int? get length => _$this._length;
  set length(int? length) => _$this._length = length;

  String? _replacement;
  String? get replacement => _$this._replacement;
  set replacement(String? replacement) => _$this._replacement = replacement;

  RequiredEditResultBuilder();

  RequiredEditResultBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _message = $v.message;
      _offset = $v.offset;
      _length = $v.length;
      _replacement = $v.replacement;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RequiredEditResult other) {
    _$v = other as _$RequiredEditResult;
  }

  @override
  void update(void Function(RequiredEditResultBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RequiredEditResult build() => _build();

  _$RequiredEditResult _build() {
    final _$result =
        _$v ??
        _$RequiredEditResult._(
          message: BuiltValueNullFieldError.checkNotNull(
            message,
            r'RequiredEditResult',
            'message',
          ),
          offset: BuiltValueNullFieldError.checkNotNull(
            offset,
            r'RequiredEditResult',
            'offset',
          ),
          length: BuiltValueNullFieldError.checkNotNull(
            length,
            r'RequiredEditResult',
            'length',
          ),
          replacement: BuiltValueNullFieldError.checkNotNull(
            replacement,
            r'RequiredEditResult',
            'replacement',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

