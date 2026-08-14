import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:golden_matrix/src/api/matrix_run_config.dart';
import 'package:golden_matrix/src/api/matrix_test_runner.dart';
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

/// Captures component-level goldens at the **intrinsic widget size**.
///
/// Unlike [matrixGolden], which renders the scenario inside a full
/// `Scaffold` and captures the entire device viewport, this function
/// keeps the `MaterialApp` ancestry (so theme, fonts, icons, locale,
/// and overlay context all work normally) but
///
/// - sizes itself to the widget's **natural** width and height via
///   `Align(widthFactor: 1, heightFactor: 1)` — no whitespace pad,
/// - places the `RepaintBoundary` **directly around the widget**, so
///   the captured PNG is exactly the widget's bounded rect (plus
///   optional [padding]).
///
/// Best for small visual primitives — buttons, badges, chips, icons,
/// list tiles — where capturing a full phone-sized canvas is overkill.
/// For full-screen tests use [screenMatrixGolden]; for components that
/// must render inside a Scaffold (AppBar, FAB positioning, etc.) use
/// [matrixGolden].
///
/// ## Example
///
/// ```dart
/// componentMatrixGolden(
///   'ShadButton',
///   scenarios: [
///     MatrixScenario('primary',
///       builder: () => const ShadButton(child: Text('Click me'))),
///     MatrixScenario('destructive',
///       builder: () => const ShadButton.destructive(child: Text('Delete'))),
///   ],
///   axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
/// );
/// ```
///
/// ## Limitations
///
/// - Widgets that **don't have an intrinsic size** (e.g. plain `Container()`
///   without `width`/`height`) will throw a layout error. Wrap such
///   widgets in a `SizedBox(width: ..., height: ...)` inside your
///   scenario builder.
/// - Widgets that need a full `MaterialApp` ancestor — overlays,
///   `Tooltip`, `showDialog`, `Navigator`-pushed routes, `Hero` — won't
///   work here. Use [matrixGolden] or [screenMatrixGolden] instead.
/// - The `devices` axis of [MatrixAxes] is **ignored** in component
///   mode (intrinsic size does not depend on device geometry).
///   The capture pixel density comes from the [pixelRatio] parameter.
///   A multi-device axis is collapsed to its first value before generation,
///   so it multiplies neither tests nor report counters, and rules matching
///   on `c.device` see only that first value.
///
/// ## Parameters
///
/// - [name] — test group name; appears as `componentMatrixGolden: <name>`
///   in the test output and as the leading path segment in golden file
///   paths.
/// - [scenarios] — non-empty list of [MatrixScenario]s to render.
/// - [config] — A reusable [MatrixRunConfig] carrying the sixteen options every
///   entry point shares. Any argument passed directly to this function
///   overrides the same field of the config — see the precedence table on
///   [matrixGolden].
/// - [axes] / [preset] — themes, locales, text scales, directions. The
///   `devices` field is collapsed to a single value, so
///   [MatrixPreset.componentFull] yields 8 combinations here instead of 16.
/// - [sampling] / [maxCombinations] / [rules] / [scenarioTags] — same
///   semantics as [matrixGolden].
/// - [pixelRatio] — capture density (default `1.0`, i.e. goldens are
///   written at logical size). PNG resolution in physical pixels =
///   (widget logical size + [padding]) × this value, so `pixelRatio: 2.0`
///   writes a 20×10 widget as a 40×20 file. Must be > 0.
///   Up to 1.1.2 this value only configured layout and every golden was
///   written at logical size regardless; 1.2.0 made it drive the raster
///   but kept the old `2.0` default, doubling everyone's goldens. Since
///   1.3.0 the default is `1.0` — same size as pre-1.2.0, so 1.2.0 users
///   need one `flutter test --update-goldens` (or `pixelRatio: 2.0` to
///   keep the 1.2.0 files).
///   It affects density only: the widget always lays itself out in the
///   same 800×800 logical surface. Up to 1.4.0 that surface was 800
///   *physical* pixels, so a higher ratio shrank it (400×400 at `2.0`,
///   ~267×267 at `3.0`) and quietly squeezed anything wider.
/// - [padding] — added around the widget inside the boundary so PNG
///   edges have a little visual breathing room. Default
///   `EdgeInsets.all(8)`; pass `EdgeInsets.zero` for tightest crop.
/// - [extraLocalizationsDelegates] — additional delegates merged with
///   the built-in `GlobalMaterialLocalizations`/`GlobalCupertinoLocalizations`/
///   `GlobalWidgetsLocalizations`.
/// - [reportFormats] / [reportDir] / [detectStaleGoldens] / [setup] /
///   [freezeAnimations] / [captureAfter] / [tolerance] / [skip] /
///   [printSummary] / [fileNameBuilder] — same semantics as
///   [matrixGolden].
void componentMatrixGolden(
  String name, {
  required List<MatrixScenario> scenarios,
  MatrixRunConfig? config,
  MatrixAxes? axes,
  MatrixPreset? preset,
  MatrixSampling? sampling,
  int? maxCombinations,
  List<MatrixRule>? rules,
  List<String>? scenarioTags,
  String Function(MatrixCombination)? fileNameBuilder,
  List<LocalizationsDelegate<dynamic>> extraLocalizationsDelegates = const [],
  Set<MatrixReportFormat>? reportFormats,
  String? reportDir,
  bool? skip,
  double? tolerance,
  bool? printSummary,
  MatrixSetupCallback? setup,
  bool? freezeAnimations,
  Duration? captureAfter,
  bool? detectStaleGoldens,
  double pixelRatio = 1.0,
  EdgeInsets padding = const EdgeInsets.all(8),
}) {
  validateCaptureScale(pixelRatio, 'pixelRatio');
  // Explicit arguments fold over the caller's config, so they win.
  final effective = (config ?? const MatrixRunConfig()).merge(
    MatrixRunConfig(
      axes: axes,
      preset: preset,
      sampling: sampling,
      maxCombinations: maxCombinations,
      rules: rules,
      scenarioTags: scenarioTags,
      fileNameBuilder: fileNameBuilder,
      reportFormats: reportFormats,
      reportDir: reportDir,
      skip: skip,
      tolerance: tolerance,
      printSummary: printSummary,
      setup: setup,
      freezeAnimations: freezeAnimations,
      captureAfter: captureAfter,
      detectStaleGoldens: detectStaleGoldens,
    ),
  );
  validateTolerance(effective.tolerance);
  final plan = MatrixRunPlan.resolve(
    name: name,
    scenarios: scenarios,
    axes: effective.axes,
    preset: effective.preset,
    sampling: effective.sampling,
    rules: effective.resolvedRules,
    scenarioTags: effective.scenarioTags,
    maxCombinations: effective.maxCombinations,
    fileNameBuilder: effective.fileNameBuilder,
    pathScheme: MatrixPathScheme.component,
  );
  plan.warnAboutProblems();

  final formats = effective.resolvedReportFormats;
  final skipTests = effective.resolvedSkip;
  final wantStaleDetection = effective.resolvedDetectStaleGoldens && !plan.usesCustomPaths;
  final recordResults = formats.isNotEmpty || wantStaleDetection;

  final results = <MatrixCombinationResult>[];
  final stopwatch = Stopwatch()..start();
  final groupName = 'componentMatrixGolden: $name';

  group(groupName, () {
    installToleranceComparator(effective.tolerance);

    for (final entry in plan.byScenario.entries) {
      group(entry.key, () {
        for (final planned in entry.value) {
          final (:combination, :goldenPath) = planned;

          if (skipTests && recordResults) {
            recordSkipped(results, combination, goldenPath);
          }

          testWidgets(
            _componentTestDescription(combination),
            skip: skipTests,
            (tester) => executeCapture(
              tester: tester,
              combination: combination,
              goldenPath: goldenPath,
              strategy: IntrinsicCaptureStrategy(
                pixelRatio: pixelRatio,
                padding: padding,
                extraLocalizationsDelegates: extraLocalizationsDelegates,
                freezeAnimations: effective.resolvedFreezeAnimations,
              ),
              record: recordResults,
              results: results,
              setup: effective.setup,
              captureAfter: effective.captureAfter,
            ),
          );
        }
      });
    }

    if (recordResults) {
      installReportPipeline(
        reportName: groupName,
        testSlug: plan.name,
        results: results,
        stopwatch: stopwatch,
        reportDir: effective.reportDir,
        printSummary: effective.resolvedPrintSummary,
        formats: formats,
        detectStaleGoldens: wantStaleDetection,
      );
    }
  });
}

// -- Helpers --

String _componentTestDescription(MatrixCombination c) {
  final dir = c.direction == TextDirection.ltr ? 'ltr' : 'rtl';
  final scale = c.textScale % 1 == 0 ? '${c.textScale.toInt()}.0x' : '${c.textScale}x';
  return '${c.scenario.name} ${c.theme.name} ${c.locale.toLanguageTag()} $dir $scale';
}
