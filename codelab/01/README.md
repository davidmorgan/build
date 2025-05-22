# Builder Codelab

[Go back to the main page](../README.md).

## 01 First Builder

Start by running a build.

```bash
cd 01/end_to_end_test
dart run build_runner build -d
```

A lot will happen behind the scenes—we'll go into detail later.

The output ends with

```
[SEVERE] codelab_builders:first_builder on lib/$lib$

UnimplementedError
#0      FirstBuilder.build (package:codelab_builders/first_builder.dart:14:46)
```

because the builder hasn't been implemented yet.

Open `codelab/01/codelab_builders/first_builder.dart` in your IDE of choice and find the build method

```dart
  @override
  Future<void> build(BuildStep buildStep) => throw UnimplementedError();
```

which is the most important builder method.

The `BuildStep` passed in is the main way to interact with the build system: use it to read files, write files, and resolve Dart code. For now, just make it do nothing, then build again:

```dart
  @override
  Future<void> build(BuildStep buildStep) async {};
```

```bash
dart run build_runner build -d
```

Notice that builders are not required to write any outputs: the build now succesfully does nothing! Make it write something:

```dart
  @override
  Future<void> build(BuildStep buildStep) async {
    await buildStep.writeAsString(
      AssetId(buildStep.inputId.package, 'output.txt'),
      'hello world',
    );
  }
```

```bash
dart run build_runner build -d
```

This time, a different failure


```
[SEVERE] codelab_builders:first_builder on lib/$lib$:

UnexpectedOutputException: end_to_end_test|output.txt
Expected only: {end_to_end_test|lib/first_builder_output.txt}
```

because while builders are not _required_ to write any output, they must _declare_ all possible output. The `buildExtensions` method, also in `first_builder.dart`, does so:

```
  @override
  Map<String, List<String>> get buildExtensions => {
    r'$lib$': ['first_builder_output.txt'],
  };
```

So, change the builder to output what it's allowed to output:

```
  @override
  Future<void> build(BuildStep buildStep) async {
    await buildStep.writeAsString(
      AssetId(buildStep.inputId.package, 'first_builder_output.txt'),
      'hello world',
    );
  }
```

```bash
dart run build_runner build -d
```

This time the build succeeds. But, you won't see any output file.

By default, builders write their output "hidden", to the `.dart_tool/build` directory. This is suitable for build output that the user _does not_ want to see or interact with.

Unhide the output by adding a new last line to `codelab_builders/build.yaml`:

```yaml
    build_to: source
```

so the whole file is now:

```yaml
builders:
  first_builder:
    import: "package:codelab_builders/builders.dart"
    builder_factories: ["firstBuilder"]
    build_extensions: {"$lib$": ["first_builder_output.txt"]}
    build_to: source
```

Then rebuild:

```bash
dart run build_runner build -d
```

and now the output appears as `lib/first_builder_output.txt`.

If you run the build again you'll find the file is _not_ rebuilt. It will only be rebuilt if the output is deleted or if some input changes. But, what counts as an "input"?

### Builder Inputs

Currently, the builder doesn't read anything: it has no file inputs. Add one:

```dart
  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = AssetId(buildStep.inputId.package, 'lib/input.dart');

    String? contents;
    if (await buildStep.canRead(inputId)) {
      contents = await buildStep.readAsString(inputId);
    }
    final output =
        contents == null
            ? 'missing\n'
            : 'read with length ${contents.length}\n';
    await buildStep.writeAsString(
      AssetId(buildStep.inputId.package, 'lib/first_builder_output.txt'),
      output,
    );
  }
```

Now the builder has an input, `lib/input.dart`, although it's not required to be there. Try creating, modifying, and deleting the file, rebuilding, then checking how the output changes:

```bash
dart run build_runner build -d
cat lib/first_builder_output.txt
missing
```

```bash
echo 'hi' > lib/input.dart
dart run build_runner build -d
cat lib/first_builder_output.txt
read with length 3
echo 'hi again' >> lib/input.dart
dart run build_runner build -d
cat lib/first_builder_output.txt
read with length 12
rm lib/input.dart
dart run build_runner build -d
cat lib/first_builder_output.txt
missing
```

`build_runner` keeps track of everything that a builder reads, then checks those files for changes when it does an incremental build. So, now, the builder runs whenever `input.dart` appears, disappears or changes.

### The Watch Command

The `watch` command is an alternative to repeatedly running `dart run build_runner build`.

```bash
dart run build_runner watch -d
```

While this is running you can forget about the terminal window, and just make edits in your IDE. The outputs will update when needed.

If you want to make edits using the command line, you'll need a second terminal window. You'll find the same edits as before work automatically while "watch" is running:

```
echo 'hi' > lib/input.dart; sleep 2
cat lib/first_builder_output.txt
read with length 3
echo 'hi again' >> lib/input.dart; sleep 2
cat lib/first_builder_output.txt
read with length 12
rm lib/input.dart; sleep 2
cat lib/first_builder_output.txt
missing
```

That's it for `first_builder`. To recap, you:

  - Learned to run builds with `dart run build_runner build -d` and `dart run build_runner watch -d`.
  - Created a builder that reads one specific file in the package and produces one output based on it.

The final state of this step is available in the `01_complete` directory next to `01`.

### Addendum: The Wiring

Skip this if you like.

Here is how the build is "wired up":

 - When you run `dart run build_runner build -d` in `end_to_end_test`, `build_runner` reads `end_to_end_test/build.yaml`.
 - It follows the reference there to `codelab_builders:first_builder` and reads the entry for `first_builder` in `codelab_builders/build.yaml`.
 - This points to the top level declaration `firstBuilder` in `package:codelab_builders/builders.dart`. This is a _builder factory_: a top level method that takes `BuilderOptions` and returns a `Builder`.
 - `build_runner` generates a script that depends on both `package:codelab_builders` and `package:build_runner`, and runs that script to do the actual build.
 - You can think of the generated script as "build_runner with codelab_builders plugged in". It does the build, instantiating `first_builder` as needed using the plugged in builder factory.
