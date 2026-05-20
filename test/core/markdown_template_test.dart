import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';
import 'package:golden_matrix/src/core/markdown_template.dart';

MatrixCombination _combo({
  String scenarioName = 'default',
  MatrixTheme theme = MatrixTheme.light,
  Locale locale = const Locale('en'),
  double textScale = 1.0,
  MatrixDevice device = MatrixDevice.phoneSmall,
  TextDirection direction = TextDirection.ltr,
}) {
  return MatrixCombination(
    scenario: MatrixScenario(scenarioName, builder: () => const SizedBox.shrink()),
    theme: theme,
    locale: locale,
    textScale: textScale,
    device: device,
    direction: direction,
  );
}

MatrixCombinationResult _passed(MatrixCombination c, {String? goldenPath}) =>
    MatrixCombinationResult(
      combination: c,
      status: MatrixResultStatus.passed,
      goldenPath: goldenPath ?? 'goldens/x/default/light.png',
    );

MatrixCombinationResult _failed(MatrixCombination c, String error) => MatrixCombinationResult(
  combination: c,
  status: MatrixResultStatus.failed,
  goldenPath: 'goldens/x/default/light.png',
  errorMessage: error,
);

void main() {
  group('MarkdownTemplate.render', () {
    test('clean run — no Failed or Stale sections', () {
      final result = MatrixResult(
        name: 'matrixGolden: Clean',
        results: [
          _passed(_combo()),
          _passed(_combo(scenarioName: 'other')),
        ],
        duration: const Duration(milliseconds: 320),
      );

      final md = MarkdownTemplate.render(result);
      expect(md, startsWith('# matrixGolden: Clean'));
      expect(md, contains('## Summary'));
      expect(md, contains('**Total:** 2'));
      expect(md, contains('**Passed:** 2'));
      expect(md, contains('**Duration:** 320ms'));
      expect(md, isNot(contains('## Failed')));
      expect(md, isNot(contains('## Stale goldens')));
      expect(md, contains('[View HTML report]('));
    });

    test('single failure — Failed table with one row', () {
      final c = _combo(scenarioName: 'broken', theme: MatrixTheme.dark);
      final result = MatrixResult(
        name: 'matrixGolden: Widget',
        results: [_passed(_combo()), _failed(c, 'pixel diff 5%')],
        duration: const Duration(seconds: 1, milliseconds: 50),
      );

      final md = MarkdownTemplate.render(result);
      expect(md, contains('**Failed:** 1'));
      expect(md, contains('## Failed'));
      expect(md, contains('| Scenario | Theme | Locale | Dir | Scale | Device | Error |'));
      expect(md, contains('| broken | dark | en'));
      expect(md, contains('| ltr | 1x | phoneSmall'));
      expect(md, contains('pixel diff 5%'));
    });

    test('multiple failures — all rows in declaration order', () {
      final results = [
        _failed(_combo(scenarioName: 'a'), 'err-a'),
        _passed(_combo(scenarioName: 'b')),
        _failed(_combo(scenarioName: 'c'), 'err-c'),
      ];
      final md = MarkdownTemplate.render(
        MatrixResult(name: 'matrixGolden: Multi', results: results),
      );
      final aIdx = md.indexOf('err-a');
      final cIdx = md.indexOf('err-c');
      expect(aIdx, greaterThan(0));
      expect(cIdx, greaterThan(0));
      expect(aIdx, lessThan(cIdx));
    });

    test('stale goldens — bullet list present', () {
      final result = MatrixResult(
        name: 'matrixGolden: Widget',
        results: [_passed(_combo())],
        staleGoldens: const ['goldens/widget/old/light.png', 'goldens/widget/old/dark.png'],
      );

      final md = MarkdownTemplate.render(result);
      expect(md, contains('**Stale goldens:** 2'));
      expect(md, contains('## Stale goldens'));
      expect(md, contains('- `goldens/widget/old/light.png`'));
      expect(md, contains('- `goldens/widget/old/dark.png`'));
    });

    test('warnings counted in summary', () {
      final c = _combo();
      final result = MatrixResult(
        name: 'matrixGolden: Widget',
        results: [
          MatrixCombinationResult(
            combination: c,
            status: MatrixResultStatus.passed,
            goldenPath: 'goldens/x/d/l.png',
            warnings: const ['Overflow X', 'Overflow Y'],
          ),
        ],
      );
      final md = MarkdownTemplate.render(result);
      expect(md, contains('**Warnings:** 2'));
    });

    test('HTML link points to slug-derived filename', () {
      final result = MatrixResult(name: 'matrixGolden: My Widget!', results: [_passed(_combo())]);
      final md = MarkdownTemplate.render(result);
      // slugify replaces non-alphanumeric with _
      expect(md, contains('[View HTML report](matrixgolden__my_widget__report.html)'));
    });

    test('long error message is truncated to one line', () {
      final big = 'A' * 200 + '\nB' * 50;
      final result = MatrixResult(name: 'matrixGolden: Widget', results: [_failed(_combo(), big)]);
      final md = MarkdownTemplate.render(result);
      // Truncation marker present
      expect(md, contains('…'));
      // No multi-line cell (table row must stay on one line)
      final tableRow = md.split('\n').firstWhere((l) => l.startsWith('| default |'));
      expect(tableRow.contains('\n'), isFalse);
    });

    test('pipe in error message is escaped for markdown table', () {
      final result = MatrixResult(
        name: 'matrixGolden: Widget',
        results: [_failed(_combo(), 'expected | actual differ')],
      );
      final md = MarkdownTemplate.render(result);
      expect(md, contains(r'expected \| actual differ'));
    });

    test('ends with single trailing newline', () {
      final result = MatrixResult(name: 'matrixGolden: Widget', results: [_passed(_combo())]);
      final md = MarkdownTemplate.render(result);
      expect(md.endsWith('\n'), isTrue);
      expect(md.endsWith('\n\n'), isFalse);
    });
  });
}
