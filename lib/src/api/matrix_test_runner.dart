import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:golden_matrix/src/api/matrix_run_config.dart';
import 'package:golden_matrix/src/core/matrix_run_plan.dart';
import 'package:golden_matrix/src/flutter/capture_strategy.dart';
import 'package:golden_matrix/src/flutter/golden_lifecycle.dart';
import 'package:golden_matrix/src/flutter/report_pipeline.dart';
import 'package:golden_matrix/src/flutter/tolerant_comparator.dart';
import 'package:golden_matrix/src/models/matrix_combination.dart';
import 'package:golden_matrix/src/models/matrix_result.dart';
import 'package:golden_matrix/src/models/matrix_scenario.dart';

/// Builds a widget tree for a given [MatrixCombination].
typedef MatrixWidgetBuilder = CaptureWidgetBuilder;

/// Internal test runner shared by [matrixGolden] and [screenMatrixGolden].
///
/// Takes the already-merged [config] — the entry points fold their explicit
/// arguments over the caller's config before getting here, so precedence is
/// decided in exactly one place.
void runMatrixTests(
  String name, {
  required List<MatrixScenario> scenarios,
  required MatrixWidgetBuilder widgetBuilder,
  required MatrixRunConfig config,
  double captureScale = 1.0,
}) {
  validateCaptureScale(captureScale, 'captureScale');
  validateTolerance(config.tolerance);
  final plan = MatrixRunPlan.resolve(
    name: _stripPrefix(name),
    scenarios: scenarios,
    axes: config.axes,
    preset: config.preset,
    sampling: config.sampling,
    rules: config.resolvedRules,
    scenarioTags: config.scenarioTags,
    maxCombinations: config.maxCombinations,
    fileNameBuilder: config.fileNameBuilder,
  );
  plan.warnAboutProblems();

  final formats = config.resolvedReportFormats;
  final skip = config.resolvedSkip;
  // Stale detection needs per-combination results too, so we record them
  // whenever it's enabled even if no reports are being written.
  final wantStaleDetection = config.resolvedDetectStaleGoldens && !plan.usesCustomPaths;
  final recordResults = formats.isNotEmpty || wantStaleDetection;

  final List<MatrixCombinationResult> results = [];
  final stopwatch = Stopwatch()..start();

  group(name, () {
    installToleranceComparator(config.tolerance);

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
                freezeAnimations: config.resolvedFreezeAnimations,
                captureScale: captureScale,
              ),
              record: recordResults,
              results: results,
              setup: config.setup,
              captureAfter: config.captureAfter,
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
        reportDir: config.reportDir,
        printSummary: config.resolvedPrintSummary,
        formats: formats,
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
