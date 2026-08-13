import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

MatrixCombination _combo({bool dark = false, double textScale = 1.0}) => MatrixCombination(
      scenario: MatrixScenario('s', builder: () => const SizedBox.shrink()),
      theme: dark ? MatrixTheme.dark : MatrixTheme.light,
      locale: const Locale('en'),
      textScale: textScale,
      device: MatrixDevice.phoneSmall,
      direction: TextDirection.ltr,
    );

// Top-level predicates: the docs on MatrixPreset recommend these precisely so
// the rule can be `const`.
bool isDarkAndLarge(MatrixCombination c) => c.theme.isDark && c.textScale >= 1.5;
bool isLight(MatrixCombination c) => !c.theme.isDark;

// A const rule must be usable in a const preset — that is the whole point of
// the recommendation in matrix_preset.dart.
const _darkLargeExcluded = MatrixRule.exclude(isDarkAndLarge);
const _lightOnly = MatrixRule.includeOnly(isLight);

void main() {
  group('MatrixRule is const-constructible', () {
    test('exclude keeps its type and predicate', () {
      expect(_darkLargeExcluded.type, MatrixRuleType.exclude);
      expect(_darkLargeExcluded.predicate(_combo(dark: true, textScale: 2.0)), isTrue);
      expect(_darkLargeExcluded.predicate(_combo()), isFalse);
    });

    test('includeOnly keeps its type and predicate', () {
      expect(_lightOnly.type, MatrixRuleType.includeOnly);
      expect(_lightOnly.predicate(_combo()), isTrue);
      expect(_lightOnly.predicate(_combo(dark: true)), isFalse);
    });

    test('identical const rules are canonicalized to the same instance', () {
      const again = MatrixRule.exclude(isDarkAndLarge);
      expect(identical(_darkLargeExcluded, again), isTrue);
    });

    test('a const rule works inside a const preset', () {
      const preset = MatrixPreset(
        axes: MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
        rules: [_darkLargeExcluded],
      );

      final combinations = MatrixGenerator.generate(
        scenarios: [MatrixScenario('s', builder: () => const SizedBox.shrink())],
        axes: preset.axes,
        rules: preset.rules,
      );

      expect(combinations.any((c) => c.theme.isDark), isTrue);
      expect(combinations.any((c) => c.theme.isDark && c.textScale >= 1.5), isFalse);
    });

    test('non-const call sites keep working', () {
      final local = MatrixRule.exclude((c) => c.theme.isDark);
      expect(local.type, MatrixRuleType.exclude);
      expect(local.predicate(_combo(dark: true)), isTrue);
    });
  });
}
