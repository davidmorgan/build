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

