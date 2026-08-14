import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

import '../_helpers/no_op_comparator.dart';

/// `MatrixRunConfig` only earns its keep if an argument written next to it
/// still wins. These runs are declared eagerly (the runners register groups at
/// declaration time) and each writes a JSON report into its own temp dir; the
/// follow-up `test(...)` reads the report back and checks what actually ran.
void main() {
  GoldenFileComparator? saved;
  setUpAll(() {
    saved = goldenFileComparator;
    goldenFileComparator = NoOpGoldenComparator();
  });
  tearDownAll(() {
    if (saved != null) goldenFileComparator = saved!;
  });

  final dirs = <String, Directory>{};
  Directory dirFor(String key) => dirs[key] ??= Directory.systemTemp.createTempSync('cfg_${key}_');

  tearDownAll(() {
    for (final d in dirs.values) {
      if (d.existsSync()) d.deleteSync(recursive: true);
    }
  });

  Map<String, dynamic> report(String key, String fileName) => jsonDecode(
        File('${dirFor(key).path}/$fileName').readAsStringSync(),
      ) as Map<String, dynamic>;

  Widget box() =>
      const SizedBox(width: 20, height: 10, child: ColoredBox(color: Color(0xFF00AA00)));

  MatrixScenario scenario() => MatrixScenario('s', builder: box);

  // --- 1. A config alone drives the run. ---
  matrixGolden(
    'cfg_only',
    scenarios: [scenario()],
    config: MatrixRunConfig(
      axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
      reportFormats: const {MatrixReportFormat.json},
      reportDir: dirFor('only').path,
      printSummary: false,
      detectStaleGoldens: false,
    ),
  );

  test('a config alone configures the whole run', () {
    expect(report('only', 'matrixgolden__cfg_only_report.json')['total'], 2);
  });

  // --- 2. An explicit argument beats the same field in the config. ---
  matrixGolden(
    'cfg_override',
    scenarios: [scenario()],
    config: MatrixRunConfig(
      axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
      reportFormats: const {MatrixReportFormat.json},
      reportDir: dirFor('override').path,
      printSummary: false,
      detectStaleGoldens: false,
      skip: true,
    ),
    // The config says skip and two themes; the call site says otherwise.
    skip: false,
    axes: const MatrixAxes(themes: [MatrixTheme.dark]),
  );

  test('an explicit argument overrides the config field', () {
    final json = report('override', 'matrixgolden__cfg_override_report.json');
    final results = (json['results'] as List).cast<Map<String, dynamic>>();

    expect(json['total'], 1, reason: 'explicit single-theme axes won');
    expect(json['skipped'], 0, reason: 'explicit skip: false won');
    expect(json['passed'], 1);
    expect(
      results.single['goldenPath'],
      contains('dark_'),
      reason: 'and it is the theme the call site named, not the config',
    );
  });

  // --- 3. skip: true really does come through a config. ---
  matrixGolden(
    'cfg_skip',
    scenarios: [scenario()],
    config: MatrixRunConfig(
      reportFormats: const {MatrixReportFormat.json},
      reportDir: dirFor('skip').path,
      printSummary: false,
      detectStaleGoldens: false,
      skip: true,
    ),
  );

  test('skip travels through the config', () {
    expect(report('skip', 'matrixgolden__cfg_skip_report.json')['skipped'], 1);
  });

  // --- 4. Same object, reused by a second entry point. ---
  final shared = MatrixRunConfig(
    axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
    reportFormats: const {MatrixReportFormat.json},
    reportDir: dirFor('shared').path,
    printSummary: false,
    detectStaleGoldens: false,
  );

  componentMatrixGolden('cfg_component', scenarios: [scenario()], config: shared);
  screenMatrixGolden(
    'cfg_screen',
    appBuilder: (c) => MaterialApp(theme: c.theme.resolve(), home: Scaffold(body: box())),
    states: [scenario()],
    config: shared,
  );

  test('one config drives component and screen runs alike', () {
    expect(
      report('shared', 'componentmatrixgolden__cfg_component_report.json')['total'],
      2,
    );
    expect(
      report('shared', 'screenmatrixgolden__cfg_screen_report.json')['total'],
      2,
    );
  });

  // --- 5. An empty config changes nothing. ---
  matrixGolden(
    'cfg_empty',
    scenarios: [scenario()],
    config: const MatrixRunConfig(),
    reportFormats: const {MatrixReportFormat.json},
    reportDir: dirFor('empty').path,
    printSummary: false,
    detectStaleGoldens: false,
  );

  test('an empty config is indistinguishable from passing none', () {
    final json = report('empty', 'matrixgolden__cfg_empty_report.json');
    expect(json['total'], 1);
    expect(json['passed'], 1);
    expect(json.containsKey('staleGoldens'), isFalse);
  });

  // --- 6. componentMatrixGolden honours an override too. ---
  componentMatrixGolden(
    'cfg_component_override',
    scenarios: [scenario()],
    config: MatrixRunConfig(
      axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
      reportFormats: const {MatrixReportFormat.json},
      reportDir: dirFor('componentoverride').path,
      printSummary: false,
      detectStaleGoldens: false,
    ),
    maxCombinations: 1,
  );

  test('componentMatrixGolden lets the argument win as well', () {
    expect(
      report(
        'componentoverride',
        'componentmatrixgolden__cfg_component_override_report.json',
      )['total'],
      1,
    );
  });

  // --- 7. tolerance validation still fires on a config-supplied value. ---
  test('a bad tolerance in the config is rejected at the call site', () {
    expect(
      () => matrixGolden(
        'cfg_bad_tolerance',
        scenarios: [scenario()],
        config: const MatrixRunConfig(tolerance: double.nan),
      ),
      throwsArgumentError,
    );

    expect(
      () => componentMatrixGolden(
        'cfg_bad_tolerance_component',
        scenarios: [scenario()],
        config: const MatrixRunConfig(tolerance: 2.0),
      ),
      throwsArgumentError,
    );
  });
}
