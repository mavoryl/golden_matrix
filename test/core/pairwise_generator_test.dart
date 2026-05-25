import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

void main() {
  group('PairwiseGenerator', () {
    test('empty parameters returns empty', () {
      expect(PairwiseGenerator.generate([]), isEmpty);
    });

    test('single parameter returns one test case per value', () {
      final result = PairwiseGenerator.generate([3]);
      expect(result.length, 3);
      expect(result[0], [0]);
      expect(result[1], [1]);
      expect(result[2], [2]);
    });

    test('2x2 produces all 4 combinations (all pairs = all combos)', () {
      final result = PairwiseGenerator.generate([2, 2]);
      expect(result.length, 4);
      _verifyAllPairsCovered(result, [2, 2]);
    });

    test('3x3 produces all 9 combinations (2 params = full coverage)', () {
      final result = PairwiseGenerator.generate([3, 3]);
      expect(result.length, 9);
      _verifyAllPairsCovered(result, [3, 3]);
    });

    test('2x2x2 reduces from 8 full to fewer', () {
      final result = PairwiseGenerator.generate([2, 2, 2]);
      expect(result.length, lessThan(8));
      expect(result.length, greaterThanOrEqualTo(4));
      _verifyAllPairsCovered(result, [2, 2, 2]);
    });

    test('3x3x3 significantly reduces from 27', () {
      final result = PairwiseGenerator.generate([3, 3, 3]);
      expect(result.length, lessThan(27));
      expect(result.length, greaterThanOrEqualTo(9));
      _verifyAllPairsCovered(result, [3, 3, 3]);
    });

    test('2x2x2x2 reduces from 16', () {
      final result = PairwiseGenerator.generate([2, 2, 2, 2]);
      expect(result.length, lessThan(16));
      _verifyAllPairsCovered(result, [2, 2, 2, 2]);
    });

    test('2x3x2x3 reduces from 36', () {
      final result = PairwiseGenerator.generate([2, 3, 2, 3]);
      expect(result.length, lessThan(36));
      expect(result.length, greaterThanOrEqualTo(9));
      _verifyAllPairsCovered(result, [2, 3, 2, 3]);
    });

    test('large matrix 3x5x3x6 reduces significantly from 270', () {
      final result = PairwiseGenerator.generate([3, 5, 3, 6]);
      expect(result.length, lessThan(50));
      _verifyAllPairsCovered(result, [3, 5, 3, 6]);
    });

    test('is deterministic', () {
      final result1 = PairwiseGenerator.generate([2, 3, 2, 3]);
      final result2 = PairwiseGenerator.generate([2, 3, 2, 3]);
      expect(result1.length, result2.length);
      for (var i = 0; i < result1.length; i++) {
        expect(result1[i], result2[i]);
      }
    });

    test('all values appear at least once', () {
      final params = [3, 4, 2];
      final result = PairwiseGenerator.generate(params);
      for (var p = 0; p < params.length; p++) {
        final usedValues = result.map((tc) => tc[p]).toSet();
        for (var v = 0; v < params[p]; v++) {
          expect(usedValues, contains(v), reason: 'Param $p value $v not used');
        }
      }
    });
  });

  group('MatrixGenerator pairwise integration', () {
    Widget placeholder() => const SizedBox();

    test('reduces 2x2x2x2 matrix', () {
      final full = MatrixGenerator.generate(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: const MatrixAxes(
          themes: [MatrixTheme.light, MatrixTheme.dark],
          locales: [Locale('en'), Locale('ar')],
          textScales: [1.0, 2.0],
          devices: [MatrixDevice.phoneSmall, MatrixDevice.tablet],
        ),
      );

      final pairwise = MatrixGenerator.generate(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: const MatrixAxes(
          themes: [MatrixTheme.light, MatrixTheme.dark],
          locales: [Locale('en'), Locale('ar')],
          textScales: [1.0, 2.0],
          devices: [MatrixDevice.phoneSmall, MatrixDevice.tablet],
        ),
        sampling: MatrixSampling.pairwise,
      );

      expect(full.length, 16);
      expect(pairwise.length, lessThan(16));
      expect(pairwise.length, greaterThan(0));
    });

    test('covers all theme-locale pairs', () {
      final result = MatrixGenerator.generate(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: const MatrixAxes(
          themes: [MatrixTheme.light, MatrixTheme.dark],
          locales: [Locale('en'), Locale('ru'), Locale('ar')],
          devices: [MatrixDevice.phoneSmall, MatrixDevice.tablet],
        ),
        sampling: MatrixSampling.pairwise,
      );

      // Verify all theme-locale pairs exist
      final themeLocalePairs = result.map((c) => '${c.theme.name}_${c.locale}').toSet();

      expect(themeLocalePairs, contains('light_en'));
      expect(themeLocalePairs, contains('light_ru'));
      expect(themeLocalePairs, contains('light_ar'));
      expect(themeLocalePairs, contains('dark_en'));
      expect(themeLocalePairs, contains('dark_ru'));
      expect(themeLocalePairs, contains('dark_ar'));
    });

    test('works with multiple scenarios', () {
      final result = MatrixGenerator.generate(
        scenarios: [
          MatrixScenario('a', builder: placeholder),
          MatrixScenario('b', builder: placeholder),
        ],
        axes: const MatrixAxes(
          themes: [MatrixTheme.light, MatrixTheme.dark],
          locales: [Locale('en'), Locale('ar')],
          devices: [MatrixDevice.phoneSmall, MatrixDevice.tablet],
        ),
        sampling: MatrixSampling.pairwise,
      );

      final scenarioA = result.where((c) => c.scenario.name == 'a');
      final scenarioB = result.where((c) => c.scenario.name == 'b');
      expect(scenarioA.length, scenarioB.length);
      expect(scenarioA.length, greaterThan(0));
    });

    test('single-value axes returns full set', () {
      final result = MatrixGenerator.generate(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: const MatrixAxes(locales: [Locale('en'), Locale('ar')]),
        sampling: MatrixSampling.pairwise,
      );

      // Only 1 multi-value axis (locales) → pairwise = full
      expect(result.length, 2);
    });
  });
}

/// Verifies that all pairs of parameter values are covered.
void _verifyAllPairsCovered(List<List<int>> testCases, List<int> paramSizes) {
  for (var i = 0; i < paramSizes.length; i++) {
    for (var j = i + 1; j < paramSizes.length; j++) {
      final coveredPairs = <String>{};
      for (final tc in testCases) {
        coveredPairs.add('${tc[i]}_${tc[j]}');
      }
      for (var vi = 0; vi < paramSizes[i]; vi++) {
        for (var vj = 0; vj < paramSizes[j]; vj++) {
          expect(
            coveredPairs,
            contains('${vi}_$vj'),
            reason: 'Pair (param$i=$vi, param$j=$vj) not covered',
          );
        }
      }
    }
  }
}
