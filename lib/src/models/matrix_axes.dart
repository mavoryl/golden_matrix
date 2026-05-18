import 'package:flutter/widgets.dart';

import 'matrix_device.dart';
import 'matrix_theme.dart';

/// Describes the dimensions of the test matrix.
class MatrixAxes {
  final List<MatrixTheme> themes;
  final List<Locale> locales;
  final List<double> textScales;
  final List<MatrixDevice> devices;
  final List<TextDirection> directions;

  const MatrixAxes({
    this.themes = const [MatrixTheme.light],
    this.locales = const [Locale('en')],
    this.textScales = const [1.0],
    this.devices = const [MatrixDevice.phoneSmall],
    this.directions = const [],
  });

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
