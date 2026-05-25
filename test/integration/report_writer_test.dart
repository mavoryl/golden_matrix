import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';
import 'package:golden_matrix/src/core/html_template.dart';

void main() {
  Widget placeholder() => const SizedBox();

  MatrixCombinationResult makeResult({
    String scenario = 'default',
    MatrixTheme theme = MatrixTheme.light,
    MatrixResultStatus status = MatrixResultStatus.passed,
    String goldenPath = 'goldens/default/light_en_ltr_1x_phonesmall.png',
    String? errorMessage,
  }) {
    return MatrixCombinationResult(
      combination: MatrixCombination(
        scenario: MatrixScenario(scenario, builder: placeholder),
        theme: theme,
        locale: const Locale('en'),
        textScale: 1.0,
        device: MatrixDevice.phoneSmall,
        direction: TextDirection.ltr,
      ),
      status: status,
      goldenPath: goldenPath,
      errorMessage: errorMessage,
    );
  }

  group('MatrixReportWriter integration', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('golden_matrix_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('write creates JSON file with correct structure', () async {
      final result = MatrixResult(
        name: 'TestWidget',
        results: [
          makeResult(),
          makeResult(
            scenario: 'error',
            theme: MatrixTheme.dark,
            status: MatrixResultStatus.failed,
            errorMessage: 'Mismatch',
          ),
        ],
        duration: const Duration(seconds: 3),
      );

      await MatrixReportWriter.write(result, outputDir: tempDir.path);

      final file = File('${tempDir.path}/testwidget_report.json');
      expect(file.existsSync(), isTrue);

      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(json['name'], 'TestWidget');
      expect(json['total'], 2);
      expect(json['passed'], 1);
      expect(json['failed'], 1);
      expect(json['skipped'], 0);
      expect(json['durationMs'], 3000);
      expect(json['timestamp'], isNotNull);
      expect(json['results'], isList);
      expect((json['results'] as List).length, 2);
    });

    test('writeHtml creates HTML file', () async {
      final result = MatrixResult(
        name: 'TestWidget',
        results: [makeResult()],
        duration: const Duration(seconds: 1),
      );

      await MatrixReportWriter.writeHtml(result, outputDir: tempDir.path);

      final file = File('${tempDir.path}/testwidget_report.html');
      expect(file.existsSync(), isTrue);

      final html = file.readAsStringSync();
      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains('TestWidget'));
    });

    test('slug name handles special characters', () async {
      final result = MatrixResult(name: 'matrixGolden: My Widget!', results: [makeResult()]);

      await MatrixReportWriter.write(result, outputDir: tempDir.path);

      final file = File('${tempDir.path}/matrixgolden__my_widget__report.json');
      expect(file.existsSync(), isTrue);
    });

    test('outputDir overrides default path', () async {
      final customDir = Directory('${tempDir.path}/custom_output')..createSync(recursive: true);

      final result = MatrixResult(name: 'Widget', results: [makeResult()]);

      await MatrixReportWriter.write(result, outputDir: customDir.path);
      await MatrixReportWriter.writeHtml(result, outputDir: customDir.path);

      expect(File('${customDir.path}/widget_report.json').existsSync(), isTrue);
      expect(File('${customDir.path}/widget_report.html').existsSync(), isTrue);
    });

    test('write creates parent directories if needed', () async {
      final deepDir = '${tempDir.path}/a/b/c';

      final result = MatrixResult(name: 'Widget', results: [makeResult()]);

      await MatrixReportWriter.write(result, outputDir: deepDir);

      expect(File('$deepDir/widget_report.json').existsSync(), isTrue);
    });

    test('writeMarkdown creates .md file at expected slug-derived path', () async {
      final result = MatrixResult(name: 'matrixGolden: TestWidget', results: [makeResult()]);

      await MatrixReportWriter.writeMarkdown(result, outputDir: tempDir.path);

      final file = File('${tempDir.path}/matrixgolden__testwidget_report.md');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, startsWith('# matrixGolden: TestWidget'));
      expect(content, contains('## Summary'));
      expect(content, contains('**Total:** 1'));
    });

    test('writeMarkdown with custom outputDir lands in that directory', () async {
      final customDir = '${tempDir.path}/custom';
      final result = MatrixResult(name: 'Widget', results: [makeResult()]);

      await MatrixReportWriter.writeMarkdown(result, outputDir: customDir);

      expect(File('$customDir/widget_report.md').existsSync(), isTrue);
    });
  });

  group('HtmlTemplate integration', () {
    test('renders valid HTML structure', () {
      final result = MatrixResult(
        name: 'TestWidget',
        results: [
          makeResult(),
          makeResult(
            scenario: 'error',
            theme: MatrixTheme.dark,
            status: MatrixResultStatus.failed,
            errorMessage: 'Golden mismatch',
          ),
        ],
        duration: const Duration(seconds: 5),
      );

      final html = HtmlTemplate.render(result);

      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains('<html'));
      expect(html, contains('</html>'));
      expect(html, contains('TestWidget'));
      expect(html, contains('<header>'));
      expect(html, contains('<script>'));
      expect(html, contains('filterCards'));
    });

    test('shows correct counts', () {
      final result = MatrixResult(
        name: 'Widget',
        results: [
          makeResult(),
          makeResult(),
          makeResult(status: MatrixResultStatus.failed, errorMessage: 'err'),
        ],
      );

      final html = HtmlTemplate.render(result);

      expect(html, contains('>3<')); // total
      expect(html, contains('>2<')); // passed
      expect(html, contains('>1<')); // failed
    });

    test('escapes HTML in error messages', () {
      final result = MatrixResult(
        name: 'Widget',
        results: [
          makeResult(
            status: MatrixResultStatus.failed,
            errorMessage: '<script>alert("xss")</script>',
          ),
        ],
      );

      final html = HtmlTemplate.render(result);

      expect(html, isNot(contains('<script>alert')));
      expect(html, contains('&lt;script&gt;'));
    });

    test('generates correct image paths', () {
      final result = MatrixResult(name: 'Widget', results: [makeResult()]);

      final html = HtmlTemplate.render(result);

      // HTML is in goldens/, images at goldens/scenario/file.png
      // So relative path should be scenario/file.png (stripped goldens/)
      expect(html, contains('src="default/light_en_ltr_1x_phonesmall.png"'));
    });

    test('groups by scenario', () {
      final result = MatrixResult(
        name: 'Widget',
        results: [
          makeResult(scenario: 'loading'),
          makeResult(scenario: 'loading'),
          makeResult(scenario: 'error'),
        ],
      );

      final html = HtmlTemplate.render(result);

      expect(html, contains('loading'));
      expect(html, contains('error'));
      // Both should be in details/summary sections
      expect(html, contains('<details'));
      expect(html, contains('<summary>'));
    });

    test('handles empty results', () {
      final result = MatrixResult(name: 'Empty', results: []);

      final html = HtmlTemplate.render(result);

      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains('Empty'));
      expect(html, contains('>0<')); // total = 0
    });

    test('includes filter controls', () {
      final result = MatrixResult(
        name: 'Widget',
        results: [
          makeResult(),
          makeResult(theme: MatrixTheme.dark),
        ],
      );

      final html = HtmlTemplate.render(result);

      expect(html, contains('filter-scenario'));
      expect(html, contains('filter-theme'));
      expect(html, contains('filter-status'));
    });

    test('adds data attributes for filtering', () {
      final result = MatrixResult(name: 'Widget', results: [makeResult()]);

      final html = HtmlTemplate.render(result);

      expect(html, contains('data-scenario="default"'));
      expect(html, contains('data-theme="light"'));
      expect(html, contains('data-status="passed"'));
    });

    test('adds lazy loading to images', () {
      final result = MatrixResult(name: 'Widget', results: [makeResult()]);

      final html = HtmlTemplate.render(result);

      expect(html, contains('loading="lazy"'));
    });
  });
}
