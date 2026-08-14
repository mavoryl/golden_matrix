import 'package:flutter/material.dart';
import 'package:golden_matrix/src/api/matrix_run_config.dart';
import 'package:golden_matrix/src/api/matrix_test_runner.dart';
import 'package:golden_matrix/src/core/report_format.dart';
import 'package:golden_matrix/src/flutter/capture_strategy.dart';
import 'package:golden_matrix/src/models/matrix_axes.dart';
import 'package:golden_matrix/src/models/matrix_combination.dart';
import 'package:golden_matrix/src/models/matrix_preset.dart';
import 'package:golden_matrix/src/models/matrix_rule.dart';
import 'package:golden_matrix/src/models/matrix_sampling.dart';
import 'package:golden_matrix/src/models/matrix_scenario.dart';

/// A builder that receives a [MatrixCombination] and returns a fully
/// configured app widget (typically a [MaterialApp]).
typedef MatrixAppBuilder = Widget Function(MatrixCombination combination);

/// Creates a group of golden tests for full screens.
///
/// Unlike [matrixGolden], the caller is responsible for providing the
/// full app shell via [appBuilder]. The builder receives a fully
/// configured [MatrixCombination] and must return a widget (typically a
/// [MaterialApp]) wired with the appropriate theme, locale, navigation,
/// and dependency-injection scopes.
///
/// ## When to use
///
/// Use [screenMatrixGolden] when:
///   * The screen depends on a custom theme system (e.g. a brand-specific
///     `MTheme`) that cannot be expressed with a vanilla [ThemeData].
///   * The screen needs `Provider`, `Riverpod`, `GetIt`, or any other DI
///     container wired at the app root.
///   * The screen relies on a real router (`go_router`, `Navigator 2.0`)
///     instead of being placed directly into `home:`.
///   * You need to mock platform channels or HTTP clients at the app
///     level.
///
/// For simple components that fit into a default [MaterialApp], prefer
/// [matrixGolden] which handles the wrapping automatically.
///
/// ## Parameters
///
/// - [name] — Test group name. Also used in the golden file path to
///   prevent collisions across screen tests.
/// - [appBuilder] — Required builder that returns the full app widget
///   for the given [MatrixCombination]. This is the key difference from
///   [matrixGolden].
/// - [config] — A reusable [MatrixRunConfig] carrying the sixteen options every
///   entry point shares. Any argument passed directly to this function
///   overrides the same field of the config — see the precedence table on
///   [matrixGolden].
/// - [axes] — Matrix dimensions. Takes precedence over [preset]'s axes; see
///   the precedence table on [matrixGolden].
/// - [preset] — Reusable [MatrixPreset]. See [MatrixPreset.screenSmoke].
/// - [states] — Optional list of [MatrixScenario]s representing distinct
///   screen states (e.g. `loading`, `empty`, `error`, `populated`). Each
///   state is expanded across the matrix. Defaults to a single
///   `'default'` scenario when omitted.
/// - [sampling] — Strategy to reduce the matrix. See [MatrixSampling].
/// - [maxCombinations] — Hard cap on combinations. Useful with
///   [MatrixSampling.priorityBased].
/// - [rules] — [MatrixRule]s applied after the Cartesian product to
///   filter combinations.
/// - [scenarioTags] — When provided, filters [states] by their
///   [MatrixScenario.tags]. Not a Flutter test tag.
/// - [fileNameBuilder] — Override the default golden file name.
/// - [reportFormats] — Set of formats to write (`json`, `html`,
///   `markdown`, `junit`). Defaults to `const {}` — no reports are
///   written unless you ask. Pass [defaultReportFormats] for the usual
///   JSON + HTML + Markdown trio.
/// - [reportDir] — Optional directory for the generated report.
/// - [skip] — When `true`, all generated tests are skipped.
/// - [tolerance] — Optional pixel-difference tolerance for the matcher.
/// - [printSummary] — When `true` (default), prints a textual summary
///   line at the end of the run.
/// - [captureScale] — Physical pixels per logical pixel in the captured
///   PNG. Default `1.0`: a `phoneSmall` (375×667) golden is a 375×667 file.
///   `MatrixDevice.pixelRatio` drives layout and `MediaQuery` only, never
///   the file's resolution. Raise this for supersampled output
///   (`captureScale: 2.0` → 750×1334); every golden the call produces
///   changes size, so regenerate with `flutter test --update-goldens`.
///   The scale is not part of the golden path.
///
/// ## Example
///
/// ```dart
/// screenMatrixGolden(
///   'TransferScreen',
///   states: [
///     MatrixScenario('loading', builder: () => const SizedBox.shrink()),
///     MatrixScenario('populated', builder: () => const SizedBox.shrink()),
///   ],
///   appBuilder: (combination) {
///     final myTheme = combination.theme.isDark ? MTheme.dark() : MTheme.light();
///     return ProviderScope(
///       overrides: [
///         transferRepoProvider.overrideWithValue(FakeTransferRepo()),
///       ],
///       child: MTheme(
///         data: myTheme,
///         child: MaterialApp.router(
///           theme: combination.theme.resolve(),
///           locale: combination.locale,
///           localizationsDelegates: AppLocalizations.localizationsDelegates,
///           routerConfig: testRouterFor(combination.scenario.name),
///         ),
///       ),
///     );
///   },
///   preset: MatrixPreset.screenSmoke,
/// );
/// ```
///
/// See also:
///   * [matrixGolden] — component-level alternative that auto-wraps the
///     widget in a [MaterialApp].
///   * [MatrixAppBuilder] — the builder signature.
///   * [MatrixPreset.screenSmoke] — a sensible default for screens.
void screenMatrixGolden(
  String name, {
  required MatrixAppBuilder appBuilder,
  MatrixRunConfig? config,
  MatrixAxes? axes,
  MatrixPreset? preset,
  List<MatrixScenario>? states,
  MatrixSampling? sampling,
  int? maxCombinations,
  List<MatrixRule>? rules,
  List<String>? scenarioTags,
  String Function(MatrixCombination)? fileNameBuilder,
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
  final scenarios = states ?? [MatrixScenario('default', builder: () => const SizedBox.shrink())];

  runMatrixTests(
    'screenMatrixGolden: $name',
    scenarios: scenarios,
    widgetBuilder: appBuilder,
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
