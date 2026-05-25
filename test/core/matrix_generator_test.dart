import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

void main() {
  Widget placeholder() => const SizedBox();

  group('MatrixGenerator', () {
    test('single scenario with default axes produces 1 combination', () {
      final combinations = MatrixGenerator.generate(
        scenarios: [MatrixScenario('default', builder: placeholder)],
        axes: const MatrixAxes(),
      );

      expect(combinations.length, 1);
      expect(combinations.first.theme.name, 'light');
      expect(combinations.first.locale, const Locale('en'));
      expect(combinations.first.textScale, 1.0);
      expect(combinations.first.device.name, 'phoneSmall');
      expect(combinations.first.direction, TextDirection.ltr);
    });

    test('2 scenarios × 2 themes produces 4 combinations', () {
      final combinations = MatrixGenerator.generate(
        scenarios: [
          MatrixScenario('a', builder: placeholder),
          MatrixScenario('b', builder: placeholder),
        ],
        axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
      );

      expect(combinations.length, 4);
    });

    test('full Cartesian product 2×2×2×2×2 = 32', () {
      final combinations = MatrixGenerator.generate(
        scenarios: [
          MatrixScenario('a', builder: placeholder),
          MatrixScenario('b', builder: placeholder),
        ],
        axes: const MatrixAxes(
          themes: [MatrixTheme.light, MatrixTheme.dark],
          locales: [Locale('en'), Locale('ru')],
          textScales: [1.0, 2.0],
          devices: [MatrixDevice.phoneSmall, MatrixDevice.phoneLarge],
        ),
      );

      expect(combinations.length, 32);
    });

    test('direction inferred from locale: ar → RTL, en → LTR', () {
      final combinations = MatrixGenerator.generate(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: const MatrixAxes(locales: [Locale('en'), Locale('ar')]),
      );

      expect(combinations.length, 2);

      final enCombo = combinations.firstWhere((c) => c.locale == const Locale('en'));
      final arCombo = combinations.firstWhere((c) => c.locale == const Locale('ar'));

      expect(enCombo.direction, TextDirection.ltr);
      expect(arCombo.direction, TextDirection.rtl);
    });

    test('explicit directions become a separate axis', () {
      final combinations = MatrixGenerator.generate(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: const MatrixAxes(directions: [TextDirection.ltr, TextDirection.rtl]),
      );

      // 1 scenario × 1 theme × 1 locale × 1 textScale × 1 device × 2 directions = 2
      expect(combinations.length, 2);
      expect(combinations.any((c) => c.direction == TextDirection.ltr), isTrue);
      expect(combinations.any((c) => c.direction == TextDirection.rtl), isTrue);
    });

    test('exclude rule removes matching combinations', () {
      final combinations = MatrixGenerator.generate(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
        rules: [MatrixRule.exclude((c) => c.theme.name == 'dark')],
      );

      expect(combinations.length, 1);
      expect(combinations.first.theme.name, 'light');
    });

    test('multiple exclude rules applied sequentially', () {
      final combinations = MatrixGenerator.generate(
        scenarios: [
          MatrixScenario('a', builder: placeholder),
          MatrixScenario('b', builder: placeholder),
        ],
        axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
        rules: [
          MatrixRule.exclude((c) => c.theme.name == 'dark'),
          MatrixRule.exclude((c) => c.scenario.name == 'b'),
        ],
      );

      expect(combinations.length, 1);
      expect(combinations.first.scenario.name, 'a');
      expect(combinations.first.theme.name, 'light');
    });

    test('directionForLocale returns RTL for known RTL languages', () {
      expect(MatrixGenerator.directionForLocale(const Locale('ar')), TextDirection.rtl);
      expect(MatrixGenerator.directionForLocale(const Locale('he')), TextDirection.rtl);
      expect(MatrixGenerator.directionForLocale(const Locale('fa')), TextDirection.rtl);
      expect(MatrixGenerator.directionForLocale(const Locale('en')), TextDirection.ltr);
      expect(MatrixGenerator.directionForLocale(const Locale('ru')), TextDirection.ltr);
    });
  });
}
