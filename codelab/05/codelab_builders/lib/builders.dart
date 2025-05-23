// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:build/build.dart';

import 'actions_builder.dart';
import 'combine_builder.dart';
import 'format_builder.dart';

Builder formatBuilder(BuilderOptions _) => FormatBuilder();
Builder actionsBuilder(BuilderOptions _) => ActionsBuilder();
Builder combineBuilder(BuilderOptions _) => CombineBuilder();
