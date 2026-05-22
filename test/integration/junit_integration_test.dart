import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

MatrixCombinationResult _passed({String scenario = 'default'}) {
  return MatrixCombinationResult(
    combination: MatrixCombination(
      scenario: MatrixScenario(scenario, builder: () => const SizedBox.shrink()),
      theme: MatrixTheme.light,
      locale: const Locale('en'),
      textScale: 1.0,
      device: MatrixDevice.phoneSmall,
      direction: TextDirection.ltr,
    ),
    status: MatrixResultStatus.passed,
    goldenPath: 'goldens/x/$scenario/x.png',
  );
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('junit_integration_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('MatrixReportWriter.writeJunit', () {
    test('writes <slug>_report.xml at expected path', () async {
      final result = MatrixResult(
        name: 'matrixGolden: TestWidget',
        results: [_passed()],
        duration: const Duration(milliseconds: 250),
      );

      await MatrixReportWriter.writeJunit(result, outputDir: tempDir.path);

      final file = File('${tempDir.path}/matrixgolden__testwidget_report.xml');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(content, contains('<testsuites'));
      expect(content, contains('name="matrixGolden: TestWidget"'));
      expect(content, contains('tests="1"'));
      expect(content, contains('time="0.250"'));
      expect(content.trim(), endsWith('</testsuites>'));
    });

    test('slug derivation handles special characters in test name', () async {
      final result = MatrixResult(name: 'matrixGolden: My Widget!', results: [_passed()]);

      await MatrixReportWriter.writeJunit(result, outputDir: tempDir.path);

      final file = File('${tempDir.path}/matrixgolden__my_widget__report.xml');
      expect(file.existsSync(), isTrue);
    });

    test('custom outputDir is created if it does not exist', () async {
      final deepDir = '${tempDir.path}/a/b/c';
      final result = MatrixResult(name: 'Widget', results: [_passed()]);

      await MatrixReportWriter.writeJunit(result, outputDir: deepDir);

      expect(File('$deepDir/widget_report.xml').existsSync(), isTrue);
    });

    test('multiple scenarios produce separate <testsuite> elements', () async {
      final result = MatrixResult(
        name: 'matrixGolden: Multi',
        results: [
          _passed(scenario: 'alpha'),
          _passed(scenario: 'beta'),
          _passed(scenario: 'gamma'),
        ],
      );

      await MatrixReportWriter.writeJunit(result, outputDir: tempDir.path);

      final content = File('${tempDir.path}/matrixgolden__multi_report.xml').readAsStringSync();
      expect(content, contains('<testsuite name="alpha"'));
      expect(content, contains('<testsuite name="beta"'));
      expect(content, contains('<testsuite name="gamma"'));
    });
  });
}
