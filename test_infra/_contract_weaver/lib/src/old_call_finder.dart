// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Finds the calls to `old` in a contract clause.
///
/// A call to `old` is an invocation with no target, so `this.old(x)` calls a
/// member named `old`.
class OldCallFinder extends RecursiveAstVisitor<void> {
  OldCallFinder._();

  final List<MethodInvocation> _calls = [];
  bool _insideOld = false;

  /// The calls to `old` in [expression], in source order.
  ///
  /// Throws [FormatException] if a call does not have exactly one positional
  /// argument, is nested inside another, or reads `result` or `signal`, which
  /// have no value on entry.
  static List<MethodInvocation> find(Expression expression) {
    final finder = OldCallFinder._();
    expression.accept(finder);
    return finder._calls..sort((a, b) => a.offset.compareTo(b.offset));
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target != null || node.methodName.name != 'old') {
      super.visitMethodInvocation(node);
      return;
    }
    if (_insideOld) {
      throw const FormatException('old(...) cannot be nested.');
    }
    final arguments = node.argumentList.arguments;
    if (node.typeArguments != null ||
        arguments.length != 1 ||
        arguments.single is NamedArgument) {
      throw FormatException(
        'old(...) takes exactly one expression, got: ${node.toSource()}',
      );
    }
    _calls.add(node);
    _insideOld = true;
    arguments.single.accept(this);
    _insideOld = false;
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (!_insideOld) return;
    final name = node.name;
    if ((name == 'result' || name == 'signal') && !_isMemberName(node)) {
      throw FormatException(
        'old(...) cannot read "$name", which has no value on entry.',
      );
    }
  }

  /// Whether [node] names a member of an explicit target, such as `result`
  /// in `this.result`, rather than a variable in scope.
  static bool _isMemberName(SimpleIdentifier node) {
    final parent = node.parent;
    if (parent is PropertyAccess) return parent.propertyName == node;
    if (parent is PrefixedIdentifier) return parent.identifier == node;
    if (parent is MethodInvocation) {
      return parent.methodName == node && parent.target != null;
    }
    return parent is Label;
  }
}
