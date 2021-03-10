// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:meta/meta.dart';

import '../value.dart';
import '../value/external/value.dart' as ext;
import 'async_built_in.dart';

/// An interface for functions and mixins that can be invoked from Sass by
/// passing in arguments.
///
/// This class represents callables that *need* to do asynchronous work. It's
/// only compatible with the asynchonous `compile()` methods. If a callback can
/// work synchronously, it should be a [Callable] instead.
///
/// See [Callable] for more details.
@sealed
abstract class AsyncCallable {
  /// The callable's name.
  String get name;

  @Deprecated('Use `AsyncCallable.function` instead.')
  factory AsyncCallable(String name, String arguments,
          FutureOr<ext.Value> callback(List<ext.Value> arguments)) =>
      // TODO: no as
      AsyncCallable.function(name, arguments, callback);

  /// Creates a callable with the given [name] and [arguments] that runs
  /// [callback] when called.
  ///
  /// The argument declaration is parsed from [arguments], which should not
  /// include parentheses. Throws a [SassFormatException] if parsing fails.
  ///
  /// See [new Callable] for more details.
  factory AsyncCallable.function(String name, String arguments,
          FutureOr<ext.Value> callback(List<ext.Value> arguments)) =>
      // TODO: no as
      AsyncBuiltInCallable.function(name, arguments, (arguments) {
        var result = callback(arguments);
        if (result is ext.Value) return result as Value;
        return (result as Future<ext.Value>).then((value) => value as Value);
      });
}
