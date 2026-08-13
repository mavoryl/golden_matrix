import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

void main() {
  Widget placeholder() => const SizedBox();

  group('MatrixGenerator smoke sampling', () {
    test('reduces 2×2×2×2 to ~5 per scenario', () {
      final combinations = MatrixGenerator.generate(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: const MatrixAxes(
          themes: [MatrixTheme.light, MatrixTheme.dark],
          locales: [Locale('en'), Locale('ar')],
          textScales: [1.0, 2.0],
          devices: [MatrixDevice.phoneSmall, MatrixDevice.tablet],
        ),
        sampling: MatrixSampling.smoke,
      );

      // Full would be 16. Smoke: 1 base + 4 deltas = 5
      expect(combinations.length, lessThanOrEqualTo(6));
      expect(combinations.length, greaterThanOrEqualTo(3));
    });

    test('with single-value axes produces 1 per scenario', () {
      final combinations = MatrixGenerator.generate(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: const MatrixAxes(),
        sampling: MatrixSampling.smoke,
      );

      expect(combinations.length, 1);
    });

    test('scales with number of scenarios', () {
      final combinations = MatrixGenerator.generate(
        scenarios: [
          MatrixScenario('a', builder: placeholder),
          MatrixScenario('b', builder: placeholder),
          MatrixScenario('c', builder: placeholder),
        ],
        axes: const MatrixAxes(
          themes: [MatrixTheme.light, MatrixTheme.dark],
          locales: [Locale('en'), Locale('ru')],
        ),
        sampling: MatrixSampling.smoke,
      );

      // 3 scenarios × ~3 combos each (base + theme delta + locale delta)
      expect(combinations.length, greaterThanOrEqualTo(6));
      expect(combinations.length, lessThanOrEqualTo(12));
    });

    test('always includes base combination per scenario', () {
      final combinations = MatrixGenerator.generate(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: const MatrixAxes(
          themes: [MatrixTheme.light, MatrixTheme.dark],
          locales: [Locale('en'), Locale('ar')],
        ),
        sampling: MatrixSampling.smoke,
      );

      // Base should be first theme + first locale
      final hasBase = combinations.any(
        (c) => c.theme.name == 'light' && c.locale == const Locale('en'),
      );
      expect(hasBase, isTrue);
    });

    test('includes dark theme delta when available', () {
      final combinations = MatrixGenerator.generate(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
        sampling: MatrixSampling.smoke,
      );

      final hasDark = combinations.any((c) => c.theme.name == 'dark');
      expect(hasDark, isTrue);
    });
  });

  group('MatrixGenerator priorityBased sampling', () {
    test('returns all combinations sorted by priority', () {
      final combinations = MatrixGenerator.generate(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: const MatrixAxes(
          themes: [MatrixTheme.light, MatrixTheme.dark],
          textScales: [1.0, 2.0],
        ),
        sampling: MatrixSampling.priorityBased,
      );

      // All 4 combos returned but sorted
      expect(combinations.length, 4);
      // Dark + 2.0x should be first (highest priority)
      expect(combinations.first.theme.name, 'dark');
      expect(combinations.first.textScale, 2.0);
    });

    test('maxCombinations truncates result', () {
      final combinations = MatrixGenerator.generate(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: const MatrixAxes(
          themes: [MatrixTheme.light, MatrixTheme.dark],
          locales: [Locale('en'), Locale('ar')],
          textScales: [1.0, 2.0],
          devices: [MatrixDevice.phoneSmall, MatrixDevice.tablet],
        ),
        sampling: MatrixSampling.priorityBased,
        maxCombinations: 5,
      );

      expect(combinations.length, 5);
    });

    test('dark+largeText gets high priority', () {
      final combinations = MatrixGenerator.generate(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: const MatrixAxes(
          themes: [MatrixTheme.light, MatrixTheme.dark],
          textScales: [1.0, 2.0],
        ),
        sampling: MatrixSampling.priorityBased,
      );

      // dark + 2.0x has score 3+1+1=5, should be first
      final first = combinations.first;
      expect(first.theme.name, 'dark');
      expect(first.textScale, 2.0);
    });
  });

  group('MatrixGenerator includeOnly rules', () {
    test('keeps only matching combinations', () {
      final combinations = MatrixGenerator.generate(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
        rules: [MatrixRule.includeOnly((c) => c.theme.name == 'dark')],
      );

      expect(combinations.length, 1);
      expect(combinations.first.theme.name, 'dark');
    });

    test('includeOnly applied after exclude', () {
      final combinations = MatrixGenerator.generate(
        scenarios: [
          MatrixScenario('a', builder: placeholder),
          MatrixScenario('b', builder: placeholder),
        ],
        axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
        rules: [
          MatrixRule.exclude((c) => c.scenario.name == 'b'),
          MatrixRule.includeOnly((c) => c.theme.name == 'dark'),
        ],
      );

      expect(combinations.length, 1);
      expect(combinations.first.scenario.name, 'a');
      expect(combinations.first.theme.name, 'dark');
    });
  });

  group('MatrixGenerator warns when a cap breaks pairwise coverage', () {
    late DebugPrintCallback savedPrint;
    late List<String> printed;

    setUp(() {
      printed = [];
      savedPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) printed.add(message);
      };
    });

    tearDown(() => debugPrint = savedPrint);

    const axes = MatrixAxes(
      themes: [MatrixTheme.light, MatrixTheme.dark],
      locales: [Locale('en'), Locale('fr')],
      textScales: [1.0, 1.5],
      devices: [MatrixDevice.phoneSmall, MatrixDevice.tablet],
    );

    List<MatrixCombination> generate({int? cap, MatrixSampling? sampling}) =>
        MatrixGenerator.generate(
          scenarios: [MatrixScenario('test', builder: placeholder)],
          axes: axes,
          sampling: sampling ?? MatrixSampling.pairwise,
          maxCombinations: cap,
        );

    test('a cap below the covering array is reported, not applied in silence', () {
      // The global cap slices the finished pairwise set, so the guarantee the
      // strategy exists for is gone — silently, with a green CI.
      final uncapped = generate();
      expect(uncapped.length, greaterThan(3));

      final capped = generate(cap: 3);

      expect(capped.length, 3);
      expect(
        printed.join('\n'),
        allOf(
          contains('golden_matrix'),
          contains('pairwise'),
          contains('${uncapped.length}'),
          contains('3'),
        ),
      );
    });

    test('a cap at or above the covering array stays quiet', () {
      final uncapped = generate();

      final capped = generate(cap: uncapped.length);

      expect(capped.length, uncapped.length);
      expect(printed, isEmpty);
    });

    test('priorityBased and full are not warned about — their caps are meaningful', () {
      generate(cap: 2, sampling: MatrixSampling.priorityBased);
      generate(cap: 2, sampling: MatrixSampling.full);

      expect(printed, isEmpty);
    });

    test('a cap that eats smoke deltas is reported too', () {
      // Smoke is base + one delta per axis; truncating it drops the deltas,
      // which is the only thing smoke sampling is there to produce.
      final uncapped = generate(sampling: MatrixSampling.smoke);
      expect(uncapped.length, greaterThan(2));

      generate(cap: 2, sampling: MatrixSampling.smoke);

      expect(printed.join('\n'), allOf(contains('golden_matrix'), contains('smoke')));
    });
  });

  group('MatrixGenerator priorityBased is order-stable', () {
    // `List.sort` is explicitly not guaranteed to be stable, and Dart only
    // happens to be stable below 32 elements (insertion sort). Above that the
    // relative order of equal-priority combinations scrambles, so which ones
    // survive `maxCombinations` depends on the matrix size and on the SDK's
    // sort implementation rather than on the declared axis order.
    const axes = MatrixAxes(
      themes: [MatrixTheme.light, MatrixTheme.dark],
      // 'de' and 'fr' are both non-first and both LTR, so for a fixed
      // theme/scale/device they always score identically.
      locales: [Locale('en'), Locale('ru'), Locale('ar'), Locale('de'), Locale('fr')],
      textScales: [1.0, 1.5, 2.0],
      devices: [MatrixDevice.phoneSmall, MatrixDevice.phoneMedium, MatrixDevice.tablet],
    );

    List<MatrixCombination> generate(MatrixSampling sampling) => MatrixGenerator.generate(
          scenarios: [MatrixScenario('test', builder: placeholder)],
          axes: axes,
          sampling: sampling,
        );

    test('equal-priority combinations keep their declared order', () {
      final full = generate(MatrixSampling.full);
      final prioritized = generate(MatrixSampling.priorityBased);

      expect(full.length, 90, reason: 'needs to exceed the 32-element stable-sort threshold');
      expect(prioritized.length, full.length);

      String key(MatrixCombination c) =>
          '${c.theme.name}/${c.locale}/${c.textScale}/${c.device.name}';
      final rank = {
        for (var i = 0; i < prioritized.length; i++) key(prioritized[i]): i,
      };

      // For every (theme, scale, device), 'de' must still come before 'fr'.
      for (final theme in axes.themes) {
        for (final scale in axes.textScales) {
          for (final device in axes.devices) {
            final de = rank['${theme.name}/de/$scale/${device.name}']!;
            final fr = rank['${theme.name}/fr/$scale/${device.name}']!;
            expect(
              de,
              lessThan(fr),
              reason: 'de must precede fr for ${theme.name}/$scale/${device.name}',
            );
          }
        }
      }
    });

    test('the same matrix always yields the same truncated selection', () {
      final first = MatrixGenerator.generate(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: axes,
        sampling: MatrixSampling.priorityBased,
        maxCombinations: 12,
      );
      final second = MatrixGenerator.generate(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: axes,
        sampling: MatrixSampling.priorityBased,
        maxCombinations: 12,
      );

      expect(
        first.map((c) => '${c.theme.name}/${c.locale}/${c.textScale}/${c.device.name}').toList(),
        second.map((c) => '${c.theme.name}/${c.locale}/${c.textScale}/${c.device.name}').toList(),
      );
    });
  });

  group('MatrixGenerator pairwise + rules (regression)', () {
    test('pairwise derives domain from filtered combinations', () {
      // 3 themes but rule excludes one — pairwise should pair only the 2 remaining.
      final brand = MatrixTheme.custom('brand', ThemeData.light());
      final combinations = MatrixGenerator.generate(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: MatrixAxes(
          themes: [MatrixTheme.light, MatrixTheme.dark, brand],
          locales: const [Locale('en'), Locale('ar')],
        ),
        rules: [MatrixRule.exclude((c) => c.theme == brand)],
        sampling: MatrixSampling.pairwise,
      );

      // No 'brand' should remain.
      expect(combinations.any((c) => c.theme == brand), isFalse);

      // All pairs of (theme, locale) over the feasible set should be covered.
      final pairs = combinations.map((c) => '${c.theme.name}_${c.locale}').toSet();
      expect(pairs, contains('light_en'));
      expect(pairs, contains('light_ar'));
      expect(pairs, contains('dark_en'));
      expect(pairs, contains('dark_ar'));
    });

    test('pairwise after includeOnly covers reduced domain', () {
      final combinations = MatrixGenerator.generate(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: const MatrixAxes(
          themes: [MatrixTheme.light, MatrixTheme.dark],
          locales: [Locale('en'), Locale('ru'), Locale('ar')],
          devices: [MatrixDevice.phoneSmall, MatrixDevice.tablet],
        ),
        rules: [MatrixRule.includeOnly((c) => c.locale.languageCode != 'ru')],
        sampling: MatrixSampling.pairwise,
      );

      // 'ru' must not appear after includeOnly.
      expect(combinations.any((c) => c.locale.languageCode == 'ru'), isFalse);

      // All pairs over remaining domain.
      final tlPairs = combinations.map((c) => '${c.theme.name}_${c.locale}').toSet();
      expect(tlPairs, contains('light_en'));
      expect(tlPairs, contains('light_ar'));
      expect(tlPairs, contains('dark_en'));
      expect(tlPairs, contains('dark_ar'));
    });
  });

  group('MatrixGenerator pairwise under correlated rules', () {
    // The rules above are axis-aligned: they delete a whole axis value, so the
    // per-axis domains still describe the feasible set exactly. These rules are
    // correlated instead — every axis value survives, but only a sparse set of
    // tuples is feasible. That is where deriving domains independently and
    // dropping non-existent tuples silently loses coverage.

    test('covers every feasible pair when themes and locales are correlated', () {
      // dark only with en, light only with fr.
      final combinations = MatrixGenerator.generate(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: const MatrixAxes(
          themes: [MatrixTheme.light, MatrixTheme.dark],
          locales: [Locale('en'), Locale('fr')],
          textScales: [1.0, 1.5],
        ),
        rules: [
          MatrixRule.includeOnly(
            (c) =>
                (c.theme.isDark && c.locale.languageCode == 'en') ||
                (!c.theme.isDark && c.locale.languageCode == 'fr'),
          ),
        ],
        sampling: MatrixSampling.pairwise,
      );

      final themeScale = combinations.map((c) => '${c.theme.name}_${c.textScale}').toSet();
      expect(themeScale, contains('light_1.0'));
      expect(themeScale, contains('light_1.5'));
      expect(themeScale, contains('dark_1.0'));
      expect(themeScale, contains('dark_1.5'));

      final localeScale =
          combinations.map((c) => '${c.locale.languageCode}_${c.textScale}').toSet();
      expect(localeScale, contains('en_1.0'));
      expect(localeScale, contains('en_1.5'));
      expect(localeScale, contains('fr_1.0'));
      expect(localeScale, contains('fr_1.5'));
    });

    test('keeps every survivor when no combination is redundant', () {
      // Only two tuples survive; neither shares an axis value with the other,
      // so both are required to cover the feasible pairs.
      final combinations = MatrixGenerator.generate(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: const MatrixAxes(
          themes: [MatrixTheme.light, MatrixTheme.dark],
          locales: [Locale('en'), Locale('fr')],
          textScales: [1.0, 1.5],
        ),
        rules: [
          MatrixRule.includeOnly(
            (c) =>
                (c.theme.isDark && c.locale.languageCode == 'fr' && c.textScale == 1.0) ||
                (!c.theme.isDark && c.locale.languageCode == 'en' && c.textScale == 1.5),
          ),
        ],
        sampling: MatrixSampling.pairwise,
      );

      expect(combinations.length, 2);
    });

    test('covers every feasible pair when themes and devices are correlated', () {
      // dark ships only on tablet, light only on phoneSmall.
      final combinations = MatrixGenerator.generate(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: const MatrixAxes(
          themes: [MatrixTheme.light, MatrixTheme.dark],
          locales: [Locale('en'), Locale('fr')],
          devices: [MatrixDevice.phoneSmall, MatrixDevice.tablet],
        ),
        rules: [
          MatrixRule.includeOnly(
            (c) => c.theme.isDark
                ? c.device == MatrixDevice.tablet
                : c.device == MatrixDevice.phoneSmall,
          ),
        ],
        sampling: MatrixSampling.pairwise,
      );

      final deviceLocale =
          combinations.map((c) => '${c.device.name}_${c.locale.languageCode}').toSet();
      expect(deviceLocale, contains('phoneSmall_en'));
      expect(deviceLocale, contains('phoneSmall_fr'));
      expect(deviceLocale, contains('tablet_en'));
      expect(deviceLocale, contains('tablet_fr'));
    });

    test('covers every feasible pair when an explicit direction axis is correlated', () {
      // rtl only for ar, ltr only for en — direction is an explicit axis here,
      // so it takes part in pairing.
      final combinations = MatrixGenerator.generate(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: const MatrixAxes(
          themes: [MatrixTheme.light, MatrixTheme.dark],
          locales: [Locale('en'), Locale('ar')],
          directions: [TextDirection.ltr, TextDirection.rtl],
        ),
        rules: [
          MatrixRule.includeOnly(
            (c) => c.locale.languageCode == 'ar'
                ? c.direction == TextDirection.rtl
                : c.direction == TextDirection.ltr,
          ),
        ],
        sampling: MatrixSampling.pairwise,
      );

      final directionTheme = combinations.map((c) => '${c.direction.name}_${c.theme.name}').toSet();
      expect(directionTheme, contains('ltr_light'));
      expect(directionTheme, contains('ltr_dark'));
      expect(directionTheme, contains('rtl_light'));
      expect(directionTheme, contains('rtl_dark'));
    });

    test('covers every feasible pair for all 255 rule subsets of a 2×2×2 matrix', () {
      const axes = MatrixAxes(
        themes: [MatrixTheme.light, MatrixTheme.dark],
        locales: [Locale('en'), Locale('fr')],
        textScales: [1.0, 1.5],
      );

      // Encodes a combination as a bit triple so a rule can allow an arbitrary
      // subset of the 8 tuples.
      int tupleBits(MatrixCombination c) =>
          (c.theme.isDark ? 1 : 0) |
          (c.locale.languageCode == 'fr' ? 2 : 0) |
          (c.textScale > 1.0 ? 4 : 0);

      Set<String> pairsOf(Iterable<MatrixCombination> combos) {
        final pairs = <String>{};
        for (final c in combos) {
          final v = [c.theme.isDark, c.locale.languageCode == 'fr', c.textScale > 1.0];
          for (var i = 0; i < v.length; i++) {
            for (var j = i + 1; j < v.length; j++) {
              pairs.add('$i=${v[i]},$j=${v[j]}');
            }
          }
        }
        return pairs;
      }

      for (var mask = 1; mask < 256; mask++) {
        final allowed = {
          for (var i = 0; i < 8; i++)
            if (mask & (1 << i) != 0) i,
        };
        final rules = [MatrixRule.includeOnly((c) => allowed.contains(tupleBits(c)))];

        final feasible = MatrixGenerator.generate(
          scenarios: [MatrixScenario('test', builder: placeholder)],
          axes: axes,
          rules: rules,
        );
        final combinations = MatrixGenerator.generate(
          scenarios: [MatrixScenario('test', builder: placeholder)],
          axes: axes,
          rules: rules,
          sampling: MatrixSampling.pairwise,
        );

        expect(
          pairsOf(combinations),
          pairsOf(feasible),
          reason: 'mask $mask (allowed tuples $allowed) lost pair coverage',
        );
        expect(
          combinations.length,
          lessThanOrEqualTo(feasible.length),
          reason: 'mask $mask sampled more than the feasible set',
        );
      }
    });
  });

  group('MatrixGenerator pairwise selection is unchanged without rules', () {
    // Guard for the compatibility branch: with no rules the feasible set is the
    // full Cartesian product, so selection must keep going through the proven
    // PairwiseGenerator path and produce byte-identical golden names.
    String show(MatrixCombination c) =>
        '${c.theme.name}/${c.locale}/${c.textScale}/${c.device.name}';

    List<String> sampled(MatrixAxes axes) => MatrixGenerator.generate(
          scenarios: [MatrixScenario('test', builder: placeholder)],
          axes: axes,
          sampling: MatrixSampling.pairwise,
        ).map(show).toList();

    test('2 themes × 2 locales × 2 scales', () {
      expect(
        sampled(
          const MatrixAxes(
            themes: [MatrixTheme.light, MatrixTheme.dark],
            locales: [Locale('en'), Locale('fr')],
            textScales: [1.0, 1.5],
          ),
        ),
        [
          'light/en/1.0/phoneSmall',
          'dark/fr/1.0/phoneSmall',
          'light/fr/1.5/phoneSmall',
          'dark/en/1.5/phoneSmall',
        ],
      );
    });

    test('2 themes × 2 locales × 2 scales × 2 devices', () {
      expect(
        sampled(
          const MatrixAxes(
            themes: [MatrixTheme.light, MatrixTheme.dark],
            locales: [Locale('en'), Locale('ar')],
            textScales: [1.0, 2.0],
            devices: [MatrixDevice.phoneSmall, MatrixDevice.tablet],
          ),
        ),
        [
          'light/en/1.0/phoneSmall',
          'dark/ar/2.0/phoneSmall',
          'light/ar/1.0/tablet',
          'dark/en/2.0/tablet',
          'light/en/2.0/phoneSmall',
          'dark/en/1.0/phoneSmall',
        ],
      );
    });

    test('2 themes × 3 locales × 2 devices', () {
      expect(
        sampled(
          const MatrixAxes(
            themes: [MatrixTheme.light, MatrixTheme.dark],
            locales: [Locale('en'), Locale('ru'), Locale('ar')],
            devices: [MatrixDevice.phoneSmall, MatrixDevice.tablet],
          ),
        ),
        [
          'light/en/1.0/phoneSmall',
          'dark/ru/1.0/phoneSmall',
          'light/ar/1.0/tablet',
          'dark/en/1.0/tablet',
          'light/ru/1.0/tablet',
          'dark/ar/1.0/phoneSmall',
        ],
      );
    });
  });
}
