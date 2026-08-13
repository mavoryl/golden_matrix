import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:golden_matrix/src/core/matrix_run_plan.dart';
import 'package:golden_matrix/src/core/report_format.dart';
import 'package:golden_matrix/src/flutter/golden_lifecycle.dart';
import 'package:golden_matrix/src/flutter/pump_helpers.dart';
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
typedef MatrixWidgetBuilder = Widget Function(MatrixCombination combination);

/// Key used for the [RepaintBoundary] that wraps the golden capture target.
const _goldenBoundaryKey = ValueKey('__golden_matrix_boundary__');

/// Callback type for `matrixGolden`/`screenMatrixGolden` `setup:` parameter.
///
/// Runs after the widget has been pumped and settled, before the golden
/// file is captured. Use to drive interactions like `tester.tap(...)`,
/// `tester.enterText(...)`, or scrolling — anything needed to bring the
/// widget into the visual state you want to snapshot.
typedef MatrixSetupCallback = Future<void> Function(
  WidgetTester tester,
  MatrixCombination combination,
);

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
            (tester) => _executeGoldenTest(
              tester: tester,
              combination: combination,
              goldenPath: goldenPath,
              widgetBuilder: widgetBuilder,
              report: recordResults,
              results: results,
              setup: setup,
              freezeAnimations: freezeAnimations,
              captureAfter: captureAfter,
              captureScale: captureScale,
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

// -- Capture --

/// Compares the widget under [boundaryKey] against the golden at [goldenPath],
/// rasterizing at [captureScale] physical pixels per logical pixel.
///
/// At the default scale of 1.0 this is the plain `matchesGoldenFile(Finder)`
/// path, byte-for-byte what golden_matrix has always produced: flutter_test's
/// `captureImage` rasterizes the boundary's layer at `pixelRatio: 1.0`,
/// *regardless* of `tester.view.devicePixelRatio` — the device-pixel-ratio
/// transform lives in `RenderView`, above the boundary, so it never enters the
/// captured layer.
///
/// Above 1.0 the boundary is rasterized explicitly and the resulting image is
/// handed to the matcher (which accepts a `ui.Image` as well as a `Finder`).
/// The 1.0 case deliberately keeps the old path so existing goldens cannot
/// shift by a rounding pixel.
///
/// Used internally by `matrixGolden` / `screenMatrixGolden` /
/// `componentMatrixGolden`; also covered by unit tests directly.
Future<void> expectMatchesGolden(
  WidgetTester tester,
  Key boundaryKey,
  String goldenPath, {
  required double captureScale,
}) async {
  if (captureScale == 1.0) {
    await expectLater(find.byKey(boundaryKey), matchesGoldenFile(goldenPath));
    return;
  }

  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
  final image = await boundary.toImage(pixelRatio: captureScale);
  try {
    // The matcher does not take ownership of an image it did not create,
    // so disposal is ours.
    await expectLater(image, matchesGoldenFile(goldenPath));
  } finally {
    image.dispose();
  }
}

/// Throws [ArgumentError] unless [value] is a positive, finite capture scale.
void validateCaptureScale(double value, String name) {
  if (value <= 0 || !value.isFinite) {
    throw ArgumentError.value(value, name, 'must be > 0');
  }
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

// -- Test execution --

Future<void> _executeGoldenTest({
  required WidgetTester tester,
  required MatrixCombination combination,
  required String goldenPath,
  required MatrixWidgetBuilder widgetBuilder,
  required bool report,
  required List<MatrixCombinationResult> results,
  MatrixSetupCallback? setup,
  bool freezeAnimations = false,
  Duration? captureAfter,
  double captureScale = 1.0,
}) async {
  PumpHelpers.configureView(tester, combination.device);

  await runGoldenLifecycle(
    tester: tester,
    combination: combination,
    goldenPath: goldenPath,
    record: report,
    results: results,
    build: () => RepaintBoundary(
      key: _goldenBoundaryKey,
      child: TickerMode(enabled: !freezeAnimations, child: widgetBuilder(combination)),
    ),
    pump: (widget) async {
      await tester.pumpWidget(widget);

      // Initial settle. When captureAfter is set, use pump(duration) instead
      // of pumpAndSettle — pumpAndSettle would hang on infinite animations
      // (the very use case captureAfter exists for).
      if (captureAfter != null) {
        await tester.pump(captureAfter);
      } else {
        await tester.pumpAndSettle();
      }
    },
    setup: setup == null
        ? null
        : () async {
            await setup(tester, combination);
            if (captureAfter != null) {
              await tester.pump(captureAfter);
            } else {
              await tester.pumpAndSettle();
            }
          },
    compare: () => expectMatchesGolden(
      tester,
      _goldenBoundaryKey,
      goldenPath,
      captureScale: captureScale,
    ),
    onFinally: () => PumpHelpers.resetView(tester),
  );
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
