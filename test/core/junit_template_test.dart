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
        results: [
          _passed(_combo()),
          _passed(_combo(theme: MatrixTheme.dark)),
        ],
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
      final result = MatrixResult(name: 'matrixGolden: Foo', results: [_skipped(_combo())]);

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
      final result = MatrixResult(name: 'matrixGolden: Foo', results: [_passed(_combo())]);

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

    test('empty results — testsuites with tests=0, no testsuite children', () {
      final result = MatrixResult(name: 'matrixGolden: Empty', results: const []);

      final xml = JunitTemplate.render(result);
      expect(xml, contains('tests="0"'));
      expect(xml, contains('failures="0"'));
      expect(xml, contains('skipped="0"'));
      expect(xml, isNot(contains('<testsuite ')));
    });

    test('mixed pass + fail + skipped in same suite — counts add up', () {
      final result = MatrixResult(
        name: 'matrixGolden: Foo',
        results: [
          _passed(_combo()),
          _failed(_combo(theme: MatrixTheme.dark), 'mismatch'),
          _skipped(_combo(locale: const Locale('ru'))),
        ],
      );

      final xml = JunitTemplate.render(result);
      // Top-level counts
      expect(xml, contains('tests="3"'));
      expect(xml, contains('failures="1"'));
      expect(xml, contains('skipped="1"'));
      // Per-suite counts (single suite "default")
      expect(
        xml,
        contains('<testsuite name="default" tests="3" failures="1" errors="0" skipped="1"'),
      );
    });

    test('locale with country code appears in testcase name', () {
      final result = MatrixResult(
        name: 'matrixGolden: Foo',
        results: [_passed(_combo(locale: const Locale('zh', 'CN')))],
      );

      final xml = JunitTemplate.render(result);
      expect(xml, contains('name="light zh-CN ltr 1x phoneSmall"'));
    });

    test('fractional textScale renders without truncation', () {
      final combo = MatrixCombination(
        scenario: MatrixScenario('default', builder: () => const SizedBox.shrink()),
        theme: MatrixTheme.light,
        locale: const Locale('en'),
        textScale: 1.5,
        device: MatrixDevice.phoneSmall,
        direction: TextDirection.ltr,
      );
      final result = MatrixResult(name: 'matrixGolden: Foo', results: [_passed(combo)]);

      final xml = JunitTemplate.render(result);
      expect(xml, contains('name="light en ltr 1.5x phoneSmall"'));
    });

    test('failed status with null errorMessage falls back to "failed"', () {
      final combo = _combo();
      final result = MatrixResult(
        name: 'matrixGolden: Foo',
        results: [
          MatrixCombinationResult(
            combination: combo,
            status: MatrixResultStatus.failed,
            goldenPath: 'goldens/x/default/x.png',
            // errorMessage intentionally omitted
          ),
        ],
      );

      final xml = JunitTemplate.render(result);
      expect(xml, contains('<failure'));
      expect(xml, contains('message="failed"'));
    });

    test('RTL direction appears as "rtl" in testcase name', () {
      final combo = MatrixCombination(
        scenario: MatrixScenario('default', builder: () => const SizedBox.shrink()),
        theme: MatrixTheme.light,
        locale: const Locale('ar'),
        textScale: 1.0,
        device: MatrixDevice.phoneSmall,
        direction: TextDirection.rtl,
      );
      final result = MatrixResult(name: 'matrixGolden: Foo', results: [_passed(combo)]);

      final xml = JunitTemplate.render(result);
      expect(xml, contains('name="light ar rtl 1x phoneSmall"'));
    });

    test('XML output ends with closing testsuites tag and a newline', () {
      final result = MatrixResult(name: 'matrixGolden: Foo', results: [_passed(_combo())]);
      final xml = JunitTemplate.render(result);
      expect(xml.trim(), endsWith('</testsuites>'));
    });
  });
}
