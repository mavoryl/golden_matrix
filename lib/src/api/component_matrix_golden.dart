import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:golden_matrix/src/api/matrix_test_runner.dart';
import 'package:golden_matrix/src/core/matrix_report_writer.dart';
import 'package:golden_matrix/src/core/naming_strategy.dart';
import 'package:golden_matrix/src/core/report_format.dart';
import 'package:golden_matrix/src/core/slug.dart';
import 'package:golden_matrix/src/core/stale_detector.dart';
import 'package:golden_matrix/src/flutter/error_capture.dart';
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
///
/// ## Parameters
///
/// - [name] — test group name; appears as `componentMatrixGolden: <name>`
///   in the test output and as the leading path segment in golden file
///   paths.
/// - [scenarios] — non-empty list of [MatrixScenario]s to render.
/// - [axes] / [preset] — themes, locales, text scales, directions. The
///   `devices` field is ignored.
/// - [sampling] / [maxCombinations] / [rules] / [scenarioTags] — same
///   semantics as [matrixGolden].
/// - [pixelRatio] — capture density (default `2.0`). PNG resolution in
///   physical pixels = widget logical size × this value.
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
  Set<MatrixReportFormat> reportFormats = defaultReportFormats,
  String? reportDir,
  bool skip = false,
  double? tolerance,
  bool printSummary = true,
  MatrixSetupCallback? setup,
  bool freezeAnimations = false,
  Duration? captureAfter,
  bool detectStaleGoldens = true,
  double pixelRatio = 2.0,
  EdgeInsets padding = const EdgeInsets.all(8),
}) {
  final effectiveFormats = reportFormats;
  final writeReports = effectiveFormats.isNotEmpty;
  final wantStaleDetection = detectStaleGoldens && fileNameBuilder == null;
  final recordResults = writeReports || wantStaleDetection;
  final combinations = resolveCombinations(
    scenarios: scenarios,
    axes: axes,
    preset: preset,
    sampling: sampling,
    rules: rules,
    scenarioTags: scenarioTags,
    maxCombinations: maxCombinations,
  );

  final byScenario = groupByScenario(combinations);

  final results = <MatrixCombinationResult>[];
  final stopwatch = Stopwatch()..start();
  final groupName = 'componentMatrixGolden: $name';

  group(groupName, () {
    _setupComponentTolerance(tolerance);

    for (final entry in byScenario.entries) {
      group(entry.key, () {
        for (final combination in entry.value) {
          final goldenPath = fileNameBuilder != null
              ? fileNameBuilder(combination)
              : NamingStrategy.componentGoldenPath(combination, testName: name);

          if (skip && recordResults) {
            _recordSkipped(results, combination, goldenPath);
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
      _setupComponentTearDown(
        groupName,
        name,
        results,
        stopwatch,
        reportDir,
        printSummary,
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

  final capture = ErrorCapture()..start();
  try {
    final widget = _buildComponentTree(
      combination: combination,
      padding: padding,
      extraLocalizationsDelegates: extraLocalizationsDelegates,
      freezeAnimations: freezeAnimations,
    );

    await tester.pumpWidget(widget);

    if (captureAfter != null) {
      await tester.pump(captureAfter);
    } else {
      await tester.pumpAndSettle();
    }

    if (setup != null) {
      await setup(tester, combination);
      if (captureAfter != null) {
        await tester.pump(captureAfter);
      } else {
        await tester.pumpAndSettle();
      }
    }

    capture.stop();

    if (record) {
      Object? capturedError;
      try {
        await expectLater(find.byKey(_componentBoundaryKey), matchesGoldenFile(goldenPath));
      } catch (e) {
        capturedError = e;
      }
      capturedError ??= tester.binding.takeException();

      if (capturedError != null) {
        results.add(
          MatrixCombinationResult(
            combination: combination,
            status: MatrixResultStatus.failed,
            goldenPath: goldenPath,
            errorMessage: capturedError.toString(),
            warnings: List.unmodifiable(capture.warnings),
          ),
        );
        throw capturedError;
      }

      results.add(
        MatrixCombinationResult(
          combination: combination,
          status: MatrixResultStatus.passed,
          goldenPath: goldenPath,
          warnings: List.unmodifiable(capture.warnings),
        ),
      );
    } else {
      await expectLater(find.byKey(_componentBoundaryKey), matchesGoldenFile(goldenPath));
    }
  } finally {
    capture.stop();
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
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

// -- Helpers (mostly duplicated from matrix_test_runner.dart so component
//    mode stays self-contained; consolidate when both APIs stabilize). --

String _componentTestDescription(MatrixCombination c) {
  final dir = c.direction == TextDirection.ltr ? 'ltr' : 'rtl';
  final scale = c.textScale % 1 == 0 ? '${c.textScale.toInt()}.0x' : '${c.textScale}x';
  return '${c.scenario.name} ${c.theme.name} ${c.locale.toLanguageTag()} $dir $scale';
}

void _recordSkipped(
  List<MatrixCombinationResult> results,
  MatrixCombination combination,
  String goldenPath,
) {
  results.add(
    MatrixCombinationResult(
      combination: combination,
      status: MatrixResultStatus.skipped,
      goldenPath: goldenPath,
    ),
  );
}

void _setupComponentTolerance(double? tolerance) {
  if (tolerance == null) return;

  if (tolerance < 0.0 || tolerance > 1.0) {
    throw ArgumentError.value(tolerance, 'tolerance', 'must be in range 0.0..1.0');
  }

  GoldenFileComparator? originalComparator;

  setUp(() {
    originalComparator = goldenFileComparator;
    final current = goldenFileComparator;
    if (current is! LocalFileComparator) {
      throw StateError(
        'golden_matrix: tolerance requires goldenFileComparator to be a '
        'LocalFileComparator, but got ${current.runtimeType}. '
        'Custom comparators are not supported with the tolerance parameter.',
      );
    }
    goldenFileComparator = _TolerantComponentComparator(current, tolerance);
  });

  tearDown(() {
    if (originalComparator != null) {
      goldenFileComparator = originalComparator!;
    }
  });
}

void _setupComponentTearDown(
  String groupName,
  String testName,
  List<MatrixCombinationResult> results,
  Stopwatch stopwatch,
  String? reportDir,
  bool printSummary, {
  required Set<MatrixReportFormat> formats,
  required bool detectStaleGoldens,
}) {
  tearDownAll(() async {
    stopwatch.stop();
    final stale =
        detectStaleGoldens ? await _detectComponentStaleGoldensSafe(testName, results) : <String>[];
    final result = MatrixResult(
      name: groupName,
      results: results,
      duration: stopwatch.elapsed,
      staleGoldens: stale,
    );
    final dir = reportDir ?? _resolveComponentDefaultReportDir();
    if (formats.contains(MatrixReportFormat.json)) {
      await MatrixReportWriter.write(result, outputDir: dir);
    }
    if (formats.contains(MatrixReportFormat.html)) {
      await MatrixReportWriter.writeHtml(result, outputDir: dir);
    }
    if (formats.contains(MatrixReportFormat.markdown)) {
      await MatrixReportWriter.writeMarkdown(result, outputDir: dir);
    }
    if (formats.contains(MatrixReportFormat.junit)) {
      await MatrixReportWriter.writeJunit(result, outputDir: dir);
    }
    if (printSummary) {
      debugPrint(formatSummary(result));
    }
    if (formats.isEmpty && stale.isNotEmpty) {
      debugPrint('golden_matrix: $groupName has ${stale.length} stale golden file(s):');
      for (final path in stale) {
        debugPrint('  - $path');
      }
    }
  });
}

/// Resolves the default report directory when `reportDir` is omitted.
///
/// Like the screen/component runner, derives `<test-file-dir>/goldens` from
/// the active comparator's `basedir` so reports land next to the golden PNGs
/// for any test layout. Returns null for non-local comparators.
String? _resolveComponentDefaultReportDir() {
  final comparator = goldenFileComparator;
  if (comparator is! LocalFileComparator) return null;
  return _componentJoinPath(Directory.fromUri(comparator.basedir).path, 'goldens');
}

Future<List<String>> _detectComponentStaleGoldensSafe(
  String testName,
  List<MatrixCombinationResult> results,
) async {
  try {
    final comparator = goldenFileComparator;
    if (comparator is! LocalFileComparator) return const [];

    final basedir = Directory.fromUri(comparator.basedir);
    final goldensRoot = Directory(_componentJoinPath(basedir.path, 'goldens'));
    final testSubdir = Directory(_componentJoinPath(goldensRoot.path, slugify(testName)));

    final expected = results.map((r) => r.goldenPath).toSet();
    return await findStaleGoldens(
      expectedPaths: expected,
      testSubdir: testSubdir,
      goldensRoot: goldensRoot,
    );
  } catch (_) {
    return const [];
  }
}

String _componentJoinPath(String base, String leaf) {
  final sep = Platform.pathSeparator;
  final trimmed = base.endsWith(sep) ? base.substring(0, base.length - sep.length) : base;
  return '$trimmed$sep$leaf';
}

// -- Tolerant comparator (duplicated from matrix_test_runner.dart) --

class _TolerantComponentComparator extends LocalFileComparator {
  _TolerantComponentComparator(LocalFileComparator delegate, this._tolerance)
      : super(delegate.basedir.resolve('_golden_matrix_tolerance_anchor.dart'));

  final double _tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (!result.passed && result.diffPercent <= _tolerance) {
      return true;
    }
    if (!result.passed) {
      final error = await generateFailureOutput(result, golden, basedir);
      throw FlutterError(error);
    }
    return result.passed;
  }
}
