// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

import 'member_contract.dart';
import 'old_call_finder.dart';

/// The values captured on entry for the `old(e)` calls in one member's
/// postconditions.
///
/// As in Cofoja, `old(e)` in an `@Ensures` or `@ThrowEnsures` clause is the
/// value of `e` on entry. Each distinct `e` is captured once, after the
/// preconditions, into `$old0`, `$old1` and so on; each call in a clause is
/// rewritten to read the capture.
///
/// The capture is a reference: `old(_items)` is the same list as `_items`.
/// If evaluating `e` throws, the exception is kept and thrown only when a
/// clause reads the value, also as in Cofoja.
class OldValues {
  const OldValues._(this._indices);

  /// No captures, for a member that does not use `old`.
  static const none = OldValues._({});

  /// The source of each captured expression, mapped to its capture index.
  final Map<String, int> _indices;

  /// The part of the source that [_parse] adds before a clause.
  static const _prefix = 'final x = ';

  /// The captures for the postconditions of [contract].
  ///
  /// Throws [FormatException] if a call to `old` is malformed.
  factory OldValues.of(MemberContract contract) {
    final indices = <String, int>{};
    final clauses = [
      ...contract.postconditions,
      for (final throwClauses in contract.throwClauses) ...throwClauses.clauses,
    ];
    for (final clause in clauses) {
      for (final call in _calls(clause)) {
        indices.putIfAbsent(_expression(call), () => indices.length);
      }
    }
    return OldValues._(indices);
  }

  /// Throws [FormatException] if any of [clauses] calls `old`.
  ///
  /// [where] says where `old` was found, for the message.
  static void reject(Iterable<String> clauses, String where) {
    for (final clause in clauses) {
      if (_calls(clause).isNotEmpty) {
        throw FormatException('old(...) cannot be used in $where: $clause');
      }
    }
  }

  /// Whether nothing is captured.
  bool get isEmpty => _indices.isEmpty;

  /// The statements that capture the values on entry.
  String get declarations {
    final buffer = StringBuffer();
    for (final entry in _indices.entries) {
      buffer.writeln(
        'final \$old${entry.value} = OldValue.capture(() => ${entry.key});',
      );
    }
    return buffer.toString();
  }

  /// [clause] with each call to `old` replaced by a read of its capture.
  String rewrite(String clause) {
    if (isEmpty) return clause;
    var rewritten = clause;
    for (final call in _calls(clause).reversed) {
      rewritten = rewritten.replaceRange(
        call.offset - _prefix.length,
        call.end - _prefix.length,
        '\$old${_indices[_expression(call)]}.value',
      );
    }
    return rewritten;
  }

  /// The calls to `old` in [clause].
  static List<MethodInvocation> _calls(String clause) {
    if (!clause.contains('old')) return const [];
    final expression = _parse(clause);
    if (expression == null) return const [];
    return OldCallFinder.find(expression);
  }

  /// The source of the expression that [call] captures.
  static String _expression(MethodInvocation call) =>
      call.argumentList.arguments.single.toSource();

  /// [clause] parsed as an expression, or `null` if it does not parse.
  ///
  /// A clause that does not parse is left for analysis of the woven output to
  /// report.
  static Expression? _parse(String clause) {
    final unit = parseString(
      content: '$_prefix$clause;',
      throwIfDiagnostics: false,
    ).unit;
    final declaration = unit.declarations.singleOrNull;
    if (declaration is! TopLevelVariableDeclaration) return null;
    return declaration.variables.variables.single.initializer;
  }
}
