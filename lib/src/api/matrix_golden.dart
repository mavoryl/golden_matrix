import 'package:flutter/material.dart';
import 'package:golden_matrix/src/api/matrix_run_config.dart';
import 'package:golden_matrix/src/api/matrix_test_runner.dart';
import 'package:golden_matrix/src/core/report_format.dart';
import 'package:golden_matrix/src/flutter/capture_strategy.dart';
import 'package:golden_matrix/src/flutter/matrix_widget_wrapper.dart';
import 'package:golden_matrix/src/models/matrix_axes.dart';
import 'package:golden_matrix/src/models/matrix_combination.dart';
import 'package:golden_matrix/src/models/matrix_preset.dart';
import 'package:golden_matrix/src/models/matrix_rule.dart';
import 'package:golden_matrix/src/models/matrix_sampling.dart';
import 'package:golden_matrix/src/models/matrix_scenario.dart';

/// Creates a group of golden tests for each combination in the matrix.
///
/// This is the primary API for component-level golden testing. The widget
/// returned by each [MatrixScenario]'s builder is automatically wrapped in
/// a [MaterialApp] shell configured with the theme, locale, direction,
/// text scale, and device frame for each [MatrixCombination] produced from
/// [axes] (or [preset]).
///
/// ## When to use
///
/// Use [matrixGolden] for testing isolated components — buttons, cards,
/// form fields, list items — where you don't need to control the app
/// shell, navigation, or dependency injection. The library handles the
/// [MaterialApp] for you.
///
/// For full screens that require custom routing, DI, or a bespoke theme
/// system, use [screenMatrixGolden] instead, which lets you supply your
/// own `appBuilder`.
///
/// ## Parameters
///
/// - [name] — Test group name. Also used in the golden file path to
///   prevent collisions when multiple `matrixGolden` calls share scenario
///   names.
/// - [scenarios] — One or more [MatrixScenario]s describing distinct
///   widget states (e.g. `default`, `disabled`, `loading`). Each scenario
///   is expanded across the matrix.
/// - [config] — A reusable [MatrixRunConfig] carrying the sixteen options every
///   entry point shares. Any argument passed directly to this function
///   overrides the same field of the config; see *Precedence* below.
/// - [axes] — Defines the dimensions of the matrix (themes, locales, text
///   scales, devices, directions). Takes precedence over [preset]'s axes;
///   when neither is given, sensible defaults are used.
/// - [preset] — A reusable [MatrixPreset] bundling [axes], [sampling], and
///   [rules]. See [MatrixPreset.componentSmoke] and
///   [MatrixPreset.componentFull]. Precedence is described below the parameter
///   list.
/// - [sampling] — A [MatrixSampling] strategy used to reduce the full
///   Cartesian product. Defaults to [MatrixSampling.full].
/// - [maxCombinations] — Hard cap on the number of combinations, at least 1.
///   Most useful with [MatrixSampling.priorityBased], which orders by risk
///   before truncating. With [MatrixSampling.pairwise] a cap below the covering
///   array size drops the all-pairs guarantee and logs a warning.
/// - [rules] — A list of [MatrixRule]s applied after the Cartesian
///   product. Exclude rules drop combinations; includeOnly rules keep
///   only matching combinations.
/// - [scenarioTags] — When provided, only scenarios whose [MatrixScenario.tags]
///   intersect this list are included. This filters [scenarios] before
///   matrix generation; it is NOT passed to Flutter test as `tags`.
/// - [fileNameBuilder] — Override the default golden file name derived
///   from the combination. Useful for custom naming conventions.
/// - [extraLocalizationsDelegates] — Additional
///   [LocalizationsDelegate]s appended to the auto-wrapped [MaterialApp]
///   (e.g. your app's generated `AppLocalizations.delegate`).
/// - [wrapChild] — Optional builder that wraps the scenario widget before
///   it is placed inside the [MaterialApp]. Sits **inside**
///   `MaterialApp.home` — useful for layout shells, themed scopes that
///   work below MaterialApp, padding, or test-only decorations.
/// - [wrapApp] — Optional builder that wraps the entire auto-built
///   [MaterialApp] from the **outside**. This is the seam for dependency
///   injection above MaterialApp: `ProviderScope` (Riverpod),
///   `BlocProvider` / `MultiBlocProvider` (flutter_bloc), `MultiProvider`
///   (provider), or custom root-level `InheritedWidget`s. The callback
///   receives the current [MatrixCombination] so providers can vary per
///   scenario (e.g. seed a different fake state per combination). When
///   `null`, the widget tree is identical to previous versions.
/// - [reportFormats] — Set of report formats to write after the run.
///   Defaults to `const {}` — reports are opt-in, nothing is written
///   unless you ask. Pass [defaultReportFormats] for the usual
///   `json` + `html` + `markdown` trio, or a singleton like
///   `{MatrixReportFormat.markdown}` for CI-only Markdown summaries.
/// - [reportDir] — Directory for the generated report. Defaults to the
///   package's standard `goldens` report location.
/// - [skip] — When `true`, all generated tests are skipped.
/// - [tolerance] — Optional pixel-difference tolerance (0.0–1.0) passed
///   through to the underlying matcher. `null` uses the framework default.
/// - [printSummary] — When `true` (default), prints a textual summary
///   line per test group at the end of the run.
/// - [setup] — Optional async callback `(tester, combination) async {...}`
///   that runs after the widget is pumped and settled, but before the
///   golden file is captured. Use to drive interactions: `tester.tap(...)`,
///   `tester.enterText(...)`, scrolling, opening menus — anything needed
///   to bring the widget into the visual state you want to snapshot.
///   A `pumpAndSettle` is performed after `setup` returns.
/// - [freezeAnimations] — When `true`, wraps the widget tree in
///   `TickerMode(enabled: false)`, freezing all `AnimationController`s
///   and `Ticker`s. Use for widgets with infinite animations (shimmers,
///   skeletons, loaders) that otherwise hang `pumpAndSettle`. Snapshot
///   is taken at the initial frame.
/// - [captureAfter] — Optional duration that switches the runner into
///   "deterministic-frame mode": instead of `pumpAndSettle` (which
///   hangs on infinite animations), the runner calls `pump(captureAfter)`
///   before capture (and again after [setup] if set). Use to snapshot a
///   specific mid-animation frame on widgets with shimmers / loaders /
///   continuous animations. You pick the duration; the test takes
///   responsibility for the widget having no async work that needs
///   actual settling.
/// - [detectStaleGoldens] — When `true` (default), after the run the
///   runner walks the test's golden subdirectory and reports any `.png`
///   files that no combination produced (renamed scenarios, dropped
///   axes, etc.). Stale paths appear in the console summary and in the
///   JSON / HTML reports. Detection is automatically skipped when
///   [fileNameBuilder] is supplied (paths are custom — we don't know
///   where to look). Set to `false` to disable on a per-test basis.
/// - [captureScale] — Physical pixels per logical pixel in the captured
///   PNG. Default `1.0` (goldens at the device's logical size). See
///   *Capture resolution* below; this is **not** `MatrixDevice.pixelRatio`.
///
/// ## Precedence
///
/// Three layers can supply the same setting: an argument here, [config], and
/// [preset]. They resolve left to right.
///
/// | Setting            | Winner                                                          |
/// |--------------------|-----------------------------------------------------------------|
/// | [axes]             | [axes] → `config.axes` → `preset.axes` → `const MatrixAxes()`   |
/// | [sampling]         | [sampling] → `config.sampling` → `preset.sampling` → `full`     |
/// | [rules]            | [rules] → `config.rules`, **merged after** `preset.rules`       |
/// | [maxCombinations]  | [maxCombinations] → `config.maxCombinations` — presets carry no cap |
/// | everything else    | argument → [config] → the parameter's default                   |
///
/// Only [rules] merge, and only with the preset's: `preset.rules` run first,
/// then whichever list won between the argument and the config. Everything else
/// is a straight override, so passing [axes] next to a preset replaces the
/// preset's axes rather than extending them — use `preset.axes.copyWith(...)`
/// to extend a single axis.
///
/// An argument beats the config even when it repeats the parameter's own
/// default: `skip: false` next to a config with `skip: true` runs the tests.
/// That is why the shared parameters are nullable — null means "not specified",
/// which is what lets the config show through.
///
/// ## Example
///
/// ```dart
/// matrixGolden(
///   'PrimaryButton',
///   scenarios: [
///     MatrixScenario('default', builder: () => const PrimaryButton(label: 'OK')),
///     MatrixScenario(
///       'disabled',
///       builder: () => const PrimaryButton(label: 'OK', enabled: false),
///     ),
///   ],
///   preset: MatrixPreset.componentFull,
///   sampling: MatrixSampling.pairwise,
///   rules: [
///     // Skip dark theme + large text combo (known visual noise).
///     MatrixRule.exclude((c) => c.theme.isDark && c.textScale > 1.5),
///   ],
///   extraLocalizationsDelegates: const [AppLocalizations.delegate],
///   wrapChild: (child) => Padding(padding: const EdgeInsets.all(16), child: child),
///   wrapApp: (app, combination) => ProviderScope(
///     overrides: [apiClientProvider.overrideWithValue(MockApiClient())],
///     child: app,
///   ),
///   tolerance: 0.01,
/// );
/// ```
///
/// ## Capture resolution
///
/// Goldens are written at the device's **logical** size — a `phoneSmall`
/// (375×667) golden is a 375×667 PNG. `MatrixDevice.pixelRatio` configures
/// layout and `MediaQuery` (including which resolution-aware asset variant
/// is picked); it deliberately does **not** change the file's resolution,
/// which keeps goldens small and diffs readable.
///
/// Pass [captureScale] when you want a higher-resolution raster — e.g.
/// supersampled marketing screenshots:
///
/// ```dart
/// matrixGolden('Hero', scenarios: [...], captureScale: 2.0);  // 750×1334
/// ```
///
/// Changing [captureScale] changes the size of every golden the call
/// produces, so an existing baseline will fail on dimensions until it is
/// regenerated with `flutter test --update-goldens`. The scale is not part
/// of the golden path.
///
/// See also:
///   * [screenMatrixGolden] — for full-screen golden tests with a
///     user-supplied app shell.
///   * [MatrixPreset] — reusable bundles of axes, sampling, and rules.
///   * [MatrixSampling] — strategies for reducing the combinatorial set.
///   * [MatrixRule] — predicate-based filtering of combinations.
void matrixGolden(
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
  Widget Function(Widget child)? wrapChild,
  Widget Function(Widget app, MatrixCombination combination)? wrapApp,
  Set<MatrixReportFormat>? reportFormats,
  String? reportDir,
  bool? skip,
  double? tolerance,
  bool? printSummary,
  MatrixSetupCallback? setup,
  bool? freezeAnimations,
  Duration? captureAfter,
  bool? detectStaleGoldens,
  double captureScale = 1.0,
}) {
  runMatrixTests(
    'matrixGolden: $name',
    scenarios: scenarios,
    widgetBuilder: (combination) => buildMatrixGoldenWidget(
      combination: combination,
      extraLocalizationsDelegates: extraLocalizationsDelegates,
      wrapChild: wrapChild,
      wrapApp: wrapApp,
    ),
    config: (config ?? const MatrixRunConfig()).merge(
      // Explicit arguments fold over the caller's config, so they win.
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
    ),
    captureScale: captureScale,
  );
}

/// Builds the widget tree that `matrixGolden` pumps for a single
/// [combination]. Exposed for unit tests of the `wrapApp` / `wrapChild`
/// wiring without going through `matchesGoldenFile`.
///
/// The result is identical to what the public `matrixGolden` would
/// produce internally — when [wrapApp] is `null`, no extra ancestors
/// are introduced.
@visibleForTesting
Widget buildMatrixGoldenWidget({
  required MatrixCombination combination,
  List<LocalizationsDelegate<dynamic>> extraLocalizationsDelegates = const [],
  Widget Function(Widget child)? wrapChild,
  Widget Function(Widget app, MatrixCombination combination)? wrapApp,
}) {
  final Widget app = MatrixWidgetWrapper(
    combination: combination,
    extraLocalizationsDelegates: extraLocalizationsDelegates,
    wrapChild: wrapChild,
    child: combination.scenario.builder(),
  );
  return wrapApp == null ? app : wrapApp(app, combination);
}
