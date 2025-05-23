# Builder Codelab

If you haven't already, follow "Setup" on [the main page](../README.md).

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

Then check `end_to_end_test/lib/my_source.dart` and notice that `my_source.formatted` has appeared next to it. As you edit `lib/my_source.dart`, the `.formatted` file will appear or disappear depending on whether formatting is needed.

The reason you can see the output is that it's output "to source", rather than hidden; and the reason it's written at all is that the builder is currently _not_ marked optional. Fix both those by updating the `format_builder` part of `codelab_builders/build.yaml`:

```yaml
  format_builder:
    import: "package:codelab_builders/builders.dart"
    builder_factories: ["formatBuilder"]
    build_extensions: {".dart": [".formatted"]}
    build_to: cache
    is_optional: true
    auto_apply: dependents
```

Now, it does nothing, because no other builder currently reads the `.formatted` files.

The second builder, `actions_builder`, will look for outputs corresponding to fixes to `.dart` files. When it finds them, it will output the commands you should run to a  `.actions` file.

This has already been written for you in `codelab_builders/lib/actions_builder.dart`. To make the code a bit more interesting it uses code from codelab part 04 to check for the `@format` annotation, then with the new code

```dart
    final formattedAsset = buildStep.inputId.changeExtension('.formatted');

    if (await buildStep.canRead(formattedAsset)) {
      final formattedAssetCachedPath =
          '.dart_tool/build/generated/${formattedAsset.package}/${formattedAsset.path}';
      await buildStep.writeAsString(
        buildStep.inputId.changeExtension('.actions'),
        'cp $formattedAssetCachedPath ${buildStep.inputId.path}\n',
      );
    }
```

it checks whether any `.formatted` file has been written, and if so, 
it writes a command to copy the formatted file over the original to the `.actions` file.

`actions_builder` is not yet configured to run; do so by updating its entry in `codelab_builders/build.yaml` to

```
  actions_builder:
    import: "package:codelab_builders/builders.dart"
    builder_factories: ["actionsBuilder"]
    build_extensions: {".dart": [".actions"]}
    build_to: source
    auto_apply: dependents
```

so you can see the output. Now as you make edits to `end_to_end_test/lib/my_source.dart` you will see `my_source.action` appear if reformatting is needed. The `.formatted` file also appears, but is harder to notice as it's hidden: `.dart_tool/build/generated/end_to_end_test/lib/my_source.formatted`.

These are not the final settings for the builder: its output should also be hidden and optional. Update `codelab_builders/build.yaml` to

```
  actions_builder:
    import: "package:codelab_builders/builders.dart"
    builder_factories: ["actionsBuilder"]
    build_extensions: {".dart": [".actions"]}
    build_to: cache
    is_optional: true
    auto_apply: dependents
```

and again the output disappears because there is now no non-optional builder asking for work to be done.

### Builder Ordering

Now that there are multiple builders running, the _order_ of the builders matters.

A builder can only see output from a builder that runs before it.

Crucially, this is true _even if the output exists on disk from a previous build_. The build system prevents a builder from reading any output that will be overwritten by a later builder. If a builder does try to read such an output, it appears to the builder as if it does not exist, exactly as would happen in a clean build. This ensures that incremental builds always have the same output as a clean build.

If the two `actions_builder` is already working correctly with `format_builder` then it's a happy coincidence of ordering. Better to make it explicit in `codelab_builders/build.yaml`:

```
  actions_builder:
    import: "package:codelab_builders/builders.dart"
    builder_factories: ["actionsBuilder"]
    build_extensions: {".dart": [".actions"]}
    build_to: cache
    is_optional: true
    auto_apply: dependents
    required_inputs: [".formatted"]    
```

This tells `build_runner` that `actions_builder` wants to read `.formatted` files; so run any builders that output `.formatted` files first.

### Globs

The final builder will read all `.actions` files and combine them into a single script you can run to apply all the actions.

It has already been written for you in `codelab_builders/lib/combine_builder.dart`:

```dart
  @override
  Future<void> build(BuildStep buildStep) async {
    final output = StringBuffer();

    await for (final actionsAsset in buildStep.findAssets(Glob('**.actions'))) {
      output.write(await buildStep.readAsString(actionsAsset));
    }

    await buildStep.writeAsString(
      AssetId(buildStep.inputId.package, 'tool/actions.sh'),
      output.toString(),
    );
  }
```

The `buildStep.findAssets` method matches files on disk _and_ generated outputs _and_ optional generated outputs.

So, it matches `end_to_end_test/lib/my_source.actions` even though it it's optional, hidden, and _not generated yet_. It triggers `actions_builder`, which in turn looks for `my_source.formatted`, which triggers `format_builder`.

If formatting is needed, `format_builder` outputs the formatted source; `actions_builder` outputs the command needed to update the original source; and `combine_builder` combines that command into `tool/actions.sh`.

If formatting is _not_ needed, `format_builder` outputs nothing, `actions_builder` outputs nothing, and the `Glob` in `combine_builder` finds no output.

`combine_builder` is not configured to run, yet; configure it by updating `codelab_builders/build.yaml`:

```yaml
  combine_builder:
    import: "package:codelab_builders/builders.dart"
    builder_factories: ["combineBuilder"]
    build_extensions: {"$lib$": ["../tool/actions.sh"]}
    build_to: source
    auto_apply: dependents
    required_inputs: [".actions"]
```

This will be user-visible output, so `build_to: source`. It should run automatically when `codelab_builders` is in `dev_dependencies`, so `auto_apply: dependents`. It needs to run after `actions_builder`, so it has `required_inputs`. And, it's doing work the user directly wants, so it is _not_ declared as optional.

With this setup, you can now edit source under `end_to_end_test/lib` and see the `tool/actions.sh` file get updated with the commands needed to format it. Per the check in `actions_builder`, it _only_ checks formatting for files with

```dart
@format
library;
```

declaring that they are opting in.

### More Fixes

Can you extend this to add more automated fixes?

The final state of this part is available in the `05_complete` directory next to `05`. This was the last part! Return to [the main page](../README.md) to see a list of possible future parts and to give feedback.
