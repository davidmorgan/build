# Writing Builders

A guide to writing builders that run with
[`build_runner`](https://pub.dev/packages/build_runner).

- [Builder and PostProcessBuilder](#builder-and-postprocessbuilder)
  - [Builder](#builder)
  - [PostProcessBuilder](#postprocessbuilder)
- [Shared Part Builders in source_gen](#shared-part-builders-in-source_gen)
- [Outputting Libraries vs. Parts](#outputting-libraries-vs-parts)
  - [Libraries](#libraries)
  - [Parts](#parts)
  - [Upcoming Language Feature: Parts with Imports](#upcoming-language-feature-parts-with-imports)
- [Upcoming Build Runner Feature: Add to Library](#upcoming-build-runner-feature-add-to-library)
  - [How It Works](#how-it-works)
  - [Cross-Builder Visibility Across Phases](#cross-builder-visibility-across-phases)
  - [Scoped Imports](#scoped-imports)
  - [Output Scope & Performance](#output-scope--performance)
  - [Builder Configuration and Implementation](#builder-configuration-and-implementation)
- [Comparison Summary](#comparison-summary)

---

## Builder and PostProcessBuilder

The two types of builder are [`Builder`](https://pub.dev/documentation/build/latest/build/Builder-class.html)
and [`PostProcessBuilder`](https://pub.dev/documentation/build/latest/build/PostProcessBuilder-class.html).

### Builder

`Builder` is the most powerful and general builder.

- **Declared file mappings**: Declares inputs and outputs in advance using `buildExtensions`, such as `{'.dart': ['.freezed.dart']}` or `{'.dart': ['.json']}`.
- **Build steps**: Each build step runs on one _primary input file_ and produces zero or more outputs.
- **Phased execution**: The build runs in a series of phases, with each phase containing all the build steps for one particular builder. Outputs from a builder become visible in the next phase: so a `freezed` build step cannot read the output of other `freezed` build steps, but a different builder running at a later phase _can_ read them.
- **Analyzer access**: `buildStep.resolver` allows inspecting Dart ASTs, resolving library elements, reading annotations, and introspecting types.
- **Asset reading**: Can read any readable asset in the package or in transitive dependency packages via `buildStep.readAsString` or `buildStep.readAsBytes`.

#### Typical Uses

- Generating standalone Dart files such as `.freezed.dart`, `.mocks.dart`, or `.mapper.dart`.
- Serializing assets or compiling web and styling resources.
- Generating auxiliary metadata files consumed by subsequent build phases.

### PostProcessBuilder

`PostProcessBuilder` is a limited type of builder for specific purposes. It runs at the end of the build after all standard `Builder` phases have finished.

- **Declared input**: Matches assets by `inputExtensions`.
- **Any output**: Can emit any output file that does not collide with existing assets.
- **Primary input only**: Can only read its primary input asset. Has no access to `buildStep.resolver`.
- **Asset deletion**: Can delete its primary input using `buildStep.deletePrimaryInput()`.
- **Write only**: Because it runs at the end of the build, its outputs cannot be consumed by any other `Builder` or `PostProcessBuilder`.

#### Typical Uses

- Deleting artifact tree files that are not needed after the build, so they will not be written when using `--output` or served when using `dart run build_runner serve`.
- Preparing assets for distribution, such as archiving or compression.

---

## Shared Part Builders in source_gen

When multiple builders contribute code to the same Dart library, creating a separate generated file for each builder clutters the package and forces the user to write multiple `part` directives.

To solve this, [`package:source_gen`](https://pub.dev/packages/source_gen) introduced shared part builders.

Behind the scenes, `source_gen` coordinates `Builder` and `PostProcessBuilder` across multiple phases:

1. **Generation phase**: Each generator runs as a `SharedPartBuilder`. Instead of writing directly to the final part file, each builder writes an artifact tree file under `.dart_tool/build/generated/`, such as `model.json_serializable.g.part`.
2. **Combining phase**: A subsequent `combining_builder` reads all `.part` artifact tree files for `model.dart`, concatenates their source under a single `part of 'model.dart';` header, and writes the consolidated `model.g.dart` file.
3. **Cleanup**: A `PostProcessBuilder` deletes the `.part` artifact tree files so they will not be written when using `--output` or served when using `dart run build_runner serve`.

The user writes a single directive in their code:

```dart
// lib/model.dart
import 'package:json_annotation/json_annotation.dart';

part 'model.g.dart';

@JsonSerializable()
class Model {
  ...
}
```

---

## Outputting Libraries vs. Parts

A builder that outputs Dart source must choose whether to output a library or a part.

### Libraries

A builder can output an independent library file, such as `user.mocks.dart`, imported by the user with `import 'user.mocks.dart';`.

- **Advantage**: The generated library declares its own `import` directives. It manages its own dependencies without forcing the user to add imports to the main library file.
- **Limitation**: As a separate library, the generated code cannot access or provide private (`_`) symbols in the user's library. This makes it harder for the generated and user code to collaborate.

### Parts

A builder can output a dedicated part file, included with `part 'user.custom.dart';`, or contribute to a shared part file like `part 'user.g.dart';`.

- **Advantage**: Generated code belongs to the same library. It has access to private declarations, can implement private interfaces, and can supply mixins like `with _$User`.
- **Limitation**: Dart `part` files cannot declare `import` directives. Any package or type referenced by generated code must be imported by the user in the main library file, even if handwritten code never references those symbols directly.

### Upcoming Language Feature: Parts with Imports

A future Dart SDK release will add **Parts with Imports**, providing builders with the benefits of libraries within a part file.

When the feature arrives, all builders should output parts.

## Upcoming Build Runner Feature: Add to Library

**Add to Library** gives builders a new way to write Dart source code. It's a better way to write part files, and should be immediately interesting for builders that currently write source to part files. When _Parts with Imports_ launches, builders that currently write source to libraries should use it too.

### How It Works

- `build_runner` collects contributions and imports from all participating builders directly into a single shared part file per library.
- The shared part is generated under `lib/_br_/`, for example `lib/_br_/model.dart`.
- The user includes the part in their code:

```dart
// lib/user.dart
part '_br_/user.dart';

@MyAnnotation()
class User {
  ...
}
```

### Cross-Builder Visibility Across Phases

A major advantage of adding to a library is **phase visibility**:

Builders can see part output from builders that ran before them.

When Builder A runs in Phase 1 and contributes code, `build_runner` immediately updates the library's shared part. When Builder B runs in Phase 2 on the same library, its `buildStep.resolver` can resolve the library including the declarations contributed by Builder A.

This enables multi-step generation pipelines where downstream builders inspect and build upon code emitted by upstream builders.

### Scoped Imports

When _Parts with Imports_ is available, `LibrarySourceSink` provides a mechanism for builders to scope the imports they add.

Through `BuildStep.librarySourceSink`, builders declare their imports with a unique prefix:

```dart
sink.addImport('package:my_helpers/helpers.dart', as: '${sink.importPrefix}_helpers');
```

Each builder receives its own `sink.importPrefix`. Imports do not collide between builders and do not leak into the parent library scope.

### Output Scope & Performance

The _Add to Library_ feature distinguishes its outputs from other files: they cannot be considered as normal inputs to any builder, they are only "visible" via analysis.

This significantly reduces the number of files that builders treat as possible inputs, improving performance.

### Builder Configuration and Implementation

#### 1. Configuration in `build.yaml`

A builder declares `adds_to_library: true` and targets the `_br_` directory:

```yaml
builders:
  my_builder:
    import: "package:my_builder/builder.dart"
    builder_factories: ["myBuilder"]
    build_extensions: {".dart": ["_br_/.dart"]}
    adds_to_library: true
    auto_apply: dependents
    build_to: source
```

#### 2. Writing Code in the Builder

Inside `build(BuildStep buildStep)`:

```dart
import 'package:build/build.dart';

class MyBuilder implements Builder {
  @override
  final buildExtensions = const {
    '.dart': ['_br_/.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final sink = buildStep.librarySourceSink;

    final prefix = '${sink.importPrefix}_helpers';
    sink.addImport('package:my_package/helpers.dart', as: prefix);

    sink.add('''
void generatedFunction() {
  $prefix.doWork();
}
''');
  }
}
```

---

## Comparison Summary

| Capability | Standard `Builder` | `PostProcessBuilder` | Shared Part Builder (`source_gen`) | Add to Library (Upcoming) |
|---|---|---|---|---|
| **Build phase** | Normal build phases | Final phase only | Multi-phase (generators + combining) | Normal build phases |
| **Output files** | Fixed extensions | Any non-colliding file | Single `.g.dart` | Single `_br_/*.dart` |
| **Temporary artifact tree files** | None | None | Many `.part` files | None |
| **Analyzer / Resolver** | Yes | No | Yes during generation | Yes |
| **See earlier part output** | N/A (separate files) | No | No | **Yes** across phases |
| **Import scoping** | Independent file scope | N/A | Parent library only | Scoped imports via `importPrefix` |
| **Can delete assets** | No | Yes (`deletePrimaryInput`) | Via post-process cleanup | No |
| **Native engine support** | Yes | Yes | Requires `package:source_gen` | Yes |
