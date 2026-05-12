import 'package:flutter/material.dart';

import '../core/slug.dart';

/// Represents a theme configuration for matrix golden testing.
///
/// Use [data] to attach arbitrary context (custom theme objects, feature
/// flags, brand config, etc.) that can be accessed in builders via
/// `combination.theme.data`.
///
/// ## Using `data` for a custom theme system
///
/// If your app uses a non-Material theme system — for example a brand
/// `MTheme` inherited widget — you can attach the resolved theme to
/// each [MatrixTheme] via [data], then read it back inside your
/// [screenMatrixGolden] `appBuilder`:
///
/// ```dart
/// // 1. Declare themes that carry a custom MTheme alongside ThemeData.
/// const themes = [
///   MatrixTheme.custom('light', ThemeData.light(), data: MTheme.light),
///   MatrixTheme.custom('dark',  ThemeData.dark(),  data: MTheme.dark),
/// ];
///
/// // 2. Read combination.theme.data inside the appBuilder.
/// screenMatrixGolden(
///   'SettingsScreen',
///   axes: const MatrixAxes(themes: themes),
///   appBuilder: (combination) {
///     final myTheme = combination.theme.data as MTheme;
///     return MThemeScope(
///       theme: myTheme,
///       child: MaterialApp(
///         theme: combination.theme.resolve(),
///         home: const SettingsScreen(),
///       ),
///     );
///   },
/// );
/// ```
///
/// Example with a custom theme system:
/// ```dart
/// axes: MatrixAxes(
///   themes: [
///     MatrixTheme.custom('light', ThemeData.light(), data: MyTheme.light()),
///     MatrixTheme.custom('dark', ThemeData.dark(), data: MyTheme.dark()),
///   ],
/// )
///
/// // In builder:
/// final myTheme = combination.theme.data as MyTheme;
/// ```
class MatrixTheme {
  final String name;
  final ThemeData? themeData;

  /// Arbitrary data attached to this theme.
  ///
  /// Use this to pass custom theme objects, brand configurations,
  /// or any other context needed in widget builders.
  final Object? data;

  const MatrixTheme._(this.name, [this.themeData, this.data]);

  static const light = MatrixTheme._('light', null, null);
  static const dark = MatrixTheme._('dark', null, null);

  /// Creates a custom theme with a [name], [ThemeData], and optional [data].
  factory MatrixTheme.custom(String name, ThemeData themeData, {Object? data}) {
    assert(name != '', 'MatrixTheme name must not be empty');
    return MatrixTheme._(name, themeData, data);
  }

  /// Whether this is the built-in dark theme.
  bool get isDark => identical(this, dark) || (themeData?.brightness == Brightness.dark);

  /// Returns the resolved ThemeData.
  ThemeData resolve() {
    if (themeData != null) return themeData!;
    return isDark ? ThemeData.dark() : ThemeData.light();
  }

  String get slug => slugify(name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MatrixTheme && other.name == name);

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'MatrixTheme($name)';
}
