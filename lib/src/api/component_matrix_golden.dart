import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:golden_matrix/src/api/matrix_test_runner.dart';
import 'package:golden_matrix/src/core/matrix_run_plan.dart';
import 'package:golden_matrix/src/core/report_format.dart';
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

const _componentBoundaryKey = ValueKey('__golden_matrix_component_boundary__');

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
  MatrixAxes? axes,
  MatrixPreset? preset,
  MatrixSampling? sampling,
  int? maxCombinations,
  List<MatrixRule> rules = const [],
  List<String>? scenarioTags,
  String Function(MatrixCombination)? fileNameBuilder,
  List<LocalizationsDelegate<dynamic>> extraLocalizationsDelegates = const [],
  Set<MatrixReportFormat> reportFormats = const {},
  String? reportDir,
  bool skip = false,
  double? tolerance,
  bool printSummary = true,
  MatrixSetupCallback? setup,
  bool freezeAnimations = false,
  Duration? captureAfter,
  bool detectStaleGoldens = true,
  double pixelRatio = 1.0,
  EdgeInsets padding = const EdgeInsets.all(8),
}) {
  validateCaptureScale(pixelRatio, 'pixelRatio');
  validateTolerance(tolerance);
  final plan = MatrixRunPlan.resolve(
    name: name,
    scenarios: scenarios,
    axes: axes,
    preset: preset,
    sampling: sampling,
    rules: rules,
    scenarioTags: scenarioTags,
    maxCombinations: maxCombinations,
    fileNameBuilder: fileNameBuilder,
    pathScheme: MatrixPathScheme.component,
  );
  plan.warnAboutProblems();

  final effectiveFormats = reportFormats;
  final writeReports = effectiveFormats.isNotEmpty;
  final wantStaleDetection = detectStaleGoldens && !plan.usesCustomPaths;
  final recordResults = writeReports || wantStaleDetection;

  final results = <MatrixCombinationResult>[];
  final stopwatch = Stopwatch()..start();
  final groupName = 'componentMatrixGolden: $name';

  group(groupName, () {
    installToleranceComparator(tolerance);

    for (final entry in plan.byScenario.entries) {
      group(entry.key, () {
        for (final planned in entry.value) {
          final (:combination, :goldenPath) = planned;

          if (skip && recordResults) {
            recordSkipped(results, combination, goldenPath);
          }

          testWidgets(
            _componentTestDescription(combination),
            skip: skip,
            (tester) => _executeComponentGoldenTest(
              tester: tester,
              combination: combination,
              goldenPath: goldenPath,
              pixelRatio: pixelRatio,
              padding: padding,
              extraLocalizationsDelegates: extraLocalizationsDelegates,
              record: recordResults,
              results: results,
              setup: setup,
              freezeAnimations: freezeAnimations,
              captureAfter: captureAfter,
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
        reportDir: reportDir,
        printSummary: printSummary,
        formats: effectiveFormats,
        detectStaleGoldens: wantStaleDetection,
      );
    }
  });
}

// -- Test execution --

Future<void> _executeComponentGoldenTest({
  required WidgetTester tester,
  required MatrixCombination combination,
  required String goldenPath,
  required double pixelRatio,
  required EdgeInsets padding,
  required List<LocalizationsDelegate<dynamic>> extraLocalizationsDelegates,
  required bool record,
  required List<MatrixCombinationResult> results,
  MatrixSetupCallback? setup,
  bool freezeAnimations = false,
  Duration? captureAfter,
}) async {
  // Generous virtual surface; the widget sizes itself inside UnconstrainedBox.
  tester.view.devicePixelRatio = pixelRatio;
  tester.view.physicalSize = const Size(800, 800) * 1.0;

  await runGoldenLifecycle(
    tester: tester,
    combination: combination,
    goldenPath: goldenPath,
    record: record,
    results: results,
    build: () => _buildComponentTree(
      combination: combination,
      padding: padding,
      extraLocalizationsDelegates: extraLocalizationsDelegates,
      freezeAnimations: freezeAnimations,
    ),
    pump: (widget) async {
      await tester.pumpWidget(widget);

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
      _componentBoundaryKey,
      goldenPath,
      captureScale: pixelRatio,
    ),
    onFinally: () {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    },
  );
}

Widget _buildComponentTree({
  required MatrixCombination combination,
  required EdgeInsets padding,
  required List<LocalizationsDelegate<dynamic>> extraLocalizationsDelegates,
  required bool freezeAnimations,
}) {
  final themeData = combination.theme.resolve();
  final delegates = [
    ...extraLocalizationsDelegates,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  // Reuse the same `MaterialApp` shell as `matrixGolden` so widgets that
  // depend on Material ancestry (DefaultTextStyle, IconTheme, Overlay for
  // Tooltip/Dialog, Theme-tinted ripples, etc.) work out of the box.
  //
  // The key differences vs `matrixGolden`:
  // 1. The RepaintBoundary sits **inside** the app tree, directly around
  //    the widget — so the captured PNG is widget-sized, not viewport-sized.
  // 2. `Align(widthFactor: 1, heightFactor: 1)` makes the wrap shrink to
  //    the widget's natural size (no overflow indicators).
  // 3. `MaterialApp.builder` injects `Material(transparency)` so Text and
  //    Icon widgets get a proper Material context — without it Flutter
  //    paints yellow-underline warnings on Text and falls back to Ahem.
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: themeData,
    locale: combination.locale,
    supportedLocales: [combination.locale],
    localizationsDelegates: delegates,
    builder: (context, child) => Directionality(
      textDirection: combination.direction,
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(combination.textScale)),
        child: Material(type: MaterialType.transparency, child: child),
      ),
    ),
    home: TickerMode(
      enabled: !freezeAnimations,
      child: Align(
        alignment: Alignment.topLeft,
        widthFactor: 1.0,
        heightFactor: 1.0,
        child: RepaintBoundary(
          key: _componentBoundaryKey,
          // Theme-aware solid background so semi-transparent widgets
          // (cards over scaffold colour, glass effects, etc.) render
          // against the same surface they'd see inside a real app.
          // Mirrors what `Scaffold` does in `matrixGolden`.
          child: ColoredBox(
            color: themeData.scaffoldBackgroundColor,
            child: Padding(padding: padding, child: combination.scenario.builder()),
          ),
        ),
      ),
    ),
  );
}

// -- Helpers --

String _componentTestDescription(MatrixCombination c) {
  final dir = c.direction == TextDirection.ltr ? 'ltr' : 'rtl';
  final scale = c.textScale % 1 == 0 ? '${c.textScale.toInt()}.0x' : '${c.textScale}x';
  return '${c.scenario.name} ${c.theme.name} ${c.locale.toLanguageTag()} $dir $scale';
}
