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
  }) {
    return MatrixAxes(
      themes: themes ?? this.themes,
      locales: locales ?? this.locales,
      textScales: textScales ?? this.textScales,
      devices: devices ?? this.devices,
      directions: directions ?? this.directions,
    );
  }
}
