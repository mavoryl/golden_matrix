import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';
import 'package:golden_matrix/src/api/matrix_test_runner.dart';

void main() {
  Widget placeholder() => const SizedBox();

  group('resolveCombinations', () {
    test('uses axes directly when no preset', () {
      final result = resolveCombinations(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: const MatrixAxes(
          themes: [MatrixTheme.light, MatrixTheme.dark],
          devices: [MatrixDevice.phoneSmall],
        ),
      );

      expect(result.length, 2);
    });

    test('uses preset axes when axes is null', () {
      final result = resolveCombinations(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        preset: MatrixPreset.componentSmoke,
      );

      expect(result, isNotEmpty);
      // componentSmoke has light+dark themes, smoke sampling
    });

    test('explicit axes wins over preset', () {
      final result = resolveCombinations(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: const MatrixAxes(themes: [MatrixTheme.light], devices: [MatrixDevice.tablet]),
        preset: MatrixPreset.componentFull,
      );

      // All combinations should use tablet (from explicit axes)
      expect(result.every((c) => c.device == MatrixDevice.tablet), isTrue);
    });

    test('explicit sampling wins over preset', () {
      final full = resolveCombinations(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: const MatrixAxes(
          themes: [MatrixTheme.light, MatrixTheme.dark],
          locales: [Locale('en'), Locale('ar')],
        ),
        preset: MatrixPreset.componentSmoke, // smoke sampling
        sampling: MatrixSampling.full, // override to full
      );

      // full = 4 combos, smoke would be less
      expect(full.length, 4);
    });

    test('filters scenarios by scenarioTags', () {
      final result = resolveCombinations(
        scenarios: [
          MatrixScenario('a', builder: placeholder, tags: ['core']),
          MatrixScenario('b', builder: placeholder, tags: ['edge']),
          MatrixScenario('c', builder: placeholder, tags: ['core']),
        ],
        scenarioTags: ['core'],
      );

      expect(result.length, 2);
      expect(result.every((c) => c.scenario.name != 'b'), isTrue);
    });

    test('scenarioTags=null includes all scenarios', () {
      final result = resolveCombinations(
        scenarios: [
          MatrixScenario('a', builder: placeholder, tags: ['core']),
          MatrixScenario('b', builder: placeholder, tags: ['edge']),
        ],
      );
      expect(result.length, 2);
    });

    test('maxCombinations caps full sampling', () {
      final result = resolveCombinations(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: const MatrixAxes(
          themes: [MatrixTheme.light, MatrixTheme.dark],
          locales: [Locale('en'), Locale('ru'), Locale('ar')],
          textScales: [1.0, 2.0],
        ),
        maxCombinations: 5,
      );
      // Full would be 12; capped to 5.
      expect(result.length, 5);
    });

    test('maxCombinations caps pairwise sampling', () {
      final result = resolveCombinations(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: const MatrixAxes(
          themes: [MatrixTheme.light, MatrixTheme.dark],
          locales: [Locale('en'), Locale('ru'), Locale('ar')],
          textScales: [1.0, 2.0],
          devices: [MatrixDevice.phoneSmall, MatrixDevice.tablet],
        ),
        sampling: MatrixSampling.pairwise,
        maxCombinations: 3,
      );
      expect(result.length, 3);
    });

    test('maxCombinations caps smoke sampling', () {
      final result = resolveCombinations(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        axes: const MatrixAxes(
          themes: [MatrixTheme.light, MatrixTheme.dark],
          locales: [Locale('en'), Locale('ar')],
          devices: [MatrixDevice.phoneSmall, MatrixDevice.tablet],
        ),
        sampling: MatrixSampling.smoke,
        maxCombinations: 2,
      );
      expect(result.length, lessThanOrEqualTo(2));
    });

    test('merges preset rules with explicit rules', () {
      final presetWithRule = MatrixPreset(
        axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
        rules: [MatrixRule.exclude((c) => c.theme == MatrixTheme.dark)],
      );

      final result = resolveCombinations(
        scenarios: [MatrixScenario('test', builder: placeholder)],
        preset: presetWithRule,
      );

      expect(result.length, 1);
      expect(result.first.theme, MatrixTheme.light);
    });

    test('defaults to MatrixAxes() when no axes and no preset', () {
      final result = resolveCombinations(scenarios: [MatrixScenario('test', builder: placeholder)]);

      expect(result.length, 1);
      expect(result.first.theme, MatrixTheme.light);
      expect(result.first.locale, const Locale('en'));
      expect(result.first.device, MatrixDevice.phoneSmall);
    });
  });

  group('groupByScenario', () {
    test('groups combinations by scenario name', () {
      final combos = MatrixGenerator.generate(
        scenarios: [
          MatrixScenario('alpha', builder: placeholder),
          MatrixScenario('beta', builder: placeholder),
        ],
        axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
      );

      final grouped = groupByScenario(combos);

      expect(grouped.keys, containsAll(['alpha', 'beta']));
      expect(grouped['alpha']!.length, 2);
      expect(grouped['beta']!.length, 2);
    });

    test('returns empty map for empty input', () {
      expect(groupByScenario([]), isEmpty);
    });

    test('single scenario produces one group', () {
      final combos = MatrixGenerator.generate(
        scenarios: [MatrixScenario('only', builder: placeholder)],
        axes: const MatrixAxes(
          themes: [MatrixTheme.light, MatrixTheme.dark],
          devices: [MatrixDevice.phoneSmall, MatrixDevice.tablet],
        ),
      );

      final grouped = groupByScenario(combos);

      expect(grouped.keys.length, 1);
      expect(grouped['only']!.length, 4);
    });
  });

  group('formatSummary', () {
    MatrixCombinationResult passed(String scenario) => MatrixCombinationResult(
      combination: MatrixCombination(
        scenario: MatrixScenario(scenario, builder: placeholder),
        theme: MatrixTheme.light,
        locale: const Locale('en'),
        textScale: 1.0,
        device: MatrixDevice.phoneSmall,
        direction: TextDirection.ltr,
      ),
      status: MatrixResultStatus.passed,
      goldenPath: 'goldens/$scenario/light_en_ltr_1x_phonesmall.png',
    );

    MatrixCombinationResult failedResult({
      String scenario = 'default',
      MatrixTheme theme = MatrixTheme.light,
      Locale locale = const Locale('en'),
      double textScale = 1.0,
      MatrixDevice device = MatrixDevice.phoneSmall,
    }) => MatrixCombinationResult(
      combination: MatrixCombination(
        scenario: MatrixScenario(scenario, builder: placeholder),
        theme: theme,
        locale: locale,
        textScale: textScale,
        device: device,
        direction: TextDirection.ltr,
      ),
      status: MatrixResultStatus.failed,
      goldenPath: 'goldens/$scenario/file.png',
      errorMessage: 'mismatch',
    );

    test('includes name and counts', () {
      final summary = formatSummary(
        MatrixResult(
          name: 'MyWidget',
          results: [passed('a'), passed('b')],
          duration: const Duration(milliseconds: 250),
        ),
      );

      expect(summary, contains('MyWidget'));
      expect(summary, contains('2 total'));
      expect(summary, contains('2 passed'));
    });

    test('omits sections with zero counts', () {
      final summary = formatSummary(
        MatrixResult(
          name: 'MyWidget',
          results: [passed('a')],
          duration: const Duration(milliseconds: 100),
        ),
      );

      expect(summary, isNot(contains('failed')));
      expect(summary, isNot(contains('skipped')));
      expect(summary, isNot(contains('warnings')));
    });

    test('shows duration in ms when under 1 second', () {
      final summary = formatSummary(
        MatrixResult(
          name: 'X',
          results: [passed('a')],
          duration: const Duration(milliseconds: 250),
        ),
      );

      expect(summary, contains('(250ms)'));
    });

    test('shows duration in seconds when 1s or more', () {
      final summary = formatSummary(
        MatrixResult(name: 'X', results: [passed('a')], duration: const Duration(seconds: 3)),
      );

      expect(summary, contains('(3s)'));
    });

    test('lists failed combinations', () {
      final summary = formatSummary(
        MatrixResult(
          name: 'X',
          results: [
            passed('a'),
            failedResult(scenario: 'b', theme: MatrixTheme.dark),
          ],
          duration: const Duration(milliseconds: 100),
        ),
      );

      expect(summary, contains('Failed:'));
      expect(summary, contains('b | dark'));
    });

    test('does not show Failed: section when no failures', () {
      final summary = formatSummary(
        MatrixResult(
          name: 'X',
          results: [passed('a')],
          duration: const Duration(milliseconds: 100),
        ),
      );

      expect(summary, isNot(contains('Failed:')));
    });
  });
}
