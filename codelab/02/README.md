# Builder Codelab

If you haven't already, follow "Setup" on [the main page](../README.md).

## 02 Many Files Builder

The previous part created a builder that reads one file and writes one file.

More often, builders do work per file, so that adding files to your package causes more files to be generated. This part is about creating such a builder.

Start by running "watch" mode.

```bash
cd 02/end_to_end_test
dart run build_runner watch -d
```

The rest of the codelab will assume "watch" mode is running.

As in the previous part, the build initially fails because it's not implemented:

```
[SEVERE] codelab_builders:many_files_builder on lib/some_file.dart (cached)

UnimplementedError
#0      ManyFilesBuilder.build (package:codelab_builders/many_files_builder.dart:14:46)```

So, implement it, in `codelab_builders/lib/many_files_builder.dart`:

```dart
  @override
  Future<void> build(BuildStep buildStep) async {
    final count = (await buildStep.readAsString(buildStep.inputId)).length;

    await buildStep.writeAsString(
      buildStep.inputId.changeExtension('.count'),
      '$count\n',
    );
  }
```

Unlike the builder in the previous part, this builder does not have to check whether the input file exists. Instead, each build step runs _because_ one file exists. In fact, it runs for every `.dart` file, as declared in its `buildExtensions`:

```dart
  Map<String, List<String>> get buildExtensions => {
    '.dart': ['.count'],
  };
```

So if there are ten `.dart` files in the package, it runs ten times. As before, inputs are tracked, so on an incremental build anywhere between zero and ten of the build steps might run, depending on what changed.

Experiment with adding, changing and removing files. Make sure "watch" is running in a separate terminal.

```bash
touch lib/in.dart lib/in2.dart; sleep 2
cat lib/in.count lib/in2.count
0
0
echo 'hi' >> lib/in.dart; echo 'hello' >> lib/in2.dart; sleep 2
cat lib/in.count lib/in2.count
3
6
rm lib/in.dart; sleep 2
cat lib/in.count lib/in2.count
cat: lib/in.count: No such file or directory
6
```

Notice that `.count` files are automatically added, updated and even deleted to reflect the current state of all the `.dart` files.

## Triggered Generation

Most builders don't run on every file in the package. Instead, generation is triggered via something in the source, such as an annotation.

Add a dependency from `end_to_end_test` onto `package:codelab_builders` by updating `end_to_end_test/pubspec.yaml`:

```yaml
dependencies:
  codelab_annotations:
    path: ../codelab_annotations
```

Notice that while `codelab_builders` is a `dev_dependency`, `codelab_annotations` is a normal dependency. That's because use code never references the builder directly, but it _will_ use the annotation.

Adding the dependency will cause "watch" mode to exit

```
[SEVERE] Terminating builds due to package graph update, please restart the build.
```

so find the terminal where you ran it, and run it again.

Now add source files `end_to_end_test/lib/count_me.dart`

```dart
@count
library;

import 'package:codelab_annotations/codelab_annotations.dart';
```

and `end_to_end_test/lib/do_no_count_me.dart`

```dart
import 'package:codelab_annotations/codelab_annotations.dart';
```

and notice that `.count` files are generated for both, because you haven't added a check for the annotation yet.

Do so:

```dart
  @override
  Future<void> build(BuildStep buildStep) async {
    final content = await buildStep.readAsString(buildStep.inputId);

    if (!content.contains('@count')) return;

    final count = content.length;
    await buildStep.writeAsString(
      buildStep.inputId.changeExtension('.count'),
      '$count\n',
    );
  }
```

Now only `count_me.count` should exist: `do_not_count_me.dart` generates nothing, so `do_not_count_me.count` is deleted.

Edit the files and notice that adding or removing the `@count` annotation now triggers generation or deletion of the corresponding `.count` file.

The check for `@count` is a simple string match, so it doesn't care where you put the annotation: in a comment or a string literal will also trigger generation. Parsing or resolving the code would let you do better—both will be covered in the next part.

Instead, this codelab part will complete the "triggered generation" feature.

You probably don't want every user of your generator to have to create a `build.yaml` file.

So, delete `end_to_end_test/build.yaml`. You will find `build_runner` no longer builds anything for the package.

To make things work again, update `codelab_builders/build.yaml` to add `auto_apply`:

```
builders:
  many_files_builder:
    import: "package:codelab_builders/builders.dart"
    builder_factories: ["manyFilesBuilder"]
    build_extensions: {".dart": [".count"]}
    build_to: source
    auto_apply: dependents
```

Now users can activate the builder simply by adding a `dev_dependencies` entry pointing to `codegen_builders`, then adding the `@count` annotation.

This is the most popular way to trigger builders.

## Addendum: Primary Inputs

Skip this if you like.

To understand exactly what and when `build_runner` builds it's useful to introduce the concepts of primary and normal inputs.

Each build step exists because of a primary input.

A primary input is a `buildExtensions` match.

For example, `many_files_builder` declares

```dart
  @override
  Map<String, List<String>> get buildExtensions => {
    '.dart': ['.count'],
  };
```

which means that every file named `*.dart` in the package is a primary input.

For every primary input a build step is created. When that build step runs, the primary input is passed in as `buildStep.inputId`. The build has the opportunity to output files with some or all of the declared extenions; `.count` in this case, conveniently expressed in the code as `buildStep.inputId.changeExtension('.count')`.

Adding or removing files can cause primary inputs to appear or disappear, which in turn causes build steps to be created or destroyed. This is why the `.count` files are automatically added, updated, and deleted.

A primary input can also be a _placeholder_. In the previous codelab part, `first_builder` declares 

```dart
  @override
  Map<String, List<String>> get buildExtensions => {
    r'$lib$': ['first_builder_output.txt'],
  };
```

which means that it runs just once in the package, for its `lib` folder.

So: primary inputs are about _which build steps_ make up the build. They are _not_ used for change detection.

To see why not, notice that the `build` method can choose to write its output without reading any files. Then, there is no need to rerun it when its primary input file changes: it will produce the same output.

So, distinct from primary inputs is the concept of non-primary inputs, or just "inputs". These are the files that the `build` method actually reads. If any input changes, the `build` method must run again. If files that are not inputs change, the `build` method does not need to rerun.

The primary input is _also_ a normal input exactly if the `build` method reads it, which `many_files_builder` does:

```dart
  @override
  Future<void> build(BuildStep buildStep) async {
    final content = await buildStep.readAsString(buildStep.inputId);
```
