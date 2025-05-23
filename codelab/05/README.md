# Builder Codelab

[Go back to the main page](../README.md).

## 05 Many Builders

In this codelab part you'll use more than one builder in combination, to learn how they interact.

### Optional Builders

An optional builder is a builder that offers to produce output, but does not actually run unless a non-optional builder reads it.

So, an optional builder is appropriate for doing work "behind the scenes" that the user does not directly care about. The work only gets done if something the user _does_ care about depends on it.

The first builder in this codelab is `format_builder`, which will be an optional builder that consumes `.dart` files and outputs `.formatted` files.

The code to run `dart_style` in a builder is already written for you in `codelab_builders/lib/format_builder.dart`:

```dart
  @override
  Future<void> build(BuildStep buildStep) async {
    final content = await buildStep.readAsString(buildStep.inputId);

    final formattedContent = DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    ).format(content);

    if (content != formattedContent) {
      await buildStep.writeAsString(
        buildStep.inputId.changeExtension('.formatted'),
        formattedContent,
      );
    }
  }
```

Launch "watch" mode:

```bash
cd 05/end_to_end_test
dart run build_runner watch -d
```

Then check `lib/my_source.dart` and notice that `lib/my_source.formatted` has appeared next to it. As you edit `lib/my_source.dart`, the `.formatted` file will appear or disappear depending on whether formatting is needed.

The reason you can see the output is that it's output "to source", rather than hidden; and the reason it's written at all is that the builder is currently _not_ marked optional. Fix both those by updating the `format_builder` part of `codelab_builders/build.yaml`:

```
  format_builder:
    import: "package:codelab_builders/builders.dart"
    builder_factories: ["formatBuilder"]
    build_extensions: {".dart": [".formatted"]}
    build_to: cache
    is_optional: true
    auto_apply: dependents
```