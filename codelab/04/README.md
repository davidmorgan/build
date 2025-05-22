# Builder Codelab

[Go back to the main page](../README.md).

## 04 Equality Part Builder

Now it's time for a builder that does something useful.

Launch "watch" mode:

```bash
cd 04/end_to_end_test
dart run build_runner watch -d
```

The builder is already wired up to look for the classes with the `@equality` annotation and output a part file with the suffix `.equality.dart`. So, the file `end_to_end_test/lib/value.dart`

```dart
import 'package:codelab_annotations/codelab_annotations.dart';

part 'value.equality.dart';

@equality
class Value {
  int x;
  int y;

  Value(this.x, this.y);

  @override
  String toString() => 'Value($x, $y)';
}
```

gets its part file generated

```
part of 'value.dart';
// TODO: generate for Value
```

which, as you can see, does nothing.

There is a test that checks whether `Value` has value equality; currently it doesn't, so the test fails:

```
dart test
00:00 +0 -1: test/value_test.dart: Value has value equality [E] 
  Expected: Value:<Value(1, 2)>
    Actual: Value:<Value(1, 2)>
```

To fix it, you'll need to update this part of `codelab_builders/lib/resolving_builder.dart`:

```dart
    for (final classElement in classElements) {
      buffer.writeln('// TODO: generate for ${classElement.displayName}');
    }
```

But—update it to what? How can a part file supply the `==` implementation?

Until the augmentation language feature arrives, there are a few answers but all are more work than you want. For this codelab, you'll use a mixin. Update `end_to_end_test/lib/value.dart` to reference the mixin you're going to generate:

```dart
class Value with _$Value {
```

and change the TODO generation in `` into a mixin:
and change the TODO generation in `codelab_builders/lib/equality_builder.dart` into a mixin:

```dart
    for (final classElement in classElements) {
      buffer.writeln('mixin _\$${classElement.displayName} {');
      buffer.writeln('}');
    }
```

The `_` in the mixin name `_$Value` makes the declaration private; the `$` has no special effect, it is a convention commonly used for generated symbols to distinguish them from hand-written code.

Now, the builder can start adding implementation to `Value`. It can add `operator==`:

```dart
    for (final classElement in classElements) {
      buffer.writeln('mixin _\$${classElement.displayName} {');
      buffer.writeln('bool operator== (other) {');
      buffer.writeln('  return true;');
      buffer.writeln('}');
      buffer.writeln('}');
    }
```

This implementation is sufficient to make that one test case pass, but it makes the other test case fail! You'll need something that actually checks the fields. The mixin will have to declare getters for the fields so it can access them:

```dart
    for (final classElement in classElements) {
      for (final field in fields) {
        buffer.writeln('get ${field.name};');
      }

      buffer.writeln('bool operator== (other) {');
      buffer.writeln(
        'if (other is! ${classElement.displayName}) return false;',
      );

      if (fields.isEmpty) {
        buffer.writeln('return true;');
      } else {
        buffer.write('return');
        buffer.write(
          fields.map((f) => '(other.${f.name} == ${f.name})').join(' && '),
        );
        buffer.writeln(';');
      }

      buffer.writeln('}');
      buffer.writeln('}');
    }
```

That works! At least, it's enough to pass the test:

```
dart test
00:00 +1: All tests passed!
```

But, it's unlikely to be satisfactory. The fields in `Value` count as overrides of the getters in the mixin, which means that a lint fires: they should be marked with `@override`, which seems a surprising thing to ask your users to do.

How could this be fixed?

Here are two different approaches actually used today.

The `freezed` generator creates a mixin that also declares the fields for you. The list of fields, rather than being something you write, is inferred from your constructor parameters.

Or, you could use the approach taken by the `built_value` generator: write `Value` as an abstract class with getters instead of fields. Then `_$Value extends Value`, with a concrete constructor. Finally, `Value` gains a factory constructor that returns the generated class.

Can you implement one of these, so that the checked-in code looks good and the test passes?

