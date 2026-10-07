// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:_contract_weaver/contract_weaver.dart';
import 'package:_contract_weaver/src/member_contract.dart';
import 'package:_contract_weaver/src/old_values.dart';
import 'package:_contract_weaver/src/throw_clauses.dart';
import 'package:test/test.dart';

void main() {
  group('OldValues', () {
    MemberContract contract(
      List<String> postconditions, [
      List<String> throwClauses = const [],
    ]) => MemberContract(
      (b) => b
        ..postconditions.replace(postconditions)
        ..throwClauses.replace([
          if (throwClauses.isNotEmpty)
            ThrowClauses.of(type: 'StateError', clauses: throwClauses),
        ]),
    );

    test('is empty when no clause calls old', () {
      expect(OldValues.of(contract(['result > 0', 'older'])).isEmpty, isTrue);
    });

    test('captures each distinct expression once', () {
      final old = OldValues.of(
        contract(
          ['count == old(count) + 1', 'old(count) >= 0'],
          ['old(items.length) == items.length'],
        ),
      );
      expect(
        old.declarations,
        'final \$old0 = OldValue.capture(() => count);\n'
        'final \$old1 = OldValue.capture(() => items.length);\n',
      );
    });

    test('rewrites calls to read the captures', () {
      final old = OldValues.of(contract(['a == old(a) + old(b.c)']));
      expect(
        old.rewrite('a == old(a) + old(b.c)'),
        'a == \$old0.value + \$old1.value',
      );
      expect(old.rewrite('!old(b.c)'), '!\$old1.value');
    });

    test('leaves this.old alone', () {
      expect(OldValues.of(contract(['this.old(1) == 1'])).isEmpty, isTrue);
    });

    test('allows member names result and signal', () {
      final old = OldValues.of(contract(['old(this.result) == x.signal']));
      expect(old.rewrite('old(this.result) == 1'), '\$old0.value == 1');
    });

    for (final clause in [
      'old(old(x)) == 1',
      'old(result) == 1',
      'old(signal) == 1',
      'old(x, y) == 1',
      'old() == 1',
      'old(a: x) == 1',
    ]) {
      test('rejects $clause', () {
        expect(() => OldValues.of(contract([clause])), throwsFormatException);
      });
    }

    test('reject throws only if a clause calls old', () {
      OldValues.reject(['x > 0', 'this.old(x)'], '@Requires');
      expect(
        () => OldValues.reject(['old(x) > 0'], '@Requires'),
        throwsFormatException,
      );
    });
  });

  group('ContractWeaver with old', () {
    const annotations = '''
class Requires {
  final String clause;
  const Requires(this.clause);
}

class Ensures {
  final String clause;
  const Ensures(this.clause);
}

class ThrowEnsures {
  final Type type;
  final String clause;
  const ThrowEnsures(this.type, this.clause);
}

class Invariant {
  final String clause;
  const Invariant(this.clause);
}
''';

    for (final (name, source) in [
      ('@Requires', "@Requires('old(x) > 0') void f(int x) {}"),
      (
        '@Invariant',
        "@Invariant('x >= old(x)') class C { int x = 0; void f() {} }",
      ),
      (
        'a constructor',
        "class C { int x; @Ensures('x == old(x)') C(this.x); }",
      ),
      ('a parameter named old', "@Ensures('old(old) == 1') void f(int old) {}"),
    ]) {
      test('throws FormatException for old in $name', () {
        expect(
          () => ContractWeaver().weave('$annotations\n$source\n'),
          throwsFormatException,
        );
      });
    }

    test('checks old values at runtime', () async {
      final tempDir = await Directory.systemTemp.createTemp('contracts_old_');
      try {
        final script = File('${tempDir.path}/old_runner.dart');
        const source =
            '''
$annotations

class Counter {
  int count = 0;
  final List<int> items = [];

  @Ensures('count == old(count) + delta')
  void add(int delta) {
    count += delta;
  }

  @Ensures('count == old(count) + delta')
  void addWrong(int delta) {
    count += delta + 1;
  }

  @Ensures('result == old(count)')
  Future<int> addLater(int delta) async {
    final before = count;
    await Future<void>.delayed(Duration.zero);
    count += delta;
    return before;
  }

  @ThrowEnsures(StateError, 'count == old(count)')
  void failAfterChanging() {
    count++;
    throw StateError('failed');
  }

  @Ensures('old(items.isEmpty) || old(items.last) <= items.last')
  void push(int x) {
    items.add(x);
  }

  @Ensures('old(items.last) <= items.last')
  void pushReadingLast(int x) {
    items.add(x);
  }
}

Future<void> main() async {
  final c = Counter();
  c.add(2);

  try {
    c.addWrong(1);
    throw 'addWrong should have thrown';
  } on ContractViolation catch (e) {
    if (!e.message.contains('old(count)')) throw 'message: \${e.message}';
  }

  if (await c.addLater(3) != 4) throw 'addLater returned the wrong value';

  try {
    c.failAfterChanging();
    throw 'failAfterChanging should have thrown';
  } on ContractViolation {
    // Expected.
  }

  // The capture of items.last throws on an empty list, but the clause does
  // not read it.
  c.push(1);
  c.push(2);

  // Here the clause does read it, so the capture's exception is thrown.
  c.items.clear();
  try {
    c.pushReadingLast(1);
    throw 'pushReadingLast should have thrown';
  } on StateError {
    // Expected.
  }
}
''';
        await script.writeAsString(ContractWeaver().weave(source));
        final result = await Process.run(Platform.resolvedExecutable, [
          script.path,
        ]);
        expect(
          result.exitCode,
          0,
          reason: 'stderr: ${result.stderr}\nstdout: ${result.stdout}',
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
