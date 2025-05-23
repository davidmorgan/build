# Builder Codelab

Welcome to the `build_runner` codelab for builder authors!

It'll take you through writing a series of builders to show the various things `build_runner` can do.

TODO(davidmorgan): the instructions are currently for Linux. Make Windows-compatible! \
TODO(davidmorgan): code currently uses the analyzer element1 API; release a `build_runner` for the element2 API and update the codelab.

## Setup

Start by cloning the `build` repo.

```bash
cd ~/git
git clone https://github.com/dart-lang/build.git
cd build
```

The codelab isn't merged yet, so pull the branch:

```bash
git remote add dm https://github.com/davidmorgan/build.git
git fetch dm codelab
git checkout codelab
```

Run `dart pub get` so the workspace is ready to go:

```bash
dart pub get
```

Then change to the codelab subdirectory:

```bash
cd codelab
```

## Package Layout

Running a builder with `build_runner` usually involves either two or three packages.

 - The builder code. In this codelab, the builders are always in `package:codelab_builders`.
 - The package that applies the builders. Applying your own builders is an important way to test them, so in this codelab the package that applies the builders is called `package:end_to_end_test`. It uses `package:codelab_builders` the same way any other package would.
 - Optionally, a package used to _trigger and configure_ the builders. Usually, this means it has annotations. In this codelab when there is such a package it's `package:codelab_annotations`.

## Codelab Layout

The code that goes with each part of the codelab is under a numbered subdirectory, for example `01`.

The instructions are a `README.md` file in that subdirectory.

Next to it is another subdirectory with the final state of the code after following all the instructions, for example `01_complete`.

## Parts

Click into any part to get started. They're intended to be followed in order, but they also work independently.

[01 First Builder](01/README.md) in which you learn how to run builds and create a builder that reads one file and writes one file.

[02 Many Files Builder](02/README.md) in which you learn how to write a builder that writes an output for every file in the package; then to make it triggered automatically and only for the files where it's requested.

[03 Resolving Builder](03/README.md) in which you learn how to write a builder that parses or resolves Dart source code with the Dart Analyzer.

[04 Equality Part Builder](04/README.md) in which you write a builder that implements `operator==`.

[05 Many Builders](05/README.md) in which you make three builders that work together to check source in a package then aggregate the results.

## Future Topics

Possible future topics: 

 - Custom builder configuration via `build.yaml`.
 - `source_gen` is a package that makes it easier to write builders that generate Dart code based on Dart code, like `equality_builder` in part 04 above.
 - Small tests for builders with `package:build_test`.

 Please send requests, suggestions and feedback to the [discussion forum](https://github.com/dart-lang/build/discussions)!
