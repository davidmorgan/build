library;

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:built_value/built_value.dart';
import 'dart_types.dart';
import 'metadata.dart' show metadataToStringValue;

part 'memoized_getter.g.dart';

abstract class MemoizedGetter
    implements Built<MemoizedGetter, MemoizedGetterBuilder> {
  String get returnType;
  NullabilitySuffix get nullabilitySuffix;
  String get name;

  factory MemoizedGetter([void Function(MemoizedGetterBuilder) updates]) =
      _$MemoizedGetter;
  MemoizedGetter._();

  bool get isNullable => nullabilitySuffix == NullabilitySuffix.question;

  static Iterable<MemoizedGetter> fromClassElement(
    InterfaceElement classElement,
    ParsedLibraryResult parsedLibrary,
  ) {
    return classElement.fields
        .where(
          (field) =>
              field.getter != null &&
              !field.getter!.isAbstract &&
              field.getter!.metadata.annotations.any(
                (metadata) => metadataToStringValue(metadata) == 'memoized',
              ),
        )
        .map(
          (field) => MemoizedGetter(
            (b) => b
              ..returnType = _returnType(field.getter!, parsedLibrary)
              ..nullabilitySuffix = field.getter!.returnType.nullabilitySuffix
              ..name = field.displayName,
          ),
        )
        .toList();
  }

  /// The return type of [getter] without any nullability suffix, keeping any
  /// import prefix written in the source.
  static String _returnType(
    GetterElement getter,
    ParsedLibraryResult parsedLibrary,
  ) {
    final typeFromElement = DartTypes.getName(getter.returnType);
    final declaration =
        parsedLibrary.getFragmentDeclaration(getter.firstFragment)?.node;
    if (declaration is! MethodDeclaration) return typeFromElement;
    var typeFromAst = declaration.returnType?.toSource();
    if (typeFromAst == null) return typeFromElement;
    if (typeFromAst.endsWith('?')) {
      typeFromAst = typeFromAst.substring(0, typeFromAst.length - 1);
    }

    // Function types are formatted incorrectly by the element. Otherwise
    // prefer the element unless the source has an import prefix, because the
    // element handles inherited generics correctly.
    if (typeFromElement.contains('(')) return typeFromAst;
    if (!typeFromAst.contains('.')) return typeFromElement;
    return typeFromAst;
  }
}
