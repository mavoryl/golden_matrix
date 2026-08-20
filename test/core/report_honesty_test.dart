import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';
import 'package:golden_matrix/src/core/junit_template.dart';
import 'package:golden_matrix/src/core/markdown_template.dart';

MatrixCombination _combo() => MatrixCombination(
      scenario: MatrixScenario('s', builder: () => const SizedBox.shrink()),
      theme: MatrixTheme.light,
      locale: const Locale('en'),
      textScale: 1.0,
      device: MatrixDevice.phoneSmall,
      direction: TextDirection.ltr,
    );

MatrixResult _result(List<MatrixCombinationResult> results) =>
    MatrixResult(name: 'matrixGolden: Widget', results: results);

void main() {
  group('Markdown does not advertise reports that were not written', () {
    final passing = _result([
      MatrixCombinationResult(
        combination: _combo(),
        status: MatrixResultStatus.passed,
        goldenPath: 'goldens/widget/s/light_en_ltr_1x_phonesmall.png',
      ),
    ]);

    test('no HTML link when html was not requested', () {
      final md = MarkdownTemplate.render(
        passing,
        formats: const {MatrixReportFormat.markdown},
      );

      expect(md, isNot(contains('View HTML report')));
    });

    test('HTML link when html was requested alongside markdown', () {
      final md = MarkdownTemplate.render(
        passing,
        formats: const {MatrixReportFormat.markdown, MatrixReportFormat.html},
      );

      expect(md, contains('View HTML report'));
      expect(md, contains('matrixgolden__widget_report.html'));
    });

    test('writeMarkdown passes the requested formats through', () async {
      final dir = Directory.systemTemp.createTempSync('md_honesty_');
      addTearDown(() => dir.deleteSync(recursive: true));

      await MatrixReportWriter.writeMarkdown(
        passing,
        outputDir: dir.path,
        formats: const {MatrixReportFormat.markdown},
      );

      final md = File('${dir.path}/matrixgolden__widget_report.md').readAsStringSync();
      expect(md, isNot(contains('View HTML report')));
    });
  });

  group('JUnit reports the phase a combination failed in', () {
    String renderWith(MatrixFailurePhase? phase) => JunitTemplate.render(
          _result([
            MatrixCombinationResult(
              combination: _combo(),
              status: MatrixResultStatus.failed,
              goldenPath: 'goldens/widget/s/light_en_ltr_1x_phonesmall.png',
              errorMessage: 'boom',
              failurePhase: phase,
            ),
          ]),
        );

    test('a layout failure is not labelled a pixel mismatch', () {
      // Every failure used to be type="PixelMismatch", including errors thrown
      // long before any pixel was compared.
      final xml = renderWith(MatrixFailurePhase.pump);

      expect(xml, isNot(contains('PixelMismatch')));
      expect(xml, contains('type="PumpError"'));
    });

    test('a builder failure is labelled as such', () {
      expect(renderWith(MatrixFailurePhase.build), contains('type="BuildError"'));
    });

    test('a setup failure is labelled as such', () {
      expect(renderWith(MatrixFailurePhase.setup), contains('type="SetupError"'));
    });

    test('a comparison failure is labelled as a golden mismatch', () {
      expect(renderWith(MatrixFailurePhase.comparison), contains('type="GoldenMismatch"'));
    });

    test('an unclassified failure falls back to a neutral type', () {
      final xml = renderWith(null);

      expect(xml, contains('type="Failure"'));
      expect(xml, isNot(contains('PixelMismatch')));
    });
  });

  group('MatrixCombinationResult carries the failure phase', () {
    test('phase reaches JSON when set', () {
      final json = MatrixCombinationResult(
        combination: _combo(),
        status: MatrixResultStatus.failed,
        goldenPath: 'goldens/widget/s/light_en_ltr_1x_phonesmall.png',
        errorMessage: 'boom',
        failurePhase: MatrixFailurePhase.setup,
      ).toJson();

      expect(json['phase'], 'setup');
    });

    test('phase is absent from JSON for a passing combination', () {
      final json = MatrixCombinationResult(
        combination: _combo(),
        status: MatrixResultStatus.passed,
        goldenPath: 'goldens/widget/s/light_en_ltr_1x_phonesmall.png',
      ).toJson();

      expect(json.containsKey('phase'), isFalse);
    });
  });

  group('every combination carries its own time', () {
    // JUnit hardcoded `time="0"` on every `<testcase>`, so no CI dashboard could
    // rank slow combinations and no per-suite total ever added up. The number
    // was not merely rounded — it was never measured.
    MatrixCombinationResult timed(Duration duration) => MatrixCombinationResult(
          combination: _combo(),
          status: MatrixResultStatus.passed,
          goldenPath: 'goldens/widget/s/light_en_ltr_1x_phonesmall.png',
          duration: duration,
        );

    test('a result nobody timed reports zero rather than a fabricated number', () {
      expect(timed(Duration.zero).duration, Duration.zero);
      expect(
        MatrixCombinationResult(
          combination: _combo(),
          status: MatrixResultStatus.skipped,
          goldenPath: 'goldens/widget/s/light.png',
        ).duration,
        Duration.zero,
      );
    });

    test('JSON carries the per-combination duration', () {
      expect(timed(const Duration(milliseconds: 12)).toJson()['durationMs'], 12);
    });

    test('JUnit renders the per-case duration in seconds', () {
      final xml = JunitTemplate.render(_result([timed(const Duration(milliseconds: 1234))]));

      expect(xml, contains('time="1.234"'));
      expect(xml, isNot(contains('time="0"')));
    });

    test('a testsuite reports the sum of its cases', () {
      final xml = JunitTemplate.render(
        _result([
          timed(const Duration(milliseconds: 500)),
          timed(const Duration(milliseconds: 250)),
        ]),
      );
      final suite = xml.split('\n').firstWhere((line) => line.contains('<testsuite '));

      expect(suite, contains('time="0.750"'));
    });
  });
}
