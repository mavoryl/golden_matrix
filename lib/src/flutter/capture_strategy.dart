import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:golden_matrix/src/flutter/golden_lifecycle.dart';
import 'package:golden_matrix/src/flutter/pump_helpers.dart';
import 'package:golden_matrix/src/models/matrix_combination.dart';
import 'package:golden_matrix/src/models/matrix_result.dart';

/// Builds a widget tree for a given [MatrixCombination].
typedef CaptureWidgetBuilder = Widget Function(MatrixCombination combination);

/// Callback type for the `setup:` parameter of the public test functions.
///
/// Runs after the widget has been pumped and settled, before the golden
/// file is captured. Use to drive interactions like `tester.tap(...)`,
/// `tester.enterText(...)`, or scrolling — anything needed to bring the
/// widget into the visual state you want to snapshot.
typedef MatrixSetupCallback = Future<void> Function(
  WidgetTester tester,
  MatrixCombination combination,
);

/// What a run captures, and how it prepares the view to capture it.
///
/// The two modes differ in exactly four things — the view configuration, the
/// widget tree, which `RepaintBoundary` is rasterized, and at what scale.
/// Everything else (pump, settle, setup, compare, result bookkeeping) is
/// identical, and used to be written out twice.
abstract class CaptureStrategy {
  /// Const so strategies can be built per test without allocation churn.
  const CaptureStrategy();

  /// Key of the [RepaintBoundary] whose pixels become the golden.
  Key get boundaryKey;

  /// Physical pixels per logical pixel in the written PNG.
  double get captureScale;

  /// Prepares `tester.view` before the first pump.
  void configureView(WidgetTester tester, MatrixCombination combination);

  /// Builds the tree to pump, boundary included.
  Widget build(MatrixCombination combination);

  /// Undoes [configureView]. Runs after the capture, whatever happened.
  void resetView(WidgetTester tester);
}

/// Captures the whole device viewport — `matrixGolden` and
/// `screenMatrixGolden`.
///
/// The device axis drives the view geometry, so the golden is a picture of the
/// scenario as that device would show it.
class ViewportCaptureStrategy extends CaptureStrategy {
  /// Captures [widgetBuilder]'s tree filling the combination's device viewport.
  const ViewportCaptureStrategy({
    required this.widgetBuilder,
    required this.freezeAnimations,
    required this.captureScale,
  });

  /// Builds the tree that gets wrapped in the capture boundary.
  final CaptureWidgetBuilder widgetBuilder;

  /// Whether tickers in the scenario tree are halted before the capture.
  final bool freezeAnimations;

  @override
  final double captureScale;

  @override
  Key get boundaryKey => const ValueKey('__golden_matrix_boundary__');

  @override
  void configureView(WidgetTester tester, MatrixCombination combination) {
    PumpHelpers.configureView(tester, combination.device);
  }

  @override
  Widget build(MatrixCombination combination) => RepaintBoundary(
        key: boundaryKey,
        child: TickerMode(enabled: !freezeAnimations, child: widgetBuilder(combination)),
      );

  @override
  void resetView(WidgetTester tester) => PumpHelpers.resetView(tester);
}

/// Captures the widget at its intrinsic size — `componentMatrixGolden`.
///
/// The boundary sits inside the app tree, directly around the widget, and
/// `Align(widthFactor: 1, heightFactor: 1)` shrinks the wrap to the widget's
/// natural size. The device axis is irrelevant here, which is why the plan
/// collapses it.
class IntrinsicCaptureStrategy extends CaptureStrategy {
  /// Captures the scenario widget at its own size, inside a MaterialApp shell.
  const IntrinsicCaptureStrategy({
    required this.pixelRatio,
    required this.padding,
    required this.extraLocalizationsDelegates,
    required this.freezeAnimations,
  });

  /// Capture density; also the raster scale of the written PNG.
  final double pixelRatio;

  /// Breathing room added around the widget inside the boundary.
  final EdgeInsets padding;

  /// Delegates merged ahead of the built-in Material/Cupertino/Widgets ones.
  final List<LocalizationsDelegate<dynamic>> extraLocalizationsDelegates;

  /// Whether tickers in the scenario tree are halted before the capture.
  final bool freezeAnimations;

  /// Logical size of the surface the widget lays itself out in.
  static const Size surface = Size(800, 800);

  @override
  double get captureScale => pixelRatio;

  @override
  Key get boundaryKey => const ValueKey('__golden_matrix_component_boundary__');

  @override
  void configureView(WidgetTester tester, MatrixCombination combination) {
    // Generous virtual surface; the widget sizes itself inside the Align.
    //
    // physicalSize is in *physical* pixels, so it has to be scaled by the
    // ratio to keep [surface] logical points available. A fixed 800×800 meant
    // 400×400 logical at ratio 2.0 and ~267×267 at 3.0 — a capture-density
    // knob quietly squeezing anything wider, and the golden then recorded the
    // squeezed layout.
    tester.view.devicePixelRatio = pixelRatio;
    tester.view.physicalSize = surface * pixelRatio;
  }

  @override
  Widget build(MatrixCombination combination) {
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
            key: boundaryKey,
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

  @override
  void resetView(WidgetTester tester) {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
}

/// Runs one combination through [strategy] and records its result.
///
/// The pump/settle/setup sequence is the same for every strategy; only the
/// four [CaptureStrategy] hooks differ.
Future<void> executeCapture({
  required WidgetTester tester,
  required MatrixCombination combination,
  required String goldenPath,
  required CaptureStrategy strategy,
  required bool record,
  required List<MatrixCombinationResult> results,
  MatrixSetupCallback? setup,
  Duration? captureAfter,
}) async {
  strategy.configureView(tester, combination);

  // When captureAfter is set, advance by that duration instead of settling:
  // pumpAndSettle would hang on an infinite animation, which is the very case
  // captureAfter exists for.
  Future<void> advance() =>
      captureAfter != null ? tester.pump(captureAfter) : tester.pumpAndSettle();

  await runGoldenLifecycle(
    tester: tester,
    combination: combination,
    goldenPath: goldenPath,
    record: record,
    results: results,
    build: () => strategy.build(combination),
    pump: (widget) async {
      await tester.pumpWidget(widget);
      await advance();
    },
    setup: setup == null
        ? null
        : () async {
            await setup(tester, combination);
            await advance();
          },
    compare: () => expectMatchesGolden(
      tester,
      strategy.boundaryKey,
      goldenPath,
      captureScale: strategy.captureScale,
    ),
    onFinally: () => strategy.resetView(tester),
  );
}

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
