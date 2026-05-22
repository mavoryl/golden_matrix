import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';
import 'package:golden_matrix/src/core/junit_template.dart';

MatrixCombination _combo({
  String scenario = 'default',
  MatrixTheme theme = MatrixTheme.light,
  Locale locale = const Locale('en'),
}) {
  return MatrixCombination(
    scenario: MatrixScenario(scenario, builder: () => const SizedBox.shrink()),
    theme: theme,
    locale: locale,
    textScale: 1.0,
    device: MatrixDevice.phoneSmall,
    direction: TextDirection.ltr,
  );
}

MatrixCombinationResult _passed(MatrixCombination c) => MatrixCombinationResult(
      combination: c,
      status: MatrixResultStatus.passed,
      goldenPath: 'goldens/x/${c.scenario.name}/x.png',
    );

MatrixCombinationResult _failed(MatrixCombination c, String err) => MatrixCombinationResult(
      combination: c,
      status: MatrixResultStatus.failed,
      goldenPath: 'goldens/x/${c.scenario.name}/x.png',
      errorMessage: err,
    );

MatrixCombinationResult _skipped(MatrixCombination c) => MatrixCombinationResult(
      combination: c,
      status: MatrixResultStatus.skipped,
      goldenPath: 'goldens/x/${c.scenario.name}/x.png',
    );

void main() {
  group('JunitTemplate.render', () {
    test('all passed → no failure/skipped elements, counts correct', () {
      final result = MatrixResult(
        name: 'matrixGolden: Foo',
        results: [_passed(_combo()), _passed(_combo(theme: MatrixTheme.dark))],
        duration: const Duration(milliseconds: 500),
      );

      final xml = JunitTemplate.render(result);
      expect(xml, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(xml, contains('<testsuites'));
      expect(xml, contains('tests="2"'));
      expect(xml, contains('failures="0"'));
      expect(xml, contains('skipped="0"'));
      expect(xml, contains('time="0.500"'));
      expect(xml, isNot(contains('<failure')));
      expect(xml, isNot(contains('<skipped')));
    });

    test('failure → <failure> with message + body', () {
      final result = MatrixResult(
        name: 'matrixGolden: Foo',
        results: [_failed(_combo(), 'Pixel test failed, 1.56%')],
      );

      final xml = JunitTemplate.render(result);
      expect(xml, contains('failures="1"'));
      expect(xml, contains('<failure'));
      expect(xml, contains('type="PixelMismatch"'));
      expect(xml, contains('message="Pixel test failed, 1.56%"'));
      expect(xml, contains('Pixel test failed, 1.56%'));
    });

    test('skipped → <skipped/>', () {
      final result = MatrixResult(
        name: 'matrixGolden: Foo',
        results: [_skipped(_combo())],
      );

      final xml = JunitTemplate.render(result);
      expect(xml, contains('skipped="1"'));
      expect(xml, contains('<skipped/>'));
    });

    test('scenarios get their own testsuite', () {
      final result = MatrixResult(
        name: 'matrixGolden: Foo',
        results: [
          _passed(_combo(scenario: 'a')),
          _passed(_combo(scenario: 'b')),
          _failed(_combo(scenario: 'b'), 'err'),
        ],
      );

      final xml = JunitTemplate.render(result);
      expect(xml, contains('<testsuite name="a"'));
      expect(xml, contains('<testsuite name="b"'));
    });

    test('testcase name and classname follow expected format', () {
      final result = MatrixResult(
        name: 'matrixGolden: Foo',
        results: [_passed(_combo(scenario: 'default'))],
      );

      final xml = JunitTemplate.render(result);
      expect(xml, contains('classname="matrixGolden: Foo.default"'));
      expect(xml, contains('name="light en ltr 1x phoneSmall"'));
    });

    test('XML special characters in attributes are escaped', () {
      final result = MatrixResult(
        name: 'matrixGolden: Foo <bar>',
        results: [_failed(_combo(), 'expected "x" & got <y>')],
      );

      final xml = JunitTemplate.render(result);
      // testsuites name attribute
      expect(xml, contains('name="matrixGolden: Foo &lt;bar&gt;"'));
      // failure message attribute
      expect(xml, contains('&quot;x&quot;'));
      expect(xml, contains('&amp;'));
      expect(xml, contains('&lt;y&gt;'));
    });

    test('multiline error message stays in body, message attr is first line', () {
      final result = MatrixResult(
        name: 'matrixGolden: Foo',
        results: [_failed(_combo(), 'First line of error\nstack frame 1\nstack frame 2')],
      );

      final xml = JunitTemplate.render(result);
      expect(xml, contains('message="First line of error"'));
      // Body still contains the full text
      expect(xml, contains('stack frame 1'));
      expect(xml, contains('stack frame 2'));
    });
  });
}
