import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

import '../_helpers/no_op_comparator.dart';

/// Each `matrixGolden(...)` call below writes its reports into a fresh
/// temp directory via `reportDir:`, then a follow-up `test(...)` asserts
/// which files actually exist there. Together they exercise the
/// `reportFormats` dispatch + the `report:` legacy alias.
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
  final mdOnlyDir = Directory.systemTemp.createTempSync('rf_md_');
  final jsonHtmlDir = Directory.systemTemp.createTempSync('rf_jsonhtml_');
  final emptyDir = Directory.systemTemp.createTempSync('rf_empty_');
  final legacyTrueDir = Directory.systemTemp.createTempSync('rf_legacy_true_');
  final legacyFalseDir = Directory.systemTemp.createTempSync('rf_legacy_false_');
  final reportWinsDir = Directory.systemTemp.createTempSync('rf_report_wins_');

  tearDownAll(() {
    for (final d in [
      defaultDir,
      mdOnlyDir,
      jsonHtmlDir,
      emptyDir,
      legacyTrueDir,
      legacyFalseDir,
      reportWinsDir,
    ]) {
      if (d.existsSync()) d.deleteSync(recursive: true);
    }
  });

  MatrixScenario scenario() => MatrixScenario('default', builder: () => const SizedBox.shrink());

  bool fileExists(Directory dir, String name) => File('${dir.path}/$name').existsSync();

  // 1. Default — all three formats.
  matrixGolden(
    'rf_default',
    scenarios: [scenario()],
    axes: const MatrixAxes(),
    reportDir: defaultDir.path,
    detectStaleGoldens: false,
    printSummary: false,
  );
  test('default reportFormats writes all three files', () {
    expect(fileExists(defaultDir, 'matrixgolden__rf_default_report.json'), isTrue);
    expect(fileExists(defaultDir, 'matrixgolden__rf_default_report.html'), isTrue);
    expect(fileExists(defaultDir, 'matrixgolden__rf_default_report.md'), isTrue);
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

  // 4. Empty set — nothing written.
  matrixGolden(
    'rf_empty',
    scenarios: [scenario()],
    axes: const MatrixAxes(),
    reportDir: emptyDir.path,
    reportFormats: const {},
    detectStaleGoldens: false,
    printSummary: false,
  );
  test('reportFormats: {} writes no report files', () {
    expect(fileExists(emptyDir, 'matrixgolden__rf_empty_report.json'), isFalse);
    expect(fileExists(emptyDir, 'matrixgolden__rf_empty_report.html'), isFalse);
    expect(fileExists(emptyDir, 'matrixgolden__rf_empty_report.md'), isFalse);
  });

  // 5. Legacy report: true — all three (compat with pre-0.16.0).
  matrixGolden(
    'rf_legacy_true',
    scenarios: [scenario()],
    axes: const MatrixAxes(),
    reportDir: legacyTrueDir.path,
    // ignore: deprecated_member_use_from_same_package
    report: true,
    detectStaleGoldens: false,
    printSummary: false,
  );
  test('legacy report:true writes all three (compat)', () {
    expect(fileExists(legacyTrueDir, 'matrixgolden__rf_legacy_true_report.json'), isTrue);
    expect(fileExists(legacyTrueDir, 'matrixgolden__rf_legacy_true_report.html'), isTrue);
    expect(fileExists(legacyTrueDir, 'matrixgolden__rf_legacy_true_report.md'), isTrue);
  });

  // 6. Legacy report: false — nothing (compat).
  matrixGolden(
    'rf_legacy_false',
    scenarios: [scenario()],
    axes: const MatrixAxes(),
    reportDir: legacyFalseDir.path,
    // ignore: deprecated_member_use_from_same_package
    report: false,
    detectStaleGoldens: false,
    printSummary: false,
  );
  test('legacy report:false writes no files (compat)', () {
    expect(fileExists(legacyFalseDir, 'matrixgolden__rf_legacy_false_report.json'), isFalse);
    expect(fileExists(legacyFalseDir, 'matrixgolden__rf_legacy_false_report.html'), isFalse);
    expect(fileExists(legacyFalseDir, 'matrixgolden__rf_legacy_false_report.md'), isFalse);
  });

  // 7. Compat rule — report:false overrides reportFormats:{markdown}.
  matrixGolden(
    'rf_report_wins',
    scenarios: [scenario()],
    axes: const MatrixAxes(),
    reportDir: reportWinsDir.path,
    reportFormats: const {MatrixReportFormat.markdown},
    // ignore: deprecated_member_use_from_same_package
    report: false,
    detectStaleGoldens: false,
    printSummary: false,
  );
  test('legacy report:false overrides reportFormats (compat rule)', () {
    expect(fileExists(reportWinsDir, 'matrixgolden__rf_report_wins_report.md'), isFalse);
  });
}
