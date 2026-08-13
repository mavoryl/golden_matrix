import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';
import 'package:golden_matrix/src/core/matrix_run_plan.dart';

Widget _placeholder() => const SizedBox.shrink();

List<MatrixScenario> _scenarios([int count = 1]) => [
      for (var i = 0; i < count; i++) MatrixScenario('s$i', builder: _placeholder),
    ];

void main() {
  group('MatrixRunPlan config resolution', () {
    test('axes wins over preset.axes, rules are merged', () {
      // Precedence is documented in the dartdoc of matrixGolden; before the
      // plan existed it was spelled out twice — once in the runner, once in
      // previewMatrixGolden — and the two could drift apart.
      final plan = MatrixRunPlan.resolve(
        name: 'demo',
        scenarios: _scenarios(),
        axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
        preset: MatrixPreset(
          axes: const MatrixAxes(),
          rules: [MatrixRule.exclude((c) => c.theme.isDark)],
        ),
      );

      expect(plan.axes.themes.length, 2, reason: 'axes should win over preset.axes');
      expect(plan.rules.length, 1, reason: 'the preset rule is merged in');
      expect(
        plan.combinations.map((c) => c.theme.name),
        ['light'],
        reason: 'the dark theme came from axes, the preset rule then excluded it',
      );
    });

    test('sampling falls back to the preset, then to full', () {
      final fromPreset = MatrixRunPlan.resolve(
        name: 'demo',
        scenarios: _scenarios(),
        preset: const MatrixPreset(axes: MatrixAxes(), sampling: MatrixSampling.smoke),
      );
      expect(fromPreset.sampling, MatrixSampling.smoke);

      final defaulted = MatrixRunPlan.resolve(name: 'demo', scenarios: _scenarios());
      expect(defaulted.sampling, MatrixSampling.full);
    });

    test('scenarioTags filter the scenario list', () {
      final plan = MatrixRunPlan.resolve(
        name: 'demo',
        scenarios: [
          const MatrixScenario('kept', builder: _placeholder, tags: ['smoke']),
          const MatrixScenario('dropped', builder: _placeholder, tags: ['slow']),
        ],
        scenarioTags: ['smoke'],
      );

      expect(plan.scenarios.map((s) => s.name), ['kept']);
    });

    test('scenarioTags matching nothing name the real argument', () {
      expect(
        () => MatrixRunPlan.resolve(
          name: 'demo',
          scenarios: [
            const MatrixScenario('a', builder: _placeholder, tags: ['smoke']),
          ],
          scenarioTags: ['nope'],
        ),
        throwsA(
          isA<ArgumentError>()
              .having((e) => e.name, 'name', 'scenarioTags')
              .having((e) => e.message.toString(), 'message', contains('smoke')),
        ),
      );
    });

    test('maxCombinations caps the planned tests', () {
      final plan = MatrixRunPlan.resolve(
        name: 'demo',
        scenarios: _scenarios(),
        axes: const MatrixAxes(
          themes: [MatrixTheme.light, MatrixTheme.dark],
          textScales: [1.0, 1.5, 2.0],
        ),
        maxCombinations: 2,
      );

      expect(plan.length, 2);
      expect(plan.goldenPaths.length, 2);
    });
  });

  group('MatrixRunPlan golden paths', () {
    test('the viewport scheme keeps the device segment', () {
      final plan = MatrixRunPlan.resolve(name: 'demo', scenarios: _scenarios());

      expect(plan.goldenPaths.single, 'goldens/demo/s0/light_en_ltr_1x_phonesmall.png');
    });

    test('the component scheme drops the device segment', () {
      final plan = MatrixRunPlan.resolve(
        name: 'demo',
        scenarios: _scenarios(),
        pathScheme: MatrixPathScheme.component,
      );

      expect(plan.goldenPaths.single, 'goldens/demo/s0/light_en_ltr_1x.png');
    });

    test('the component scheme collapses a multi-device axis before generation', () {
      // Two devices would otherwise register two tests writing the same PNG:
      // the component path has no device segment. Collapsing inside the plan
      // keeps the device out of rules, sampling and report counters too.
      final plan = MatrixRunPlan.resolve(
        name: 'demo',
        scenarios: _scenarios(),
        axes: const MatrixAxes(devices: [MatrixDevice.tablet, MatrixDevice.phoneSmall]),
        pathScheme: MatrixPathScheme.component,
      );

      expect(plan.axes.devices, [MatrixDevice.tablet]);
      expect(plan.length, 1);
      expect(plan.duplicatePaths, isEmpty);
    });

    test('the viewport scheme keeps every device', () {
      final plan = MatrixRunPlan.resolve(
        name: 'demo',
        scenarios: _scenarios(),
        axes: const MatrixAxes(devices: [MatrixDevice.tablet, MatrixDevice.phoneSmall]),
      );

      expect(plan.length, 2);
    });

    test('fileNameBuilder overrides both schemes', () {
      final plan = MatrixRunPlan.resolve(
        name: 'demo',
        scenarios: _scenarios(),
        fileNameBuilder: (c) => 'custom/${c.scenario.name}.png',
      );

      expect(plan.goldenPaths.single, 'custom/s0.png');
      expect(plan.usesCustomPaths, isTrue);
    });

    test('usesCustomPaths is false without a fileNameBuilder', () {
      expect(MatrixRunPlan.resolve(name: 'demo', scenarios: _scenarios()).usesCustomPaths, isFalse);
    });
  });

  group('MatrixRunPlan duplicate detection', () {
    test('a many-to-one fileNameBuilder is reported once per colliding path', () {
      final plan = MatrixRunPlan.resolve(
        name: 'demo',
        scenarios: _scenarios(),
        axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
        fileNameBuilder: (c) => 'same.png',
      );

      expect(plan.length, 2);
      expect(plan.duplicatePaths, ['same.png']);
    });

    test('distinct paths produce no duplicates', () {
      final plan = MatrixRunPlan.resolve(
        name: 'demo',
        scenarios: _scenarios(),
        axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
      );

      expect(plan.duplicatePaths, isEmpty);
    });

    test('the component scheme sees collisions the viewport scheme does not', () {
      // Two devices, component paths: identical files. This is exactly the
      // collision previewMatrixGolden could not show before, because it only
      // ever priced paths through the viewport scheme.
      final scenarios = _scenarios();
      const axes = MatrixAxes(devices: [MatrixDevice.tablet, MatrixDevice.phoneSmall]);

      final viewport = MatrixRunPlan.resolve(name: 'demo', scenarios: scenarios, axes: axes);
      expect(viewport.duplicatePaths, isEmpty);

      // Bypass the collapse with a custom builder that mirrors the component
      // scheme: the collision is real for anyone naming files without a device.
      final component = MatrixRunPlan.resolve(
        name: 'demo',
        scenarios: scenarios,
        axes: axes,
        fileNameBuilder: (c) => 'goldens/demo/${c.scenario.slug}/${c.theme.slug}.png',
      );
      expect(component.duplicatePaths, ['goldens/demo/s0/light.png']);
    });
  });

  group('MatrixRunPlan.describeProblems', () {
    test('a healthy plan has nothing to say', () {
      final plan = MatrixRunPlan.resolve(name: 'demo', scenarios: _scenarios());

      expect(plan.describeProblems(), isNull);
    });

    test('an empty plan is reported, because zero tests looks like success', () {
      final plan = MatrixRunPlan.resolve(
        name: 'demo',
        scenarios: _scenarios(),
        rules: [MatrixRule.exclude((_) => true)],
      );

      expect(plan.describeProblems(), contains('no combinations'));
      expect(plan.describeProblems(), isNot(contains('collapses the devices axis')));
    });

    test('an empty component plan also blames the device collapse', () {
      final plan = MatrixRunPlan.resolve(
        name: 'demo',
        scenarios: _scenarios(),
        axes: const MatrixAxes(devices: [MatrixDevice.tablet, MatrixDevice.phoneSmall]),
        rules: [MatrixRule.exclude((c) => c.device == MatrixDevice.tablet)],
        pathScheme: MatrixPathScheme.component,
      );

      expect(plan.describeProblems(), contains('collapses the devices axis'));
    });

    test('colliding paths are reported with the paths themselves', () {
      // Until the plan existed only previewMatrixGolden could see this; the
      // runners registered both tests and let the second overwrite the first.
      final plan = MatrixRunPlan.resolve(
        name: 'demo',
        scenarios: _scenarios(),
        axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
        fileNameBuilder: (c) => 'same.png',
      );

      expect(
        plan.describeProblems(),
        allOf(contains('1 golden path(s)'), contains('same.png')),
      );
    });

    test('a long collision list is truncated instead of flooding the console', () {
      final plan = MatrixRunPlan.resolve(
        name: 'demo',
        scenarios: _scenarios(),
        // Twelve combinations, six distinct paths, each claimed twice.
        axes: const MatrixAxes(
          themes: [MatrixTheme.light, MatrixTheme.dark],
          textScales: [1.0, 1.1, 1.2, 1.3, 1.4, 1.5],
        ),
        fileNameBuilder: (c) => 'dup${c.textScale}.png',
      );

      final problem = plan.describeProblems()!;
      expect(plan.duplicatePaths.length, 6);
      expect(problem, contains('6 golden path(s)'));
      expect(problem, endsWith(', …'));
    });

    test('warnAboutProblems prints under the package prefix, or stays quiet', () {
      final lines = <String>[];
      final original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => lines.add(message ?? '');
      addTearDown(() => debugPrint = original);

      MatrixRunPlan.resolve(name: 'demo', scenarios: _scenarios()).warnAboutProblems();
      expect(lines, isEmpty);

      MatrixRunPlan.resolve(
        name: 'demo',
        scenarios: _scenarios(),
        rules: [MatrixRule.exclude((_) => true)],
      ).warnAboutProblems();
      expect(lines.single, startsWith('golden_matrix: '));
    });
  });

  group('MatrixRunPlan grouping and counts', () {
    test('tests are grouped by scenario in declaration order', () {
      final plan = MatrixRunPlan.resolve(
        name: 'demo',
        scenarios: _scenarios(3),
        axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
      );

      expect(plan.byScenario.keys, ['s0', 's1', 's2']);
      expect(plan.byScenario['s0']!.length, 2);
      expect(plan.byScenario['s0']!.first.goldenPath, contains('/s0/'));
    });

    test('rawCount and afterRulesCount bracket the sampled count', () {
      final plan = MatrixRunPlan.resolve(
        name: 'demo',
        scenarios: _scenarios(),
        axes: const MatrixAxes(
          themes: [MatrixTheme.light, MatrixTheme.dark],
          textScales: [1.0, 1.5, 2.0],
        ),
        rules: [MatrixRule.exclude((c) => c.theme.isDark && c.textScale > 1.0)],
        maxCombinations: 2,
      );

      expect(plan.rawCount, 6);
      expect(plan.afterRulesCount, 4);
      expect(plan.length, 2);
    });

    test('an empty plan is empty, not a crash', () {
      final plan = MatrixRunPlan.resolve(
        name: 'demo',
        scenarios: _scenarios(),
        rules: [MatrixRule.exclude((_) => true)],
      );

      expect(plan.isEmpty, isTrue);
      expect(plan.byScenario, isEmpty);
      expect(plan.goldenPaths, isEmpty);
      expect(plan.duplicatePaths, isEmpty);
    });
  });
}
