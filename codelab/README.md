# Builder Codelab

Welcome to the `build_runner` codelab for builder authors!

It'll take you through writing a series of builders to show the various things `build_runner` can do.

TODO(davidmorgan): the instructions are currently for Linux. Make Windows-compatible!
TODO(davidmorgan): code currently uses the analyzer element1 API; release a `build_runner` for the element2 API and update the codelab.

## Setup

Start by cloning the `build` repo.

```bash
mkdir -p ~/git/build
cd ~/git/build
git clone https://github.com/dart-lang/build.git
```

The codelab isn't merged yet, so pull the branch:

```bash
git remote add dm https://github.com/davidmorgan/build.git
git fetch dm codelab
git checkout codelab
```

And change to the codelab subdirectory:

```bash
cd codelab
```

## Package Layout

Running a builder with `build_runner` usually involves either two or three packages.

 - The builder code. In this codelab, the builders are always in `package:codelab_builders`.
 - The package that applies the builders. Applying your own builders is an important way to test them, so in this codelab the package that applies the builders is called `package:end_to_end_test`. It is exactly a normal user of `package:codelab_builders`.
 - Optionally, a package used to _configure and trigger the builders_. Usually, this means it has annotations. In this codelab when there is such a package it's `package:codelab_annotations`.

## Codelab Layout

Each part of the codelab is under a numbered subdirectory, for example `01`.

The instructions are a `README.md` file in that subdirectory.

Next to it is another subdirectory with the final state of the code after following all the instructions, for example `01_complete`.

## Parts

[01 First Builder](01/README.md) in which you learn how to run builds and create a builder that reads one file and writes one file.

[02 Many Files Builder](02/README.md) in which you learn how to write a builder that writes an output for every file in the package; then to make it triggered automatically and only for the files where it's requested.

[03 Resolving Builder](03/README.md) in which you learn how to write a builder that parses or resolves Dart source code with the Dart Analyzer.

[04 Equality Part Builder](04/README.md) in which you write a builder that implements `operator==`.

## Addendum: Part vs Library Builders

Skip this if you like.

Builders that output part files have the advantage of being able to add to the checked-in library: they can access private members, and provide private declarations. But they have the _disadvantage_ that they can't generate imports. If a builder that outputs parts wants to use types from other libraries, it has to ask the user to add the imports to the checked-in file.

Builders that output library files face the reversed situation: they can add imports, but they can't access or provide private declarations.

Both are used in practice, depending on which best fits the use case of each particular generator.

The [enhanced parts](https://github.com/dart-lang/language/issues/4155) language feature will allow imports in parts; after that all generators can be (enhanced) part generators.