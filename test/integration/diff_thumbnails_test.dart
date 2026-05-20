import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

MatrixCombination _combo({String name = 'default'}) => MatrixCombination(
  scenario: MatrixScenario(name, builder: () => const SizedBox.shrink()),
  theme: MatrixTheme.light,
  locale: const Locale('en'),
  textScale: 1.0,
  device: MatrixDevice.phoneSmall,
  direction: TextDirection.ltr,
);

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('diff_thumbs_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<String> renderHtml(MatrixResult result) async {
    await MatrixReportWriter.writeHtml(result, outputDir: tempDir.path);
    final files = tempDir.listSync().whereType<File>().where((f) => f.path.endsWith('.html'));
    return files.first.readAsStringSync();
  }

  group('diff thumbnails in HTML report', () {
    test('passed test → no .diff-thumbs block', () async {
      final result = MatrixResult(
        name: 'matrixGolden: Widget',
        results: [
          MatrixCombinationResult(
            combination: _combo(),
            status: MatrixResultStatus.passed,
            goldenPath: 'goldens/widget/default/light_en_ltr_1x_phonesmall.png',
          ),
        ],
      );
      final html = await renderHtml(result);
      expect(html, isNot(contains('class="diff-thumbs"')));
      expect(html, isNot(contains('_masterImage.png')));
    });

    test('failed test → exactly one .diff-thumbs block with 4 tiles', () async {
      final result = MatrixResult(
        name: 'matrixGolden: Widget',
        results: [
          MatrixCombinationResult(
            combination: _combo(),
            status: MatrixResultStatus.failed,
            goldenPath: 'goldens/widget/default/light_en_ltr_1x_phonesmall.png',
            errorMessage: 'pixel mismatch',
          ),
        ],
      );
      final html = await renderHtml(result);

      // Exactly one diff-thumbs container
      final count = '<div class="diff-thumbs">'.allMatches(html).length;
      expect(count, 1);

      // All four expected failure-PNG references
      const base = 'widget/default/failures/light_en_ltr_1x_phonesmall';
      expect(html, contains('${base}_masterImage.png'));
      expect(html, contains('${base}_testImage.png'));
      expect(html, contains('${base}_isolatedDiff.png'));
      expect(html, contains('${base}_maskedDiff.png'));

      // Captions present
      expect(html, contains('<figcaption>expected</figcaption>'));
      expect(html, contains('<figcaption>actual</figcaption>'));
      expect(html, contains('<figcaption>diff</figcaption>'));
      expect(html, contains('<figcaption>masked</figcaption>'));
    });

    test('mixed pass+fail → number of .diff-thumbs blocks matches failed count', () async {
      final result = MatrixResult(
        name: 'matrixGolden: Widget',
        results: [
          MatrixCombinationResult(
            combination: _combo(name: 'a'),
            status: MatrixResultStatus.passed,
            goldenPath: 'goldens/widget/a/x.png',
          ),
          MatrixCombinationResult(
            combination: _combo(name: 'b'),
            status: MatrixResultStatus.failed,
            goldenPath: 'goldens/widget/b/x.png',
            errorMessage: 'err',
          ),
          MatrixCombinationResult(
            combination: _combo(name: 'c'),
            status: MatrixResultStatus.failed,
            goldenPath: 'goldens/widget/c/x.png',
            errorMessage: 'err',
          ),
          MatrixCombinationResult(
            combination: _combo(name: 'd'),
            status: MatrixResultStatus.skipped,
            goldenPath: 'goldens/widget/d/x.png',
          ),
        ],
      );
      final html = await renderHtml(result);
      expect('<div class="diff-thumbs">'.allMatches(html).length, 2);
    });

    test('each thumb has graceful onerror fallback', () async {
      final result = MatrixResult(
        name: 'matrixGolden: Widget',
        results: [
          MatrixCombinationResult(
            combination: _combo(),
            status: MatrixResultStatus.failed,
            goldenPath: 'goldens/widget/default/light.png',
            errorMessage: 'err',
          ),
        ],
      );
      final html = await renderHtml(result);
      // Four images, each with onerror that hides its <figure> parent.
      final onErrorCount = "onerror=\"this.closest('figure').style.display='none'\""
          .allMatches(html)
          .length;
      expect(onErrorCount, 4);
    });

    test('skipped test → no .diff-thumbs block', () async {
      final result = MatrixResult(
        name: 'matrixGolden: Widget',
        results: [
          MatrixCombinationResult(
            combination: _combo(),
            status: MatrixResultStatus.skipped,
            goldenPath: 'goldens/widget/default/light.png',
          ),
        ],
      );
      final html = await renderHtml(result);
      expect(html, isNot(contains('class="diff-thumbs"')));
    });
  });
}
