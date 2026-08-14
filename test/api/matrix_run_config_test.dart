import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

Widget _placeholder() => const SizedBox.shrink();

bool _isDark(MatrixCombination c) => c.theme.isDark;

void main() {
  group('MatrixRunConfig defaults match the bare parameter defaults', () {
    // A config nobody configured has to behave exactly like calling
    // matrixGolden with no optional arguments at all — otherwise passing an
    // empty config would silently change a run.
    const empty = MatrixRunConfig();

    test('every field starts unset', () {
      expect(empty.axes, isNull);
      expect(empty.preset, isNull);
      expect(empty.sampling, isNull);
      expect(empty.maxCombinations, isNull);
      expect(empty.rules, isNull);
      expect(empty.scenarioTags, isNull);
      expect(empty.fileNameBuilder, isNull);
      expect(empty.reportFormats, isNull);
      expect(empty.reportDir, isNull);
      expect(empty.skip, isNull);
      expect(empty.tolerance, isNull);
      expect(empty.printSummary, isNull);
      expect(empty.setup, isNull);
      expect(empty.freezeAnimations, isNull);
      expect(empty.captureAfter, isNull);
      expect(empty.detectStaleGoldens, isNull);
    });

    test('resolved getters fall back to the documented defaults', () {
      expect(empty.resolvedRules, isEmpty);
      expect(empty.resolvedReportFormats, isEmpty);
      expect(empty.resolvedSkip, isFalse);
      expect(empty.resolvedPrintSummary, isTrue);
      expect(empty.resolvedFreezeAnimations, isFalse);
      expect(empty.resolvedDetectStaleGoldens, isTrue);
    });
  });

  group('MatrixRunConfig.merge lets the override win, field by field', () {
    const base = MatrixRunConfig(
      axes: MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
      sampling: MatrixSampling.pairwise,
      maxCombinations: 10,
      rules: [MatrixRule.exclude(_isDark)],
      scenarioTags: ['smoke'],
      reportFormats: {MatrixReportFormat.json},
      reportDir: 'base/dir',
      skip: true,
      tolerance: 0.5,
      printSummary: false,
      freezeAnimations: true,
      captureAfter: Duration(milliseconds: 10),
      detectStaleGoldens: false,
    );

    test('a null field in the override keeps the base value', () {
      final merged = base.merge(const MatrixRunConfig());

      expect(merged.sampling, MatrixSampling.pairwise);
      expect(merged.maxCombinations, 10);
      expect(merged.reportDir, 'base/dir');
      expect(merged.resolvedSkip, isTrue);
      expect(merged.tolerance, 0.5);
      expect(merged.resolvedPrintSummary, isFalse);
      expect(merged.resolvedFreezeAnimations, isTrue);
      expect(merged.resolvedDetectStaleGoldens, isFalse);
      expect(merged.captureAfter, const Duration(milliseconds: 10));
    });

    test('a set field in the override replaces the base value', () {
      final merged = base.merge(
        const MatrixRunConfig(
          sampling: MatrixSampling.smoke,
          maxCombinations: 3,
          reportDir: 'override/dir',
          skip: false,
          tolerance: 0.0,
          printSummary: true,
          freezeAnimations: false,
          detectStaleGoldens: true,
        ),
      );

      expect(merged.sampling, MatrixSampling.smoke);
      expect(merged.maxCombinations, 3);
      expect(merged.reportDir, 'override/dir');
      expect(merged.resolvedSkip, isFalse);
      expect(merged.tolerance, 0.0);
      expect(merged.resolvedPrintSummary, isTrue);
      expect(merged.resolvedFreezeAnimations, isFalse);
      expect(merged.resolvedDetectStaleGoldens, isTrue);
    });

    test('collection fields replace rather than concatenate', () {
      // Merging lists would make it impossible to *narrow* a shared config,
      // and `rules` already merges with the preset's — two merge semantics on
      // one field is how precedence documentation stops being true.
      final merged = base.merge(const MatrixRunConfig(rules: [], reportFormats: {}));

      expect(merged.resolvedRules, isEmpty);
      expect(merged.resolvedReportFormats, isEmpty);
    });

    test('axes and preset override independently', () {
      final merged = base.merge(const MatrixRunConfig(preset: MatrixPreset.componentSmoke));

      expect(merged.axes, base.axes, reason: 'preset does not clear axes');
      expect(merged.preset, MatrixPreset.componentSmoke);
    });

    test('callbacks override too', () {
      String named(MatrixCombination c) => 'named.png';
      final merged = base.merge(MatrixRunConfig(fileNameBuilder: named));

      expect(merged.fileNameBuilder, isNotNull);
      expect(
        merged.fileNameBuilder!(
          const MatrixCombination(
            scenario: MatrixScenario('s', builder: _placeholder),
            theme: MatrixTheme.light,
            locale: Locale('en'),
            textScale: 1.0,
            device: MatrixDevice.phoneSmall,
            direction: TextDirection.ltr,
          ),
        ),
        'named.png',
      );
    });

    test('a config is const-constructible, so it can live next to the preset', () {
      // The whole point of the object is being declared once and reused; Dart
      // canonicalizes identical const instances, which is the observable proof
      // that no field forces a runtime allocation.
      const shared = MatrixRunConfig(
        axes: MatrixAxes(themes: [MatrixTheme.dark]),
        rules: [MatrixRule.exclude(_isDark)],
      );
      const again = MatrixRunConfig(
        axes: MatrixAxes(themes: [MatrixTheme.dark]),
        rules: [MatrixRule.exclude(_isDark)],
      );

      expect(identical(shared, again), isTrue);
    });
  });
}
