import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

import '../_helpers/no_op_comparator.dart';

/// Each `matrixGolden(...)` call below writes its reports into a fresh
/// temp directory via `reportDir:`, then a follow-up `test(...)` asserts
/// which files actually exist there. Together they exercise the
/// `reportFormats` dispatch (including the opt-in default and junit).
void main() {
  GoldenFileComparator? saved;

  setUpAll(() {
    saved = goldenFileComparator;
    goldenFileComparator = NoOpGoldenComparator();
  });

  tearDownAll(() {
    if (saved != null) goldenFileComparator = saved!;
  });

  // Allocate dirs up-front so they're stable across the synchronous group
  // construction (matrixGolden registers groups eagerly).
  final defaultDir = Directory.systemTemp.createTempSync('rf_default_');
  final omittedDir = Directory.systemTemp.createTempSync('rf_omitted_');
  final mdOnlyDir = Directory.systemTemp.createTempSync('rf_md_');
  final jsonHtmlDir = Directory.systemTemp.createTempSync('rf_jsonhtml_');
  final junitOnlyDir = Directory.systemTemp.createTempSync('rf_junit_');

  tearDownAll(() {
    for (final d in [defaultDir, omittedDir, mdOnlyDir, jsonHtmlDir, junitOnlyDir]) {
      if (d.existsSync()) d.deleteSync(recursive: true);
    }
  });

  MatrixScenario scenario() => MatrixScenario('default', builder: () => const SizedBox.shrink());

  bool fileExists(Directory dir, String name) => File('${dir.path}/$name').existsSync();

  // 1. defaultReportFormats — the opt-in bundle writes all three formats.
  matrixGolden(
    'rf_default',
    scenarios: [scenario()],
    axes: const MatrixAxes(),
    reportDir: defaultDir.path,
    reportFormats: defaultReportFormats,
    detectStaleGoldens: false,
    printSummary: false,
  );
  test('defaultReportFormats writes all three files', () {
    expect(fileExists(defaultDir, 'matrixgolden__rf_default_report.json'), isTrue);
    expect(fileExists(defaultDir, 'matrixgolden__rf_default_report.html'), isTrue);
    expect(fileExists(defaultDir, 'matrixgolden__rf_default_report.md'), isTrue);
  });

  // 1b. reportFormats omitted — reports are opt-in since 1.3.0, so nothing
  //     lands on disk.
  matrixGolden(
    'rf_omitted',
    scenarios: [scenario()],
    axes: const MatrixAxes(),
    reportDir: omittedDir.path,
    detectStaleGoldens: false,
    printSummary: false,
  );
  test('omitting reportFormats writes no report files', () {
    for (final ext in ['json', 'html', 'md', 'xml']) {
      expect(
        fileExists(omittedDir, 'matrixgolden__rf_omitted_report.$ext'),
        isFalse,
        reason: 'reports must be opt-in; found a .$ext report',
      );
    }
  });

  // 2. {markdown} — only .md is written.
  matrixGolden(
    'rf_md',
    scenarios: [scenario()],
    axes: const MatrixAxes(),
    reportDir: mdOnlyDir.path,
    reportFormats: const {MatrixReportFormat.markdown},
    detectStaleGoldens: false,
    printSummary: false,
  );
  test('reportFormats: {markdown} writes only the .md file', () {
    expect(fileExists(mdOnlyDir, 'matrixgolden__rf_md_report.md'), isTrue);
    expect(fileExists(mdOnlyDir, 'matrixgolden__rf_md_report.json'), isFalse);
    expect(fileExists(mdOnlyDir, 'matrixgolden__rf_md_report.html'), isFalse);
  });

  // 3. {json, html} — markdown is absent.
  matrixGolden(
    'rf_jsonhtml',
    scenarios: [scenario()],
    axes: const MatrixAxes(),
    reportDir: jsonHtmlDir.path,
    reportFormats: const {MatrixReportFormat.json, MatrixReportFormat.html},
    detectStaleGoldens: false,
    printSummary: false,
  );
  test('reportFormats: {json, html} omits markdown', () {
    expect(fileExists(jsonHtmlDir, 'matrixgolden__rf_jsonhtml_report.json'), isTrue);
    expect(fileExists(jsonHtmlDir, 'matrixgolden__rf_jsonhtml_report.html'), isTrue);
    expect(fileExists(jsonHtmlDir, 'matrixgolden__rf_jsonhtml_report.md'), isFalse);
  });

  // 4. {junit} — only .xml is written; .json/.html/.md absent.
  matrixGolden(
    'rf_junit',
    scenarios: [scenario()],
    axes: const MatrixAxes(),
    reportDir: junitOnlyDir.path,
    reportFormats: const {MatrixReportFormat.junit},
    detectStaleGoldens: false,
    printSummary: false,
  );
  test('reportFormats: {junit} writes only the .xml file', () {
    expect(fileExists(junitOnlyDir, 'matrixgolden__rf_junit_report.xml'), isTrue);
    expect(fileExists(junitOnlyDir, 'matrixgolden__rf_junit_report.json'), isFalse);
    expect(fileExists(junitOnlyDir, 'matrixgolden__rf_junit_report.html'), isFalse);
    expect(fileExists(junitOnlyDir, 'matrixgolden__rf_junit_report.md'), isFalse);
  });

  // 5. defaultReportFormats does NOT include junit (opt-in).
  test('defaultReportFormats omits junit', () {
    expect(fileExists(defaultDir, 'matrixgolden__rf_default_report.xml'), isFalse);
  });
}
