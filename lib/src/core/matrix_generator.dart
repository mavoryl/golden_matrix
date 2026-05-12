import 'package:flutter/widgets.dart';

import '../models/matrix_axes.dart';
import '../models/matrix_combination.dart';
import '../models/matrix_device.dart';
import '../models/matrix_rule.dart';
import '../models/matrix_sampling.dart';
import '../models/matrix_scenario.dart';
import '../models/matrix_theme.dart';
import 'pairwise_generator.dart';

/// Generates all combinations from scenarios and axes.
///
/// [MatrixGenerator] is the pure-logic core of the package. It takes a
/// list of [MatrixScenario]s and a [MatrixAxes] definition, then
/// produces the list of [MatrixCombination]s that the test runner will
/// render.
///
/// ## Pipeline
///
/// 1. **Full Cartesian product** — every scenario × theme × locale ×
///    textScale × device × direction is enumerated.
/// 2. **Exclude rules** — every [MatrixRule] of type
///    [MatrixRuleType.exclude] drops matching combinations.
/// 3. **IncludeOnly rules** — every [MatrixRule] of type
///    [MatrixRuleType.includeOnly] keeps only matching combinations.
/// 4. **Sampling** — the chosen [MatrixSampling] strategy reduces the
///    remaining set ([MatrixSampling.full] is a no-op).
///
/// ## Direction inference
///
/// When `axes.directions` is empty, [TextDirection] is inferred per
/// combination from the locale's language code: `ar`, `he`, `fa`, `ur`,
/// `ps`, `ku`, and `yi` are mapped to [TextDirection.rtl]; everything
/// else to [TextDirection.ltr]. Pass an explicit `directions` list on
/// [MatrixAxes] to override this behavior.
class MatrixGenerator {
  /// Generates a list of [MatrixCombination]s based on the given parameters.
  ///
  /// Pipeline: full Cartesian → exclude rules → includeOnly rules →
  /// sampling. When `axes.directions` is empty, text direction is
  /// inferred from each locale (RTL for `ar`, `he`, `fa`, `ur`, `ps`,
  /// `ku`, `yi`; LTR otherwise).
  static List<MatrixCombination> generate({
    required List<MatrixScenario> scenarios,
    required MatrixAxes axes,
    MatrixSampling sampling = MatrixSampling.full,
    List<MatrixRule> rules = const [],
    int? maxCombinations,
  }) {
    // 0. Validate inputs
    assert(scenarios.isNotEmpty, 'scenarios must not be empty');
    assert(axes.themes.isNotEmpty, 'axes.themes must not be empty');
    assert(axes.locales.isNotEmpty, 'axes.locales must not be empty');
    assert(axes.textScales.isNotEmpty, 'axes.textScales must not be empty');
    assert(axes.devices.isNotEmpty, 'axes.devices must not be empty');

    // 1. Generate full Cartesian product
    var combinations = _generateCartesian(scenarios, axes);

    // 2. Apply exclude rules
    for (final rule in rules.where((r) => r.type == MatrixRuleType.exclude)) {
      combinations = combinations.where((c) => !rule.predicate(c)).toList();
    }

    // 3. Apply includeOnly rules
    for (final rule in rules.where((r) => r.type == MatrixRuleType.includeOnly)) {
      combinations = combinations.where((c) => rule.predicate(c)).toList();
    }

    // 4. Apply sampling strategy
    switch (sampling) {
      case MatrixSampling.full:
        break;
      case MatrixSampling.smoke:
        combinations = _applySmokeSampling(combinations, axes);
      case MatrixSampling.priorityBased:
        combinations = _applyPriorityBased(combinations, axes, maxCombinations);
      case MatrixSampling.pairwise:
        combinations = _applyPairwiseSampling(combinations, axes);
    }

    // 5. Apply maxCombinations as a global cap for any strategy.
    // (priorityBased already truncates internally, but reapply for consistency.)
    if (maxCombinations != null && combinations.length > maxCombinations) {
      combinations = combinations.sublist(0, maxCombinations);
    }

    return combinations;
  }

  /// Returns the text direction for a given locale.
  static TextDirection directionForLocale(Locale locale) {
    const rtlLanguages = {'ar', 'he', 'fa', 'ur', 'ps', 'ku', 'yi'};
    return rtlLanguages.contains(locale.languageCode) ? TextDirection.rtl : TextDirection.ltr;
  }

  // -- Private helpers --

  static List<MatrixCombination> _generateCartesian(
    List<MatrixScenario> scenarios,
    MatrixAxes axes,
  ) {
    final combinations = <MatrixCombination>[];

    for (final scenario in scenarios) {
      for (final theme in axes.themes) {
        for (final locale in axes.locales) {
          for (final textScale in axes.textScales) {
            for (final device in axes.devices) {
              if (axes.directions.isEmpty) {
                final direction = directionForLocale(locale);
                combinations.add(
                  MatrixCombination(
                    scenario: scenario,
                    theme: theme,
                    locale: locale,
                    textScale: textScale,
                    device: device,
                    direction: direction,
                  ),
                );
              } else {
                for (final direction in axes.directions) {
                  combinations.add(
                    MatrixCombination(
                      scenario: scenario,
                      theme: theme,
                      locale: locale,
                      textScale: textScale,
                      device: device,
                      direction: direction,
                    ),
                  );
                }
              }
            }
          }
        }
      }
    }

    return combinations;
  }

  /// Smoke sampling: per scenario, pick a base combo + one delta per axis.
  ///
  /// Base combo uses first value from each axis (first theme, first locale,
  /// first textScale, first device). Then for each axis that has >1 value,
  /// adds one combo with a non-default value for that axis only.
  ///
  /// Result: ~(1 + number of multi-value axes) combinations per scenario.
  static List<MatrixCombination> _applySmokeSampling(
    List<MatrixCombination> combinations,
    MatrixAxes axes,
  ) {
    if (combinations.isEmpty) return combinations;

    final result = <MatrixCombination>[];

    // Group by scenario
    final byScenario = <String, List<MatrixCombination>>{};
    for (final c in combinations) {
      (byScenario[c.scenario.name] ??= []).add(c);
    }

    for (final scenarioCombos in byScenario.values) {
      if (scenarioCombos.isEmpty) continue;

      // Base values: first from each axis
      final baseTheme = axes.themes.first;
      final baseLocale = axes.locales.first;
      final baseTextScale = axes.textScales.first;
      final baseDevice = axes.devices.first;
      final baseDirection = axes.directions.isEmpty
          ? directionForLocale(baseLocale)
          : axes.directions.first;

      // Find the base combination
      final base = scenarioCombos.where(
        (c) =>
            c.theme == baseTheme &&
            c.locale == baseLocale &&
            c.textScale == baseTextScale &&
            c.device == baseDevice &&
            c.direction == baseDirection,
      );

      if (base.isNotEmpty) {
        result.add(base.first);
      } else if (scenarioCombos.isNotEmpty) {
        result.add(scenarioCombos.first);
      }

      final scenario = scenarioCombos.first.scenario;

      // Delta: one combo per axis with >1 value, changing only that axis
      if (axes.themes.length > 1) {
        final altTheme = axes.themes.firstWhere((t) => t != baseTheme, orElse: () => baseTheme);
        _addDelta(
          result,
          scenarioCombos,
          scenario,
          altTheme,
          baseLocale,
          baseTextScale,
          baseDevice,
          baseDirection,
        );
      }

      if (axes.locales.length > 1) {
        final altLocale = axes.locales.firstWhere((l) => l != baseLocale, orElse: () => baseLocale);
        final altDir = axes.directions.isEmpty ? directionForLocale(altLocale) : baseDirection;
        _addDelta(
          result,
          scenarioCombos,
          scenario,
          baseTheme,
          altLocale,
          baseTextScale,
          baseDevice,
          altDir,
        );
      }

      if (axes.textScales.length > 1) {
        // Pick the largest non-default scale
        final altScale = axes.textScales
            .where((s) => s != baseTextScale)
            .fold<double>(baseTextScale, (a, b) => b > a ? b : a);
        _addDelta(
          result,
          scenarioCombos,
          scenario,
          baseTheme,
          baseLocale,
          altScale,
          baseDevice,
          baseDirection,
        );
      }

      if (axes.devices.length > 1) {
        final altDevice = axes.devices.firstWhere((d) => d != baseDevice, orElse: () => baseDevice);
        _addDelta(
          result,
          scenarioCombos,
          scenario,
          baseTheme,
          baseLocale,
          baseTextScale,
          altDevice,
          baseDirection,
        );
      }

      if (axes.directions.length > 1) {
        final altDir = axes.directions.firstWhere(
          (d) => d != baseDirection,
          orElse: () => baseDirection,
        );
        _addDelta(
          result,
          scenarioCombos,
          scenario,
          baseTheme,
          baseLocale,
          baseTextScale,
          baseDevice,
          altDir,
        );
      }
    }

    return result;
  }

  static void _addDelta(
    List<MatrixCombination> result,
    List<MatrixCombination> pool,
    MatrixScenario scenario,
    MatrixTheme theme,
    Locale locale,
    double textScale,
    MatrixDevice device,
    TextDirection direction,
  ) {
    final match = pool.where(
      (c) =>
          c.scenario == scenario &&
          c.theme == theme &&
          c.locale == locale &&
          c.textScale == textScale &&
          c.device == device &&
          c.direction == direction,
    );
    if (match.isNotEmpty &&
        !result.any(
          (r) =>
              r.scenario == match.first.scenario &&
              r.theme == match.first.theme &&
              r.locale == match.first.locale &&
              r.textScale == match.first.textScale &&
              r.device == match.first.device &&
              r.direction == match.first.direction,
        )) {
      result.add(match.first);
    }
  }

  /// Priority-based sampling: score each combination and take the top N.
  ///
  /// Scoring:
  /// - +3 if dark theme AND textScale > 1.0
  /// - +3 if RTL direction AND smallest device
  /// - +2 if non-first locale AND non-first device
  /// - +1 if dark theme alone
  /// - +1 if non-default textScale alone
  static List<MatrixCombination> _applyPriorityBased(
    List<MatrixCombination> combinations,
    MatrixAxes axes,
    int? maxCombinations,
  ) {
    if (combinations.isEmpty) return combinations;

    final firstLocale = axes.locales.first;
    final firstDevice = axes.devices.first;

    // Find the smallest device by area
    final smallestDevice = axes.devices.reduce(
      (a, b) =>
          (a.logicalSize.width * a.logicalSize.height) <=
              (b.logicalSize.width * b.logicalSize.height)
          ? a
          : b,
    );

    int score(MatrixCombination c) {
      var s = 0;
      final isDark = c.theme.isDark;
      final isLargeText = c.textScale > 1.0;
      final isRtl = c.direction == TextDirection.rtl;
      final isSmallestDevice = c.device == smallestDevice;
      final isNonFirstLocale = c.locale != firstLocale;
      final isNonFirstDevice = c.device.name != firstDevice.name;

      if (isDark && isLargeText) s += 3;
      if (isRtl && isSmallestDevice) s += 3;
      if (isNonFirstLocale && isNonFirstDevice) s += 2;
      if (isDark) s += 1;
      if (isLargeText) s += 1;
      return s;
    }

    final scored = combinations.toList()..sort((a, b) => score(b).compareTo(score(a)));

    if (maxCombinations != null && scored.length > maxCombinations) {
      return scored.sublist(0, maxCombinations);
    }

    return scored;
  }

  /// Pairwise sampling: covers all pairs of parameter values.
  ///
  /// Converts axes into abstract parameters, runs the greedy pairwise
  /// algorithm, then maps results back to [MatrixCombination]s.
  static List<MatrixCombination> _applyPairwiseSampling(
    List<MatrixCombination> combinations,
    MatrixAxes axes,
  ) {
    if (combinations.isEmpty) return combinations;

    // Group by scenario — pairwise covers axis pairs, scenarios are separate
    final byScenario = <String, List<MatrixCombination>>{};
    for (final c in combinations) {
      (byScenario[c.scenario.name] ??= []).add(c);
    }

    final result = <MatrixCombination>[];

    // Derive pairwise domain per scenario from feasible combinations
    // (after rules), not from raw axes. This preserves pairwise coverage
    // guarantees over the actual runnable set.
    for (final entry in byScenario.entries) {
      final scenarioCombos = entry.value;
      if (scenarioCombos.isEmpty) continue;

      // Collect unique surviving values per axis from this scenario's combos
      final themes = <MatrixTheme>[];
      final locales = <Locale>[];
      final textScales = <double>[];
      final devices = <MatrixDevice>[];
      final directions = <TextDirection>[];

      for (final c in scenarioCombos) {
        if (!themes.contains(c.theme)) themes.add(c.theme);
        if (!locales.contains(c.locale)) locales.add(c.locale);
        if (!textScales.contains(c.textScale)) textScales.add(c.textScale);
        if (!devices.contains(c.device)) devices.add(c.device);
        if (!directions.contains(c.direction)) directions.add(c.direction);
      }

      // Direction is treated as an independent pairwise parameter only when
      // it was an explicit axis. Otherwise it is derived from locale and
      // would generate infeasible (locale, direction) pairs.
      final directionIsParam = axes.directions.isNotEmpty;

      // Build parameter sizes from feasible domain
      final paramSizes = [
        themes.length,
        locales.length,
        textScales.length,
        devices.length,
        if (directionIsParam) directions.length else 1,
      ];

      // Remove single-value parameters (no pairs to cover)
      final activeParams = <int>[];
      final activeParamSizes = <int>[];
      for (var i = 0; i < paramSizes.length; i++) {
        if (paramSizes[i] > 1) {
          activeParams.add(i);
          activeParamSizes.add(paramSizes[i]);
        }
      }

      // If 0 or 1 multi-value params, pairwise = full for this scenario
      if (activeParamSizes.length <= 1) {
        result.addAll(scenarioCombos);
        continue;
      }

      final testCases = PairwiseGenerator.generate(activeParamSizes);

      for (final testCase in testCases) {
        var themeIdx = 0;
        var localeIdx = 0;
        var textScaleIdx = 0;
        var deviceIdx = 0;
        var directionIdx = 0;

        for (var i = 0; i < activeParams.length; i++) {
          switch (activeParams[i]) {
            case 0:
              themeIdx = testCase[i];
            case 1:
              localeIdx = testCase[i];
            case 2:
              textScaleIdx = testCase[i];
            case 3:
              deviceIdx = testCase[i];
            case 4:
              directionIdx = testCase[i];
          }
        }

        final theme = themes[themeIdx];
        final locale = locales[localeIdx];
        final textScale = textScales[textScaleIdx];
        final device = devices[deviceIdx];

        // When direction is not a pairwise parameter, it's derived from locale.
        final direction = directionIsParam ? directions[directionIdx] : directionForLocale(locale);

        final match = scenarioCombos.where(
          (c) =>
              c.theme == theme &&
              c.locale == locale &&
              c.textScale == textScale &&
              c.device == device &&
              c.direction == direction,
        );

        if (match.isNotEmpty) {
          result.add(match.first);
        }
      }
    }

    return result;
  }
}
