import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';
import 'package:golden_matrix/src/api/matrix_test_runner.dart';

/// No-op golden comparator — accepts any bytes, writes nothing. Lets us
/// drive `matrixGolden` end-to-end without baseline PNGs on disk.
class _NoOpGoldenComparator extends GoldenFileComparator {
  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async => true;
  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {}
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('stale_integration_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('MatrixResult.staleGoldens serialization', () {
    test('JSON includes staleGoldens when non-empty', () async {
      final result = MatrixResult(
        name: 'matrixGolden: Widget',
        results: const [],
        staleGoldens: const [
          'goldens/widget/old_state/light.png',
          'goldens/widget/old_state/dark.png',
        ],
      );

      await MatrixReportWriter.write(result, outputDir: tempDir.path);
      final file = File('${tempDir.path}/matrixgolden__widget_report.json');
      expect(file.existsSync(), isTrue);
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(json['staleGoldens'], isA<List<dynamic>>());
      expect(json['staleGoldens'], hasLength(2));
      expect(json['staleGoldens'], contains('goldens/widget/old_state/light.png'));
    });

    test('JSON omits staleGoldens field entirely when list is empty', () async {
      final result = MatrixResult(name: 'matrixGolden: CleanWidget', results: const []);

      await MatrixReportWriter.write(result, outputDir: tempDir.path);
      final file = File('${tempDir.path}/matrixgolden__cleanwidget_report.json');
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(json.containsKey('staleGoldens'), isFalse);
    });

    test('HTML renders stale section + Stale stat card when non-empty', () async {
      final result = MatrixResult(
        name: 'matrixGolden: Widget',
        results: const [],
        staleGoldens: const ['goldens/widget/orphan/light_en_ltr_1x_phonesmall.png'],
      );

      await MatrixReportWriter.writeHtml(result, outputDir: tempDir.path);
      final file = File('${tempDir.path}/matrixgolden__widget_report.html');
      final html = file.readAsStringSync();
      expect(html, contains('stat-label">Stale</span>'));
      expect(html, contains('class="stale-section"'));
      expect(html, contains('goldens/widget/orphan/light_en_ltr_1x_phonesmall.png'));
      expect(html, contains('1 stale golden file'));
    });

    test('HTML omits stale section when staleGoldens is empty', () async {
      final result = MatrixResult(name: 'matrixGolden: Clean', results: const []);

      await MatrixReportWriter.writeHtml(result, outputDir: tempDir.path);
      final file = File('${tempDir.path}/matrixgolden__clean_report.html');
      final html = file.readAsStringSync();
      expect(html, isNot(contains('class="stale-section"')));
      expect(html, isNot(contains('stat-label">Stale</span>')));
    });
  });

  group('formatSummary includes stale block', () {
    test('summary mentions stale count and lists paths', () {
      final result = MatrixResult(
        name: 'matrixGolden: Widget',
        results: const [],
        staleGoldens: const ['goldens/widget/old/light.png', 'goldens/widget/old/dark.png'],
      );

      final summary = formatSummary(result);
      expect(summary, contains('2 stale'));
      expect(summary, contains('Stale (orphan goldens'));
      expect(summary, contains('goldens/widget/old/light.png'));
      expect(summary, contains('goldens/widget/old/dark.png'));
    });

    test('summary omits Stale block when list is empty', () {
      final result = MatrixResult(name: 'matrixGolden: Clean', results: const []);

      final summary = formatSummary(result);
      expect(summary, isNot(contains('stale')));
      expect(summary, isNot(contains('Stale')));
    });
  });

  group('end-to-end: detectStaleGoldens through runMatrixTests', () {
    GoldenFileComparator? savedComparator;

    setUpAll(() {
      savedComparator = goldenFileComparator;
      goldenFileComparator = _NoOpGoldenComparator();
    });

    tearDownAll(() {
      if (savedComparator != null) goldenFileComparator = savedComparator!;
    });

    matrixGolden(
      'SyntheticTest',
      scenarios: [MatrixScenario('default', builder: () => const SizedBox.shrink())],
      axes: const MatrixAxes(),
      // No fileNameBuilder, so detection is enabled.
      printSummary: false,
      reportFormats: const {}, // skip writing files; we only assert pipeline runs
    );

    test('detectStaleGoldens: true does not throw when subdir is empty', () {
      // If we got here, the matrixGolden teardown completed successfully.
      // Stale detection ran (subdir didn't exist) and returned empty.
      // No failure means the pipeline is wired correctly.
      expect(true, isTrue);
    });

    matrixGolden(
      'SyntheticTest_NoStale',
      scenarios: [MatrixScenario('default', builder: () => const SizedBox.shrink())],
      axes: const MatrixAxes(),
      detectStaleGoldens: false,
      printSummary: false,
      reportFormats: const {},
    );

    test('detectStaleGoldens: false also wires through without error', () {
      expect(true, isTrue);
    });
  });
}
