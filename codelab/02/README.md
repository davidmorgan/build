# Builder Codelab

[Go back to the main page](../README.md).

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

Instead, let's complete 