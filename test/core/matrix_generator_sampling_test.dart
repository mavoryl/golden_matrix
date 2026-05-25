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
}
