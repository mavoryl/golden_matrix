import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';
import 'package:golden_matrix/src/core/matrix_run_plan.dart';

void main() {
  Widget placeholder() => const SizedBox();

  List<MatrixScenario> scenarios() => [MatrixScenario('test', builder: placeholder)];

  List<MatrixCombination> generate({
    List<MatrixScenario>? withScenarios,
    MatrixAxes axes = const MatrixAxes(),
    MatrixSampling sampling = MatrixSampling.full,
    int? maxCombinations,
  }) =>
      MatrixGenerator.generate(
        scenarios: withScenarios ?? scenarios(),
        axes: axes,
        sampling: sampling,
        maxCombinations: maxCombinations,
      );

  group('MatrixGenerator rejects invalid input with ArgumentError', () {
    // These were `assert`s: silently absent in profile/release builds, and
    // AssertionError carries no argument context even in debug.
    test('empty scenarios', () {
      expect(
        () => generate(withScenarios: []),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'scenarios')),
      );
    });

    test('empty themes', () {
      expect(
        () => generate(axes: const MatrixAxes(themes: [])),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'axes.themes')),
      );
    });

    test('empty locales', () {
      expect(
        () => generate(axes: const MatrixAxes(locales: [])),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'axes.locales')),
      );
    });

    test('empty textScales', () {
      expect(
        () => generate(axes: const MatrixAxes(textScales: [])),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'axes.textScales')),
      );
    });

    test('empty devices', () {
      expect(
        () => generate(axes: const MatrixAxes(devices: [])),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'axes.devices')),
      );
    });
  });

  group('MatrixRunPlan.resolve names the real cause of an empty matrix', () {
    test('a scenarioTags typo blames the tags, not the scenarios', () {
      expect(
        () => MatrixRunPlan.resolve(
          name: 'test',
          scenarios: [
            MatrixScenario('test', builder: placeholder, tags: const ['smoke']),
          ],
          scenarioTags: const ['smok'],
        ),
        throwsA(
          isA<ArgumentError>()
              .having((e) => e.name, 'name', 'scenarioTags')
              .having((e) => e.message.toString(), 'message', contains('smoke')),
        ),
      );
    });

    test('matching tags still resolve normally', () {
      final result = MatrixRunPlan.resolve(
        name: 'test',
        scenarios: [
          MatrixScenario('test', builder: placeholder, tags: const ['smoke']),
        ],
        scenarioTags: const ['smoke'],
      );

      expect(result.combinations, isNotEmpty);
    });
  });

  group('MatrixGenerator validates maxCombinations', () {
    test('negative cap is rejected instead of throwing RangeError from sublist', () {
      expect(
        () => generate(maxCombinations: -1),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'maxCombinations')),
      );
    });

    test('zero cap is rejected — a run with no tests is never what was meant', () {
      expect(
        () => generate(maxCombinations: 0),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'maxCombinations')),
      );
    });

    test('a positive cap still works', () {
      final result = generate(
        axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
        maxCombinations: 1,
      );
      expect(result.length, 1);
    });
  });

  group('MatrixGenerator validates textScale', () {
    test('NaN is rejected', () {
      expect(
        () => generate(axes: const MatrixAxes(textScales: [double.nan])),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'axes.textScales')),
      );
    });

    test('infinity is rejected', () {
      expect(
        () => generate(axes: const MatrixAxes(textScales: [double.infinity])),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'axes.textScales')),
      );
    });

    test('zero and negative are rejected', () {
      expect(
        () => generate(axes: const MatrixAxes(textScales: [0.0])),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => generate(axes: const MatrixAxes(textScales: [1.0, -1.0])),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('MatrixGenerator validates device geometry', () {
    MatrixDevice sized(Size size) => MatrixDevice(name: 'weird', logicalSize: size);

    test('non-positive logicalSize is rejected', () {
      expect(
        () => generate(axes: MatrixAxes(devices: [sized(Size.zero)])),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'axes.devices')),
      );
    });

    test('NaN logicalSize is rejected', () {
      expect(
        () => generate(axes: MatrixAxes(devices: [sized(const Size(double.nan, 100))])),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'axes.devices')),
      );
    });
  });

  group('PairwiseGenerator rejects degenerate parameter sizes', () {
    test('a zero-sized domain is rejected instead of yielding index 0', () {
      // generate([2, 2, 0]) used to return value index 0 for the empty domain:
      // `bestValue` starts at 0 and the value loop never runs.
      expect(() => PairwiseGenerator.generate([2, 2, 0]), throwsA(isA<ArgumentError>()));
    });

    test('a negative size is rejected', () {
      expect(() => PairwiseGenerator.generate([2, -1]), throwsA(isA<ArgumentError>()));
    });

    test('valid sizes still produce a covering array', () {
      final cases = PairwiseGenerator.generate([2, 3, 2]);
      expect(cases, isNotEmpty);
      for (final testCase in cases) {
        expect(testCase.length, 3);
        expect(testCase[0], inInclusiveRange(0, 1));
        expect(testCase[1], inInclusiveRange(0, 2));
        expect(testCase[2], inInclusiveRange(0, 1));
      }
    });
  });
}
