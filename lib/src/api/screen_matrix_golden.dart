import 'package:flutter/material.dart';

import '../core/report_format.dart';
import '../models/matrix_axes.dart';
import '../models/matrix_combination.dart';
import '../models/matrix_preset.dart';
import '../models/matrix_rule.dart';
import '../models/matrix_sampling.dart';
import '../models/matrix_scenario.dart';
import 'matrix_test_runner.dart';

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
/// - [axes] — Matrix dimensions. Ignored when [preset] supplies its own
///   axes.
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
///   `markdown`). Defaults to all three. Pass an empty set to skip
///   reporting entirely.
/// - `report` — **Deprecated.** Legacy bool toggle. Use [reportFormats]
///   instead. When both are passed, `report` wins.
/// - [reportDir] — Optional directory for the generated report.
/// - [skip] — When `true`, all generated tests are skipped.
/// - [tolerance] — Optional pixel-difference tolerance for the matcher.
/// - [printSummary] — When `true` (default), prints a textual summary
///   line at the end of the run.
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
  MatrixAxes? axes,
  MatrixPreset? preset,
  List<MatrixScenario>? states,
  MatrixSampling? sampling,
  int? maxCombinations,
  List<MatrixRule> rules = const [],
  List<String>? scenarioTags,
  String Function(MatrixCombination)? fileNameBuilder,
  Set<MatrixReportFormat> reportFormats = defaultReportFormats,
  @Deprecated(
    'Use reportFormats instead. report:true → all formats, report:false → empty set. '
    'When both are passed, report: wins for backwards compatibility.',
  )
  bool? report,
  String? reportDir,
  bool skip = false,
  double? tolerance,
  bool printSummary = true,
  MatrixSetupCallback? setup,
  bool freezeAnimations = false,
  Duration? captureAfter,
  bool detectStaleGoldens = true,
}) {
  final scenarios = states ?? [MatrixScenario('default', builder: () => const SizedBox.shrink())];

  runMatrixTests(
    'screenMatrixGolden: $name',
    scenarios: scenarios,
    widgetBuilder: appBuilder,
    axes: axes,
    preset: preset,
    sampling: sampling,
    maxCombinations: maxCombinations,
    rules: rules,
    scenarioTags: scenarioTags,
    fileNameBuilder: fileNameBuilder,
    reportFormats: reportFormats,
    // ignore: deprecated_member_use_from_same_package
    report: report,
    reportDir: reportDir,
    skip: skip,
    tolerance: tolerance,
    printSummary: printSummary,
    setup: setup,
    freezeAnimations: freezeAnimations,
    captureAfter: captureAfter,
    detectStaleGoldens: detectStaleGoldens,
  );
}
