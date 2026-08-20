import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';
import 'package:golden_matrix/src/core/join_path.dart';

Widget _placeholder() => const SizedBox.shrink();

MatrixResult _result(String name) => MatrixResult(
      name: name,
      results: const [
        MatrixCombinationResult(
          combination: MatrixCombination(
            scenario: MatrixScenario('s', builder: _placeholder),
            theme: MatrixTheme.light,
            locale: Locale('en'),
            textScale: 1.0,
            device: MatrixDevice.phoneSmall,
            direction: TextDirection.ltr,
          ),
          status: MatrixResultStatus.passed,
          goldenPath: 'goldens/x/s/light.png',
        ),
      ],
    );

void main() {
  final sep = Platform.pathSeparator;

  group('joinPath', () {
    test('joins with the platform separator', () {
      expect(joinPath('a', 'b'), 'a${sep}b');
    });

    test('does not double a separator the base already ends with', () {
      // The report writer used to glue paths with a literal `'$dir/…'`, so a
      // caller-supplied directory ending in a separator produced `a//b` while
      // the runner's own path handling used `Platform.pathSeparator`. Two
      // conventions in one package is how the Windows story stayed broken.
      expect(joinPath('a$sep', 'b'), 'a${sep}b');
    });

    test('leaves a bare base alone', () {
      expect(joinPath('', 'b'), '${sep}b');
    });
  });

  group('MatrixReportWriter.reportFileName', () {
    test('one base name, one extension per format', () {
      expect(
        MatrixReportWriter.reportFileName('matrixGolden: Foo', MatrixReportFormat.json),
        'matrixgolden__foo_report.json',
      );
      expect(
        MatrixReportWriter.reportFileName('matrixGolden: Foo', MatrixReportFormat.html),
        'matrixgolden__foo_report.html',
      );
      expect(
        MatrixReportWriter.reportFileName('matrixGolden: Foo', MatrixReportFormat.markdown),
        'matrixgolden__foo_report.md',
      );
      expect(
        MatrixReportWriter.reportFileName('matrixGolden: Foo', MatrixReportFormat.junit),
        'matrixgolden__foo_report.xml',
      );
    });

    test('two run names can slug to one file — and that is the collision', () {
      // `slugify` collapses every non-alphanumeric run to `_`, so these are the
      // same file. Silently overwriting one report with another is the defect
      // `claimReportName` warns about.
      expect(
        MatrixReportWriter.reportFileName('A/B', MatrixReportFormat.json),
        MatrixReportWriter.reportFileName('A B', MatrixReportFormat.json),
      );
    });
  });

  group('report file name collisions are announced', () {
    setUp(MatrixReportWriter.resetReportNameClaims);
    tearDown(MatrixReportWriter.resetReportNameClaims);

    List<String> claimAll(List<String> runNames) {
      final lines = <String>[];
      final original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => lines.add(message ?? '');
      try {
        for (final name in runNames) {
          MatrixReportWriter.claimReportName(name);
        }
      } finally {
        debugPrint = original;
      }
      return lines;
    }

    test('distinct run names are silent', () {
      expect(claimAll(['matrixGolden: Alpha', 'matrixGolden: Beta']), isEmpty);
    });

    test('the same run name twice is silent — that is one run, reported once', () {
      // `installReportPipeline` runs per group declaration; re-declaring the
      // same run in a rerun must not accuse it of colliding with itself.
      expect(claimAll(['matrixGolden: Alpha', 'matrixGolden: Alpha']), isEmpty);
    });

    test('two run names slugging to one file name both get named', () {
      final lines = claimAll(['matrixGolden: A/B', 'matrixGolden: A B']);

      expect(lines.single, startsWith('golden_matrix: '));
      expect(lines.single, contains('matrixgolden__a_b_report'));
      expect(lines.single, contains('matrixGolden: A/B'));
      expect(lines.single, contains('matrixGolden: A B'));
    });

    test('a third colliding name warns again rather than going quiet', () {
      final lines = claimAll(['A/B', 'A B', r'A\B']);

      expect(lines.length, 2);
    });
  });

  group('writeAll respects a directory that ends in a separator', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('report_paths_');
      MatrixReportWriter.resetReportNameClaims();
    });
    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('the file lands exactly where joinPath says', () async {
      await MatrixReportWriter.writeAll(
        _result('matrixGolden: Sep'),
        outputDir: '${dir.path}$sep',
        formats: const {MatrixReportFormat.json},
      );

      final written = dir.listSync().whereType<File>().single;
      expect(written.path, joinPath(dir.path, 'matrixgolden__sep_report.json'));
    });
  });
}
