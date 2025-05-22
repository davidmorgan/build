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

