import 'package:flutter/widgets.dart';

import '../models/matrix_combination.dart';
import 'slug.dart';

/// Generates deterministic file paths for golden files.
class NamingStrategy {
  /// Returns the golden file path for a given combination.
  ///
  /// Format: `goldens/<test>/<scenario>/<theme>_<locale>_<direction>_<textScale>_<device>.png`
  /// (when [testName] is provided)
  ///
  /// Without [testName]: `goldens/<scenario>/<theme>_<locale>_<direction>_<textScale>_<device>.png`
  ///
  /// The [testName] prevents collisions when two `matrixGolden` calls use
  /// scenarios with the same name. Pass the first argument of `matrixGolden` here.
  static String goldenPath(MatrixCombination combination, {String? testName}) {
    final scenario = combination.scenario.slug;
    final theme = combination.theme.slug;
    final locale = _formatLocale(combination.locale);
    final dir = combination.direction == TextDirection.ltr ? 'ltr' : 'rtl';
    final scale = formatTextScale(combination.textScale);
    final device = combination.device.slug;
    final file = '${theme}_${locale}_${dir}_${scale}_$device.png';

    if (testName != null) {
      return 'goldens/${slugify(testName)}/$scenario/$file';
    }
    return 'goldens/$scenario/$file';
  }

  /// Formats a text scale value for use in file names.
  ///
  /// - `1.0` → `1x`
  /// - `2.0` → `2x`
  /// - `1.3` → `1_3x`
  /// - `1.35` → `1_35x`
  static String formatTextScale(double scale) {
    if (scale == scale.truncateToDouble()) {
      return '${scale.toInt()}x';
    }
    return '${scale.toString().replaceAll('.', '_')}x';
  }

  static String _formatLocale(Locale locale) {
    if (locale.countryCode != null && locale.countryCode!.isNotEmpty) {
      return '${locale.languageCode}_${locale.countryCode}';
    }
    return locale.languageCode;
  }
}
