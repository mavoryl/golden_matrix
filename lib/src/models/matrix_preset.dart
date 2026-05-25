import 'package:flutter/widgets.dart';

import 'package:golden_matrix/src/models/matrix_axes.dart';
import 'package:golden_matrix/src/models/matrix_device.dart';
import 'package:golden_matrix/src/models/matrix_rule.dart';
import 'package:golden_matrix/src/models/matrix_sampling.dart';
import 'package:golden_matrix/src/models/matrix_theme.dart';

/// A reusable bundle of axes, sampling strategy, and rules.
///
/// Presets simplify test declarations by providing sensible defaults
/// for common testing scenarios. Pass a preset to [matrixGolden] or
/// [screenMatrixGolden] instead of repeating the same axes and sampling
/// configuration across every test file.
///
/// ## Built-in presets
///
/// | Preset            | Sampling | Approx. tests / scenario | Best for          |
/// |-------------------|----------|--------------------------|-------------------|
/// | `componentSmoke`  | smoke    | ~2                       | Fast CI checks    |
/// | `componentFull`   | full     | 16                       | Full coverage     |
/// | `screenSmoke`     | smoke    | ~5                       | Screen-level CI   |
///
/// ## Example: using a built-in preset
///
/// ```dart
/// matrixGolden(
///   'MyWidget',
///   scenarios: [...],
///   preset: MatrixPreset.componentSmoke,
/// );
/// ```
///
/// ## Example: defining a custom preset
///
/// ```dart
/// const brandedSmoke = MatrixPreset(
///   axes: MatrixAxes(
///     themes: [MatrixTheme.light, MatrixTheme.dark],
///     locales: [Locale('en'), Locale('ar'), Locale('az')],
///     devices: [MatrixDevice.iphoneSE, MatrixDevice.iphone15, MatrixDevice.tablet],
///   ),
///   sampling: MatrixSampling.pairwise,
///   rules: [
///     // Skip large text on tablets — tablets always fit our copy.
///     // Note: in real code, prefer top-level functions over closures so
///     // the rule can be `const`.
///   ],
/// );
/// ```
class MatrixPreset {
  /// Creates a preset bundling [axes], [sampling], and [rules].
  const MatrixPreset({
    required this.axes,
    this.sampling = MatrixSampling.full,
    this.rules = const [],
  });

  /// The matrix axes (themes, locales, text scales, devices).
  final MatrixAxes axes;

  /// The sampling strategy used to reduce the Cartesian product of [axes].
  final MatrixSampling sampling;

  /// Filtering rules applied after the Cartesian product, before sampling.
  final List<MatrixRule> rules;

  /// Quick smoke test for components.
  ///
  /// Axes: light + dark theme, single device ([MatrixDevice.phoneSmall]).
  /// Sampling: [MatrixSampling.smoke].
  ///
  /// Produces roughly 2 tests per scenario — one base combination and
  /// one delta for the theme axis. Ideal for fast pre-merge CI checks
  /// where you only want to verify "does this still render in light and
  /// dark mode?".
  static const componentSmoke = MatrixPreset(
    axes: MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
    sampling: MatrixSampling.smoke,
  );

  /// Full coverage for components.
  ///
  /// Axes: 2 themes (light, dark) × 2 locales (`en`, `ar` — exercises
  /// RTL) × 2 text scales (`1.0`, `2.0`) × 2 devices
  /// ([MatrixDevice.phoneSmall], [MatrixDevice.tablet]) = 16
  /// combinations per scenario. Sampling: [MatrixSampling.full].
  ///
  /// Use for flagship widgets where the cost of exhaustive coverage is
  /// justified.
  static const componentFull = MatrixPreset(
    axes: MatrixAxes(
      themes: [MatrixTheme.light, MatrixTheme.dark],
      locales: [Locale('en'), Locale('ar')],
      textScales: [1.0, 2.0],
      devices: [MatrixDevice.phoneSmall, MatrixDevice.tablet],
    ),
  );

  /// Quick smoke test for screens.
  ///
  /// Axes: 2 themes (light, dark) × 2 locales (`en`, `ar` for LTR/RTL
  /// coverage) × 2 devices (phone + tablet). Sampling:
  /// [MatrixSampling.smoke].
  ///
  /// Produces roughly 5 tests per state (base + one delta per axis).
  /// Best for screen-level golden tests where you want a quick sanity
  /// check across the dominant visual axes.
  static const screenSmoke = MatrixPreset(
    axes: MatrixAxes(
      themes: [MatrixTheme.light, MatrixTheme.dark],
      locales: [Locale('en'), Locale('ar')],
      devices: [MatrixDevice.phoneSmall, MatrixDevice.tablet],
    ),
    sampling: MatrixSampling.smoke,
  );
}
