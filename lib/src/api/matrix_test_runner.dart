import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:golden_matrix/src/core/matrix_run_plan.dart';
import 'package:golden_matrix/src/core/report_format.dart';
import 'package:golden_matrix/src/flutter/capture_strategy.dart';
import 'package:golden_matrix/src/flutter/golden_lifecycle.dart';
import 'package:golden_matrix/src/flutter/report_pipeline.dart';
import 'package:golden_matrix/src/flutter/tolerant_comparator.dart';
import 'package:golden_matrix/src/models/matrix_axes.dart';
import 'package:golden_matrix/src/models/matrix_combination.dart';
import 'package:golden_matrix/src/models/matrix_preset.dart';
import 'package:golden_matrix/src/models/matrix_result.dart';
import 'package:golden_matrix/src/models/matrix_rule.dart';
import 'package:golden_matrix/src/models/matrix_sampling.dart';
import 'package:golden_matrix/src/models/matrix_scenario.dart';

/// Builds a widget tree for a given [MatrixCombination].
typedef MatrixWidgetBuilder = CaptureWidgetBuilder;

/// Internal test runner shared by [matrixGolden] and [screenMatrixGolden].
void runMatrixTests(
  String name, {
  required List<MatrixScenario> scenarios,
  required MatrixWidgetBuilder widgetBuilder,
  MatrixAxes? axes,
  MatrixPreset? preset,
  MatrixSampling? sampling,
  int? maxCombinations,
  List<MatrixRule> rules = const [],
  List<String>? scenarioTags,
  String Function(MatrixCombination)? fileNameBuilder,
  Set<MatrixReportFormat> reportFormats = const {},
  String? reportDir,
  bool skip = false,
  double? tolerance,
  bool printSummary = true,
  MatrixSetupCallback? setup,
  bool freezeAnimations = false,
  Duration? captureAfter,
  bool detectStaleGoldens = true,
  double captureScale = 1.0,
}) {
  validateCaptureScale(captureScale, 'captureScale');
  validateTolerance(tolerance);
  final plan = MatrixRunPlan.resolve(
    name: _stripPrefix(name),
    scenarios: scenarios,
    axes: axes,
    preset: preset,
    sampling: sampling,
    rules: rules,
    scenarioTags: scenarioTags,
    maxCombinations: maxCombinations,
    fileNameBuilder: fileNameBuilder,
  );
  plan.warnAboutProblems();

  final effectiveFormats = reportFormats;
  final writeReports = effectiveFormats.isNotEmpty;
  // Stale detection needs per-combination results too, so we record them
  // whenever it's enabled even if no reports are being written.
  final wantStaleDetection = detectStaleGoldens && !plan.usesCustomPaths;
  final recordResults = writeReports || wantStaleDetection;

  final List<MatrixCombinationResult> results = [];
  final stopwatch = Stopwatch()..start();

  group(name, () {
    installToleranceComparator(tolerance);

    for (final entry in plan.byScenario.entries) {
      group(entry.key, () {
        for (final planned in entry.value) {
          final (:combination, :goldenPath) = planned;

          if (skip && recordResults) {
            recordSkipped(results, combination, goldenPath);
          }

          testWidgets(
            _testDescription(combination),
            skip: skip,
            (tester) => executeCapture(
              tester: tester,
              combination: combination,
              goldenPath: goldenPath,
              strategy: ViewportCaptureStrategy(
                widgetBuilder: widgetBuilder,
                freezeAnimations: freezeAnimations,
                captureScale: captureScale,
              ),
              record: recordResults,
              results: results,
              setup: setup,
              captureAfter: captureAfter,
            ),
          );
        }
      });
    }

    if (recordResults) {
      installReportPipeline(
        reportName: name,
        testSlug: plan.name,
        results: results,
        stopwatch: stopwatch,
        reportDir: reportDir,
        printSummary: printSummary,
        formats: effectiveFormats,
        detectStaleGoldens: wantStaleDetection,
      );
    }
  });
}

/// Validates the `tolerance` parameter of the public test functions.
///
/// Called before the enclosing `group()` is declared so the error surfaces at
/// the call site instead of mid-run. `isFinite` matters as much as the range:
/// NaN passes every `< 0 || > 1` check, and then `diffPercent <= NaN` is false
/// for any diff, failing every golden with no explanation.
void validateTolerance(double? value) {
  if (value == null) return;
  if (!value.isFinite || value < 0.0 || value > 1.0) {
    throw ArgumentError.value(value, 'tolerance', 'must be a finite value in range 0.0..1.0');
  }
}

// -- Helpers --

/// Strips the public API prefix ('matrixGolden: ' or 'screenMatrixGolden: ')
/// from a test name to get just the user-provided identifier.
String _stripPrefix(String name) {
  const prefixes = ['matrixGolden: ', 'screenMatrixGolden: '];
  for (final prefix in prefixes) {
    if (name.startsWith(prefix)) return name.substring(prefix.length);
  }
  return name;
}

String _testDescription(MatrixCombination c) {
  final dir = c.direction == TextDirection.ltr ? 'ltr' : 'rtl';
  return '${c.theme.name} ${c.locale} $dir ${c.textScale}x ${c.device.name}';
}
