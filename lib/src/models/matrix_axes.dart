import 'package:flutter/widgets.dart';

import 'package:golden_matrix/src/models/matrix_device.dart';
import 'package:golden_matrix/src/models/matrix_theme.dart';

/// Describes the dimensions of the test matrix.
class MatrixAxes {
  /// Creates a set of axes describing the test matrix.
  ///
  /// All fields default to a minimal single-value set that produces
  /// one combination per scenario when no other axes are specified.
  const MatrixAxes({
    this.themes = const [MatrixTheme.light],
    this.locales = const [Locale('en')],
    this.textScales = const [1.0],
    this.devices = const [MatrixDevice.phoneSmall],
    this.directions = const [],
    this.directionResolver,
  });

  /// Themes to render each scenario against.
  final List<MatrixTheme> themes;

  /// Locales to apply when wrapping each scenario in MaterialApp.
  final List<Locale> locales;

  /// Text scale factors to test (e.g. 1.0, 1.3, 1.5).
  final List<double> textScales;

  /// Logical device profiles (size, pixel ratio, safe area) to render in.
  final List<MatrixDevice> devices;

  /// Explicit text directions. When empty, direction is inferred from
  /// the locale (RTL languages auto-inferred).
  final List<TextDirection> directions;

  /// Decides the text direction of a locale, replacing the built-in inference.
  ///
  /// Ignored when [directions] is non-empty — that axis enumerates directions
  /// regardless of locale, which is a different question from "which way does
  /// this locale read".
  ///
  /// The default is `MatrixGenerator.directionForLocale`, a table over CLDR's
  /// right-to-left languages and scripts. Any table is wrong for someone: a
  /// custom language subtag, a private-use locale, or a design that mirrors on
  /// an app flag rather than on the locale. Before this existed the only escape
  /// was enumerating [directions] and losing per-locale inference entirely.
  ///
  /// Pass a top-level or static function to keep the axes `const`:
  ///
  /// ```dart
  /// TextDirection myDirection(Locale locale) =>
  ///     locale.languageCode == 'xx' ? TextDirection.rtl : TextDirection.ltr;
  ///
  /// const axes = MatrixAxes(directionResolver: myDirection);
  /// ```
  final TextDirection Function(Locale locale)? directionResolver;

  /// Returns a copy of these axes with selected fields replaced.
  ///
  /// Useful for tweaking a preset's axes — e.g. take a preset's
  /// configuration and add one more device without re-declaring
  /// every axis:
  ///
  /// ```dart
  /// final axes = MatrixPreset.componentFull.axes.copyWith(
  ///   devices: [...MatrixPreset.componentFull.axes.devices, MatrixDevice.ipadPro13],
  /// );
  /// ```
  MatrixAxes copyWith({
    List<MatrixTheme>? themes,
    List<Locale>? locales,
    List<double>? textScales,
    List<MatrixDevice>? devices,
    List<TextDirection>? directions,
    TextDirection Function(Locale locale)? directionResolver,
  }) {
    return MatrixAxes(
      themes: themes ?? this.themes,
      locales: locales ?? this.locales,
      textScales: textScales ?? this.textScales,
      devices: devices ?? this.devices,
      directions: directions ?? this.directions,
      directionResolver: directionResolver ?? this.directionResolver,
    );
  }
}
