import 'dart:io';

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_state.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

final plugin = SimplePlugin();

class SimplePlugin extends Plugin {
  @override
  String get name => 'build_analyzer_plugin';

  @override
  void register(PluginRegistry registry) {
    // Register diagnostics, quick fixes, and assists.

    registry.registerWarningRule(Rule());
  }
}

const _diagnosticCode = LintCode('test_code', 'do not await String');

void _log(String message) {
  File(
    '/tmp/build_analyzer_plugin_log.txt',
  ).writeAsStringSync('$message\n', mode: FileMode.append);
}

class Rule extends MultiAnalysisRule {
  Rule() : super(name: 'rule', description: 'neato rule');

  @override
  bool get canUseParsedResult => true;

  @override
  List<DiagnosticCode> get diagnosticCodes => const [_diagnosticCode];

  @override
  List<String> get incompatibleRules => const [];

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    _log('registerNodeProcessors');
    final visitor = _Visitor(this);
    registry.addAwaitExpression(this, visitor);
  }

  @override
  RuleState get state => const RuleState.experimental();
}

class _Visitor extends SimpleAstVisitor<void> {
  final Rule rule;

  _Visitor(this.rule);

  @override
  void visitAwaitExpression(AwaitExpression node) {
    if (node.expression.staticType?.isDartCoreString == true) {
      rule.reportAtToken(node.awaitKeyword, diagnosticCode: _diagnosticCode);
    }
  }
}
