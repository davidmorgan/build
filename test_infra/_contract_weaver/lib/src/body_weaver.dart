// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';

import 'body_guard.dart';
import 'clause_emitter.dart';
import 'exit_rewriter.dart';
import 'return_statement_collector.dart';
import 'source_edits.dart';

/// Weaves checks into the body of a function or method.
class BodyWeaver {
  BodyWeaver(this.edits);

  final SourceEdits edits;

  /// Weaves [preconditions], [postconditions] and [guard] into [body].
  void weave(
    FunctionBody body, {
    required String? returnType,
    required bool isVoid,
    required Iterable<String> preconditions,
    required Iterable<String> postconditions,
    required BodyGuard guard,
  }) {
    final exitRewriter = ExitRewriter(
      returnType: returnType,
      isAsync: body.isAsynchronous,
    );
    final entry = _entry(preconditions, guard);
    if (body is ExpressionFunctionBody) {
      _weaveExpressionBody(
        body,
        entry: entry,
        result: _expressionResult(
          isVoid: isVoid,
          isAsync: body.isAsynchronous,
          postconditions: postconditions,
          exitRewriter: exitRewriter,
        ),
        guard: guard,
      );
    } else if (body is BlockFunctionBody) {
      _weaveBlockBody(
        body,
        entry: entry,
        isVoid: isVoid,
        postconditions: postconditions,
        exitRewriter: exitRewriter,
        guard: guard,
      );
    } else {
      throw const FormatException(
        'Cannot weave contracts into a function with no body, such as an '
        'external one.',
      );
    }
  }

  /// The code that runs before the original body.
  ///
  /// Nothing may throw between entering the invariant scope and opening the
  /// guard that leaves it, so preconditions come first.
  String _entry(Iterable<String> preconditions, BodyGuard guard) {
    final buffer = StringBuffer();
    if (preconditions.isNotEmpty) {
      buffer.write(ClauseEmitter.preconditions(preconditions));
    }
    if (guard.checksInvariant) {
      buffer.write(ClauseEmitter.invariantEntry);
    }
    buffer.write(ClauseEmitter.guardOpen(guard));
    return buffer.toString();
  }

  /// The code before and after the expression of `=> expr` that evaluates
  /// it, checks [postconditions] and returns the result.
  ({String before, String after}) _expressionResult({
    required bool isVoid,
    required bool isAsync,
    required Iterable<String> postconditions,
    required ExitRewriter exitRewriter,
  }) {
    final checks = postconditions.isEmpty
        ? ''
        : ClauseEmitter.postconditions(postconditions);
    // In an `async` function, `=> e` waits for `e` if it is a future, so the
    // checks must wait too.
    if (isVoid) return (before: isAsync ? 'await ' : '', after: '; $checks');
    if (postconditions.isEmpty) return (before: 'return ', after: '; ');
    final (:before, :after) = exitRewriter.wrapReturn(checks);
    return (before: before, after: '$after ');
  }

  /// Replaces `=> expr` with a block that runs [entry], then [result].
  void _weaveExpressionBody(
    ExpressionFunctionBody body, {
    required String entry,
    required ({String before, String after}) result,
    required BodyGuard guard,
  }) {
    final startOffset = body.functionDefinition.offset;
    final expression = body.expression;
    edits
      ..replace(
        startOffset,
        expression.offset - startOffset,
        '{ $entry${result.before}',
      )
      ..replace(
        expression.end,
        body.end - expression.end,
        '${result.after}${ClauseEmitter.guardClose(guard)}}',
      );
  }

  /// Inserts [entry] at the start of the block, checks [postconditions]
  /// once the body exits normally, and closes [guard] at the end.
  ///
  /// The checks run after the body's own `try` statements have finished, so
  /// they see the state that `finally` blocks leave and the body cannot catch
  /// a violation.
  void _weaveBlockBody(
    BlockFunctionBody body, {
    required String entry,
    required bool isVoid,
    required Iterable<String> postconditions,
    required ExitRewriter exitRewriter,
    required BodyGuard guard,
  }) {
    final block = body.block;
    final opening = StringBuffer(entry);
    final closing = StringBuffer();
    if (postconditions.isNotEmpty) {
      if (exitRewriter.checksAtReturn) {
        _weaveReturns(block, postconditions, exitRewriter);
      } else {
        final valueType = isVoid ? null : exitRewriter.valueType;
        if (!isVoid) {
          opening.write(
            valueType == null
                ? r'dynamic $result; '
                : '${_nullable(valueType)} \$result; ',
          );
          _recordReturns(block, exitRewriter, valueType);
        }
        opening.write(r'var $threw = false; try { ');
        closing
          ..write(r'} catch (_) { $threw = true; rethrow; } ')
          ..write(r'finally { if (!$threw) { ');
        if (!isVoid) {
          closing.write(
            valueType == null || _nullable(valueType) == valueType
                ? r'final result = $result; '
                : 'final result = \$result as $valueType; ',
          );
        }
        closing
          ..write(ClauseEmitter.postconditions(postconditions))
          ..write('} } ');
      }
    }
    closing.write(ClauseEmitter.guardClose(guard));
    if (opening.isNotEmpty) {
      edits.insert(block.leftBracket.end, ' $opening ');
    }
    if (closing.isNotEmpty) {
      edits.insert(block.rightBracket.offset, ' $closing');
    }
  }

  /// [type] made nullable, unless it already is.
  static String _nullable(String type) {
    final trimmed = type.trim();
    if (trimmed.endsWith('?') || trimmed == 'dynamic' || trimmed == 'Null') {
      return trimmed;
    }
    return '$trimmed?';
  }

  /// Rewrites each `return e;` in [block] to record the value it returns in
  /// `$result`.
  void _recordReturns(
    Block block,
    ExitRewriter exitRewriter,
    String? valueType,
  ) {
    for (final statement in ReturnStatementCollector.collect(block)) {
      final expr = statement.expression;
      if (expr == null) continue;
      final String before;
      final String after;
      if (exitRewriter.isAsync) {
        // An `async` function waits for a returned future; record the value.
        final constructor = valueType == null
            ? 'Future.value'
            : 'Future<$valueType>.value';
        before = 'return \$result = await $constructor(';
        after = ');';
      } else {
        before = r'return $result = ';
        after = ';';
      }
      edits
        ..replace(statement.offset, expr.offset - statement.offset, before)
        ..replace(expr.end, statement.end - expr.end, after);
    }
  }

  /// Rewrites each `return` in [block] to check [postconditions] first.
  void _weaveReturns(
    Block block,
    Iterable<String> postconditions,
    ExitRewriter exitRewriter,
  ) {
    for (final statement in ReturnStatementCollector.collect(block)) {
      final expr = statement.expression;
      if (expr != null) {
        final (:before, :after) = exitRewriter.wrapReturn(
          ClauseEmitter.postconditions(postconditions),
        );
        edits
          ..replace(statement.offset, expr.offset - statement.offset, before)
          ..replace(expr.end, statement.end - expr.end, after);
      } else {
        final buffer = StringBuffer('{ ')
          ..write(ClauseEmitter.postconditions(postconditions))
          ..write('return; ')
          ..write('}');
        edits.replace(statement.offset, statement.length, buffer.toString());
      }
    }
  }
}
