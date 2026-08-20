import 'package:flutter/widgets.dart';
import 'package:golden_matrix/src/core/pairwise_generator.dart';
import 'package:golden_matrix/src/models/matrix_axes.dart';
import 'package:golden_matrix/src/models/matrix_combination.dart';
import 'package:golden_matrix/src/models/matrix_device.dart';
import 'package:golden_matrix/src/models/matrix_rule.dart';
import 'package:golden_matrix/src/models/matrix_sampling.dart';
import 'package:golden_matrix/src/models/matrix_scenario.dart';
import 'package:golden_matrix/src/models/matrix_theme.dart';

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
/// combination by [directionForLocale]: the locale's script subtag when it has
/// one, otherwise its language's default script. Override it either way —
/// `MatrixAxes.directionResolver` answers "which way does this locale read",
/// while an explicit `MatrixAxes.directions` list enumerates both directions
/// regardless of locale.
class MatrixGenerator {
  /// Generates a list of [MatrixCombination]s based on the given parameters.
  ///
  /// Pipeline: full Cartesian → exclude rules → includeOnly rules →
  /// sampling. When `axes.directions` is empty, text direction comes from
  /// `axes.directionResolver`, or [directionForLocale] when that is null.
  static List<MatrixCombination> generate({
    required List<MatrixScenario> scenarios,
    required MatrixAxes axes,
    MatrixSampling sampling = MatrixSampling.full,
    List<MatrixRule> rules = const [],
    int? maxCombinations,
  }) {
    // 0. Validate inputs. ArgumentError rather than assert: asserts vanish
    // outside debug builds and carry no argument context, and an invalid cap
    // used to surface as a RangeError from `sublist` far from its cause.
    _requireNotEmpty(scenarios, 'scenarios');
    _requireNotEmpty(axes.themes, 'axes.themes');
    _requireNotEmpty(axes.locales, 'axes.locales');
    _requireNotEmpty(axes.textScales, 'axes.textScales');
    _requireNotEmpty(axes.devices, 'axes.devices');

    for (final scale in axes.textScales) {
      if (!scale.isFinite || scale <= 0) {
        throw ArgumentError.value(
          scale,
          'axes.textScales',
          'text scales must be finite and > 0',
        );
      }
    }

    for (final device in axes.devices) {
      final size = device.logicalSize;
      if (!size.width.isFinite || !size.height.isFinite || size.width <= 0 || size.height <= 0) {
        throw ArgumentError.value(
          size,
          'axes.devices',
          'device "${device.name}" needs a finite logicalSize with width and height > 0',
        );
      }
    }

    if (maxCombinations != null && maxCombinations < 1) {
      throw ArgumentError.value(
        maxCombinations,
        'maxCombinations',
        'must be at least 1 — a capped run still has to produce a test',
      );
    }

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
      // A cap silently undoes what these two strategies were asked to do:
      // pairwise loses the all-pairs guarantee, and smoke drops the per-axis
      // deltas that are its entire content. `priorityBased` truncates by design
      // — that is what the cap is for — and `full` promises no reduction to
      // begin with, so capping it is a plain, explicit budget.
      switch (sampling) {
        case MatrixSampling.pairwise:
          debugPrint(
            'golden_matrix: maxCombinations ($maxCombinations) is below the '
            '${combinations.length} combinations pairwise needs here, so the '
            'truncated matrix no longer covers every pair. Raise the cap, or '
            'switch to MatrixSampling.priorityBased if a hard budget matters '
            'more than pair coverage.',
          );
        case MatrixSampling.smoke:
          debugPrint(
            'golden_matrix: maxCombinations ($maxCombinations) is below the '
            '${combinations.length} combinations smoke sampling produced, so '
            'some per-axis delta combinations are dropped. Raise the cap, or '
            'switch to MatrixSampling.priorityBased to choose what survives.',
          );
        case MatrixSampling.full:
        case MatrixSampling.priorityBased:
          break;
      }
      combinations = combinations.sublist(0, maxCombinations);
    }

    return combinations;
  }

  static void _requireNotEmpty(List<Object?> values, String name) {
    if (values.isEmpty) {
      throw ArgumentError.value(values, name, 'must not be empty');
    }
  }

  /// Scripts written right to left, by ISO 15924 code.
  ///
  /// Checked before the language, because a script subtag is the locale
  /// *saying* which way it reads: Azerbaijani in Arabic script is RTL even
  /// though `az` is not, and romanised Arabic (`ar-Latn`) is LTR even though
  /// `ar` is.
  static const _rtlScripts = {
    'Adlm', // Adlam
    'Arab', // Arabic
    'Aran', // Nastaliq
    'Hebr', // Hebrew
    'Mand', // Mandaic
    'Mend', // Mende Kikakui
    'Nkoo', // N'Ko
    'Rohg', // Hanifi Rohingya
    'Samr', // Samaritan
    'Syrc', // Syriac
    'Thaa', // Thaana
    'Yezi', // Yezidi
  };

  /// Languages whose default script is written right to left.
  ///
  /// Only consulted when the locale carries no script subtag.
  static const _rtlLanguages = {
    'ar', // Arabic
    'arc', // Aramaic
    'bal', // Baluchi
    'bgn', // Western Balochi
    'brh', // Brahui
    'ckb', // Central Kurdish (Sorani) — the Arabic-script Kurdish
    'dv', // Divehi
    'fa', // Persian
    'glk', // Gilaki
    'he', // Hebrew
    'iw', // Hebrew, legacy code
    'ji', // Yiddish, legacy code
    'khw', // Khowar
    'ks', // Kashmiri
    'lrc', // Northern Luri
    'mzn', // Mazanderani
    'nqo', // N'Ko
    'prs', // Dari
    'ps', // Pashto
    'sd', // Sindhi
    'sdh', // Southern Kurdish
    'syr', // Syriac
    'ug', // Uyghur
    'ur', // Urdu
    'yi', // Yiddish
  };

  /// Returns the text direction for a given locale.
  ///
  /// The script subtag wins when present; otherwise the language's default
  /// script decides. This used to be seven hardcoded language codes with
  /// `scriptCode` ignored outright, which got two things wrong at once:
  /// Sindhi, Uyghur, Divehi, Sorani Kurdish, Syriac and N'Ko were laid out
  /// left to right — a mirrored screenshot that passed as correct — while
  /// `ku` was forced right to left even though Kurmanji Kurdish, which is
  /// what `ku` means, is written in the Latin alphabet.
  static TextDirection directionForLocale(Locale locale) {
    final script = locale.scriptCode;
    if (script != null) {
      return _rtlScripts.contains(script) ? TextDirection.rtl : TextDirection.ltr;
    }
    return _rtlLanguages.contains(locale.languageCode) ? TextDirection.rtl : TextDirection.ltr;
  }

  /// The direction of [locale] under [axes] — the caller's resolver when it
  /// supplied one, otherwise [directionForLocale].
  static TextDirection _directionFor(MatrixAxes axes, Locale locale) =>
      (axes.directionResolver ?? directionForLocale)(locale);

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
                final direction = _directionFor(axes, locale);
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
      final baseDirection =
          axes.directions.isEmpty ? _directionFor(axes, baseLocale) : axes.directions.first;

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
        final altDir = axes.directions.isEmpty ? _directionFor(axes, altLocale) : baseDirection;
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
      (a, b) => (a.logicalSize.width * a.logicalSize.height) <=
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
      final isNonFirstDevice = c.device != firstDevice;

      if (isDark && isLargeText) s += 3;
      if (isRtl && isSmallestDevice) s += 3;
      if (isNonFirstLocale && isNonFirstDevice) s += 2;
      if (isDark) s += 1;
      if (isLargeText) s += 1;
      return s;
    }

    // `List.sort` is not guaranteed to be stable — Dart only sorts stably below
    // 32 elements — so equal scores must be broken by the declared order
    // explicitly. Without it, which combinations survive `maxCombinations`
    // depends on the matrix size and the SDK's sort implementation.
    final indexed = [
      for (var i = 0; i < combinations.length; i++)
        (index: i, score: score(combinations[i]), combination: combinations[i]),
    ];
    indexed.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.index.compareTo(b.index);
    });
    final scored = [for (final e in indexed) e.combination];

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

      // When rules left the feasible set sparse, the abstract covering array
      // addresses tuples that no longer exist, and mapping back would silently
      // drop them along with the pairs they were covering. Select greedily over
      // the surviving combinations instead. The full-Cartesian case keeps going
      // through PairwiseGenerator below, so golden names stay unchanged for
      // matrices whose rules are axis-aligned (or absent).
      final feasibleTupleCount = paramSizes.fold(1, (a, b) => a * b);
      if (scenarioCombos.length < feasibleTupleCount) {
        result.addAll(
          _constraintAwarePairwise(
            scenarioCombos,
            activeParams,
            themes: themes,
            locales: locales,
            textScales: textScales,
            devices: devices,
            directions: directions,
          ),
        );
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
        final direction = directionIsParam ? directions[directionIdx] : _directionFor(axes, locale);

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

  /// Pairwise selection over a sparse feasible set.
  ///
  /// Builds the set of pairs that actually occur in [combos], then greedily
  /// picks the combination covering the most still-uncovered pairs until every
  /// feasible pair is covered. Ties are broken by the original order of
  /// [combos], so the result is deterministic.
  ///
  /// [activeParams] are the axis indices with more than one surviving value,
  /// in the same encoding used by [_applyPairwiseSampling]: 0 theme, 1 locale,
  /// 2 textScale, 3 device, 4 direction.
  static List<MatrixCombination> _constraintAwarePairwise(
    List<MatrixCombination> combos,
    List<int> activeParams, {
    required List<MatrixTheme> themes,
    required List<Locale> locales,
    required List<double> textScales,
    required List<MatrixDevice> devices,
    required List<TextDirection> directions,
  }) {
    int valueIndex(MatrixCombination c, int axis) => switch (axis) {
          0 => themes.indexOf(c.theme),
          1 => locales.indexOf(c.locale),
          2 => textScales.indexOf(c.textScale),
          3 => devices.indexOf(c.device),
          _ => directions.indexOf(c.direction),
        };

    // Index vector per combination, one entry per active axis.
    final vectors = [
      for (final c in combos) [for (final axis in activeParams) valueIndex(c, axis)],
    ];

    String pairKey(int i, int vi, int j, int vj) => '$i:$vi|$j:$vj';

    final uncovered = <String>{};
    for (final v in vectors) {
      for (var i = 0; i < v.length; i++) {
        for (var j = i + 1; j < v.length; j++) {
          uncovered.add(pairKey(i, v[i], j, v[j]));
        }
      }
    }

    final selected = <MatrixCombination>[];
    final candidates = List<int>.generate(combos.length, (i) => i);

    while (uncovered.isNotEmpty) {
      var bestIdx = -1;
      var bestScore = 0;

      for (final idx in candidates) {
        final v = vectors[idx];
        var score = 0;
        for (var i = 0; i < v.length; i++) {
          for (var j = i + 1; j < v.length; j++) {
            if (uncovered.contains(pairKey(i, v[i], j, v[j]))) score++;
          }
        }
        if (score > bestScore) {
          bestScore = score;
          bestIdx = idx;
        }
      }

      // No remaining combination covers anything new: every reachable pair is
      // already covered and the rest of `uncovered` is unreachable.
      if (bestIdx < 0) break;

      final v = vectors[bestIdx];
      for (var i = 0; i < v.length; i++) {
        for (var j = i + 1; j < v.length; j++) {
          uncovered.remove(pairKey(i, v[i], j, v[j]));
        }
      }
      selected.add(combos[bestIdx]);
      candidates.remove(bestIdx);
    }

    return selected;
  }
}
