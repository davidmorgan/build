// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Moves the statements of an `async` block body into a local function
/// `$body`, so that checks can run after the future it returns completes.
///
/// `return e;` inside the local function keeps its meaning: an error from a
/// returned future escapes the body's own `catch`, and its `finally` runs
/// before the future completes.
///
/// A parameter that the body assigns is captured by a closure, and Dart does
/// not promote such a variable. So `$body` takes each assigned parameter with
/// a written type as a parameter of its own. Once the future completes, the
/// caller copies back the final value for postconditions to see. A parameter
/// with no written type may have one inferred from an override, so it stays
/// captured rather than become `dynamic`.
class AsyncBodyExtractor {
  AsyncBodyExtractor(BlockFunctionBody body, {required String? returnType})
    : _returnType = returnType,
      _assigned = _assignedParameters(body);

  final String? _returnType;
  final List<({String name, String type})> _assigned;

  /// The code that opens `$body`, inserted before the original statements.
  String get header {
    final buffer = StringBuffer();
    for (final (:name, :type) in _assigned) {
      buffer.write('late $type Function() \$read\$$name; ');
    }
    final returnType = switch (_returnType) {
      null => '',
      'void' => 'Future<void> ',
      final type => '$type ',
    };
    final parameters = [
      for (final (:name, :type) in _assigned) '$type $name',
    ].join(', ');
    buffer.write('$returnType\$body($parameters) async { ');
    for (final (:name, type: _) in _assigned) {
      buffer.write('\$read\$$name = () => $name; ');
    }
    return buffer.toString();
  }

  /// The code that closes `$body`, inserted after the original statements.
  String get footer => '} ';

  /// The call to `$body`.
  String get call =>
      '\$body(${[for (final (:name, type: _) in _assigned) name].join(', ')})';

  /// Copies the final values of assigned parameters back, once the future
  /// returned by [call] completes.
  String get copyBack => [
    for (final (:name, type: _) in _assigned) '$name = \$read\$$name(); ',
  ].join();

  static List<({String name, String type})> _assignedParameters(
    BlockFunctionBody body,
  ) {
    final parameters = switch (body.parent) {
      MethodDeclaration(:final parameters) => parameters,
      FunctionExpression(:final parameters) => parameters,
      _ => null,
    };
    if (parameters == null) return const [];
    final visitor = _AssignedNames();
    body.block.accept(visitor);
    final result = <({String name, String type})>[];
    for (final parameter in parameters.parameters) {
      final name = parameter.name?.lexeme;
      if (name == null || !visitor.names.contains(name)) continue;
      final type = parameter.type;
      if (parameter is! RegularFormalParameter ||
          parameter.functionTypedSuffix != null ||
          type == null) {
        continue;
      }
      result.add((name: name, type: type.toSource()));
    }
    return result;
  }
}

/// Collects the names of simple identifiers that are assigned.
class _AssignedNames extends RecursiveAstVisitor<void> {
  final Set<String> names = {};

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    _add(node.leftHandSide);
    super.visitAssignmentExpression(node);
  }

  @override
  void visitAssignedVariablePattern(AssignedVariablePattern node) {
    names.add(node.name.lexeme);
    super.visitAssignedVariablePattern(node);
  }

  @override
  void visitForEachPartsWithIdentifier(ForEachPartsWithIdentifier node) {
    names.add(node.identifier.name);
    super.visitForEachPartsWithIdentifier(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    if (_isIncrementOrDecrement(node.operator)) _add(node.operand);
    super.visitPostfixExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    if (_isIncrementOrDecrement(node.operator)) _add(node.operand);
    super.visitPrefixExpression(node);
  }

  void _add(Expression target) {
    if (target is SimpleIdentifier) names.add(target.name);
  }

  static bool _isIncrementOrDecrement(Token operator) =>
      operator.type == TokenType.PLUS_PLUS ||
      operator.type == TokenType.MINUS_MINUS;
}
