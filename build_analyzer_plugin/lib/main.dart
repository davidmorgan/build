import 'dart:io';

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/pubspec.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_state.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';

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

void _log(String message) {
  File(
    '/tmp/build_analyzer_plugin_log.txt',
  ).writeAsStringSync('$message\n', mode: FileMode.append);
}

class Rule extends MultiAnalysisRule {
  @override
  late final BuildRunnerPubspecVisitor _pubspecVisitor;

  Rule() : super(name: 'rule', description: 'neato rule') {
    _pubspecVisitor = BuildRunnerPubspecVisitor(this);
  }

  @override
  bool get canUseParsedResult => true;

  @override
  List<DiagnosticCode> get diagnosticCodes => const [];

  var count = 0;

  @override
  List<String> get incompatibleRules => const [];

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    _log('registerNodeProcessors');
  }

  @override
  set reporter(DiagnosticReporter value) {
    // _log('set reporter: $value');
  }

  @override
  RuleState get state => const RuleState.experimental();
}

class BuildRunnerPubspecVisitor implements PubspecVisitor<Object> {
  final Rule rule;

  BuildRunnerPubspecVisitor(this.rule);

  @override
  Object? visitPackageAuthor(PubspecEntry author) {
    return null;
  }

  @override
  Object? visitPackageAuthors(PubspecNodeList authors) {
    return null;
  }

  @override
  Object? visitPackageDependencies(PubspecDependencyList dependencies) {
    return null;
  }

  @override
  Object? visitPackageDependency(PubspecDependency dependency) {
    return null;
  }

  @override
  Object? visitPackageDependencyOverride(PubspecDependency dependency) {
    return null;
  }

  @override
  Object? visitPackageDependencyOverrides(PubspecDependencyList dependencies) {
    return null;
  }

  @override
  Object? visitPackageDescription(PubspecEntry description) {
    _log('package description: $description');
    return null;
  }

  @override
  Object? visitPackageDevDependencies(PubspecDependencyList dependencies) {
    return null;
  }

  @override
  Object? visitPackageDevDependency(PubspecDependency dependency) {
    return null;
  }

  @override
  Object? visitPackageDocumentation(PubspecEntry documentation) {
    return null;
  }

  @override
  Object? visitPackageEnvironment(PubspecEnvironment environment) {
    return null;
  }

  @override
  Object? visitPackageHomepage(PubspecEntry homepage) {
    return null;
  }

  @override
  Object? visitPackageIssueTracker(PubspecEntry issueTracker) {
    return null;
  }

  @override
  Object? visitPackageName(PubspecEntry name) {
    return null;
  }

  @override
  Object? visitPackageRepository(PubspecEntry repository) {
    return null;
  }

  @override
  Object? visitPackageVersion(PubspecEntry version) {
    return null;
  }
}
