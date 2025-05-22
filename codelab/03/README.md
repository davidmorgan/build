# Builder Codelab

[Go back to the main page](../README.md).

## 03 Resolving Builder

In the previous part, `many_files_builder` used a string match on `@count` to decide whether to run on any particular `.dart` file.

In this part, you'll resolve the source file so that the check can be correct.

The builder has been renamed `resolving_builder`, but it still just does the string match. Launch the build in `watch` mode

```bash
cd 03/end_to_end_test
dart run build_runner watch -d
```

and observe that two `.count` files are created. First, correctly, for `count_me.dart` which uses the annotation; then, incorrectly for `do_not_count_me.dart` which has the annotation commented out:

```dart
// @count
```

To correctly distinguish whether `@count` is commented out, you'll first _parse_ the source.

Update `lib/src/resolving_builder.dart`

```
  @override
  Future<void> build(BuildStep buildStep) async {
    final parsedContent = await buildStep.resolver.compilationUnitFor(
      buildStep.inputId,
    );
```

then explore a little what your IDE offers for the API of `parsedContent`.

Suddenly, the whole AST API of the Dart Analyzer is available! You have the same power to handle Dart source code as any of the Dart tooling. This can be overwhelming; it's useful to look at existing builders for examples.

Here's one way to check for the annotation:

```dart
    var found = false;
    for (final directive in parsedContent.directives) {
      for (final metadata in directive.metadata) {
        if (metadata.toString() == '@count') {
          found = true;
        }
      }
    }
    if (!found) return;
```

Update the source to this, and you'll find `do_not_count_me.count` disappears, because the `@const` in the comment no longer triggers generation.

This is now a _syntax level_ check: the file is parsed, so `@count` must really be an annotation and not a comment or a string. But, it's still just a string match on the annotation name. Checking whether the annotation corresponds to the exact one declared in `package:codelab_annotations` requires that the source be fully _resolved_.

To show this, first change `do_not_count_me.dart` to

```dart
@count
library;

const String count = 'count';
```

and notice that `do_not_count_me.count` reappears: the source now _is_ using an annotation named `count`, it's just the _wrong one_.

To do resolution instead of parsing, update the builder

```dart
  @override
  Future<void> build(BuildStep buildStep) async {
    final resolvedContent = await buildStep.resolver.libraryFor(
      buildStep.inputId,
    );
```

and now you have access to a different, even richer API via `resolvedContent`. This is the analyzer's "element model", with all information resolved including reading from transitively imported sources as needed.

Here's one way to check the annotation now:

```dart
    var found = false;
    for (final metadata in resolvedContent.metadata) {
      if (metadata.element?.library?.source.uri.toString() ==
          'package:codelab_annotations/codelab_annotations.dart') {
        if (metadata.computeConstantValue()?.toStringValue() == 'count') {
          found = true;
        }
      }
    }
    if (!found) return;
```

And, this is finally correct: `do_not_count_me.count` disappears, because the annotation is not the one from `package:codelab_annotations`.
