import 'package:flutter/material.dart';

import '../flutter/matrix_widget_wrapper.dart';
import '../models/matrix_axes.dart';
import '../models/matrix_combination.dart';
import '../models/matrix_preset.dart';
import '../models/matrix_rule.dart';
import '../models/matrix_sampling.dart';
import '../models/matrix_scenario.dart';
import 'matrix_test_runner.dart';

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
/// - [axes] — Defines the dimensions of the matrix (themes, locales, text
///   scales, devices, directions). Ignored when [preset] is supplied with
///   its own axes; otherwise sensible defaults are used.
/// - [preset] — A reusable [MatrixPreset] bundling [axes], [sampling], and
///   [rules]. See [MatrixPreset.componentSmoke] and
///   [MatrixPreset.componentFull].
/// - [sampling] — A [MatrixSampling] strategy used to reduce the full
///   Cartesian product. Defaults to [MatrixSampling.full].
/// - [maxCombinations] — Hard cap on the number of combinations. Most
///   useful with [MatrixSampling.priorityBased].
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
///   it is placed inside the [MaterialApp]. Useful for `Provider`,
///   `Theme` overrides, or padding.
/// - [report] — When `true` (default), writes a JSON/HTML report to
///   [reportDir] (or the package default) summarizing pass/fail/warnings.
/// - [reportDir] — Directory for the generated report. Defaults to the
///   package's standard `goldens` report location.
/// - [skip] — When `true`, all generated tests are skipped.
/// - [tolerance] — Optional pixel-difference tolerance (0.0–1.0) passed
///   through to the underlying matcher. `null` uses the framework default.
/// - [printSummary] — When `true` (default), prints a textual summary
///   line per test group at the end of the run.
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
///   tolerance: 0.01,
/// );
/// ```
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
  MatrixAxes? axes,
  MatrixPreset? preset,
  MatrixSampling? sampling,
  int? maxCombinations,
  List<MatrixRule> rules = const [],
  List<String>? scenarioTags,
  String Function(MatrixCombination)? fileNameBuilder,
  List<LocalizationsDelegate<dynamic>> extraLocalizationsDelegates = const [],
  Widget Function(Widget child)? wrapChild,
  bool report = true,
  String? reportDir,
  bool skip = false,
  double? tolerance,
  bool printSummary = true,
}) {
  runMatrixTests(
    'matrixGolden: $name',
    scenarios: scenarios,
    widgetBuilder: (combination) => MatrixWidgetWrapper(
      combination: combination,
      extraLocalizationsDelegates: extraLocalizationsDelegates,
      wrapChild: wrapChild,
      child: combination.scenario.builder(),
    ),
    axes: axes,
    preset: preset,
    sampling: sampling,
    maxCombinations: maxCombinations,
    rules: rules,
    scenarioTags: scenarioTags,
    fileNameBuilder: fileNameBuilder,
    report: report,
    reportDir: reportDir,
    skip: skip,
    tolerance: tolerance,
    printSummary: printSummary,
  );
}
