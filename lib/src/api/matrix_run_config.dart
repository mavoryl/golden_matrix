import 'package:golden_matrix/src/core/report_format.dart';
import 'package:golden_matrix/src/flutter/capture_strategy.dart';
import 'package:golden_matrix/src/models/matrix_axes.dart';
import 'package:golden_matrix/src/models/matrix_combination.dart';
import 'package:golden_matrix/src/models/matrix_preset.dart';
import 'package:golden_matrix/src/models/matrix_rule.dart';
import 'package:golden_matrix/src/models/matrix_sampling.dart';

/// The options every golden_matrix entry point accepts, in one reusable object.
///
/// `matrixGolden`, `screenMatrixGolden` and `componentMatrixGolden` share
/// sixteen parameters. Declaring them once — next to the preset they belong
/// with — beats repeating them at every call site:
///
/// ```dart
/// const ciRun = MatrixRunConfig(
///   axes: MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
///   reportFormats: {MatrixReportFormat.json, MatrixReportFormat.junit},
///   tolerance: 0.001,
///   printSummary: false,
/// );
///
/// matrixGolden('PrimaryButton', scenarios: [...], config: ciRun);
/// matrixGolden('Badge', scenarios: [...], config: ciRun, skip: true);
/// ```
///
/// ## Precedence
///
/// An argument passed directly to the function always wins over the same field
/// of [config]. Every field here is nullable for exactly that reason: null
/// means "not specified", which is what lets the explicit argument show
/// through. The second call above therefore runs `ciRun` with `skip: true`.
///
/// `rules` still merges with the preset's rules, as it does without a config —
/// `preset.rules` first, then these. Between config and argument, though, the
/// argument *replaces*: merging would make it impossible to narrow a shared
/// config down, and a field with two merge semantics is a field whose
/// documentation stops being true.
///
/// ## What is deliberately absent
///
/// Mode-specific options stay on their own functions: `captureScale`
/// (viewport capture), `pixelRatio` and `padding` (intrinsic capture),
/// `extraLocalizationsDelegates`, `wrapChild` / `wrapApp`, `appBuilder`.
/// A field that two of three entry points quietly ignore is worse than a
/// slightly longer call site.
class MatrixRunConfig {
  /// Creates a reusable set of run options. Every field is optional; an unset
  /// field means "leave this to the call site, or to the default".
  const MatrixRunConfig({
    this.axes,
    this.preset,
    this.sampling,
    this.maxCombinations,
    this.rules,
    this.scenarioTags,
    this.fileNameBuilder,
    this.reportFormats,
    this.reportDir,
    this.skip,
    this.tolerance,
    this.printSummary,
    this.setup,
    this.freezeAnimations,
    this.captureAfter,
    this.detectStaleGoldens,
  });

  /// Axes of the matrix. Wins over [preset]'s axes when both are given.
  final MatrixAxes? axes;

  /// Preset supplying axes, sampling and rules that are not set explicitly.
  final MatrixPreset? preset;

  /// Sampling strategy. Defaults to [MatrixSampling.full].
  final MatrixSampling? sampling;

  /// Hard cap on the number of registered tests.
  final int? maxCombinations;

  /// Exclude/includeOnly rules, applied after the preset's own.
  final List<MatrixRule>? rules;

  /// Keeps only scenarios carrying at least one of these tags.
  final List<String>? scenarioTags;

  /// Replaces the built-in golden path scheme.
  final String Function(MatrixCombination)? fileNameBuilder;

  /// Report formats to write. Defaults to none — reports are opt-in.
  final Set<MatrixReportFormat>? reportFormats;

  /// Directory for reports. Defaults to the goldens dir next to the test.
  final String? reportDir;

  /// Registers the tests as skipped. Defaults to false.
  final bool? skip;

  /// Fraction of differing pixels tolerated, 0.0..1.0.
  final double? tolerance;

  /// Prints the run summary to the console. Defaults to true.
  final bool? printSummary;

  /// Runs after pump and settle, before the capture.
  final MatrixSetupCallback? setup;

  /// Halts tickers in the scenario tree. Defaults to false.
  final bool? freezeAnimations;

  /// Advances the clock by this much instead of settling.
  final Duration? captureAfter;

  /// Reports goldens on disk that this run did not produce. Defaults to true.
  final bool? detectStaleGoldens;

  /// Returns a config where every field [overrides] specifies replaces this
  /// one's, and every field it leaves null is taken from this one.
  ///
  /// Used by the entry points to fold their explicit arguments over a supplied
  /// config, which is what makes the argument win.
  MatrixRunConfig merge(MatrixRunConfig overrides) => MatrixRunConfig(
        axes: overrides.axes ?? axes,
        preset: overrides.preset ?? preset,
        sampling: overrides.sampling ?? sampling,
        maxCombinations: overrides.maxCombinations ?? maxCombinations,
        rules: overrides.rules ?? rules,
        scenarioTags: overrides.scenarioTags ?? scenarioTags,
        fileNameBuilder: overrides.fileNameBuilder ?? fileNameBuilder,
        reportFormats: overrides.reportFormats ?? reportFormats,
        reportDir: overrides.reportDir ?? reportDir,
        skip: overrides.skip ?? skip,
        tolerance: overrides.tolerance ?? tolerance,
        printSummary: overrides.printSummary ?? printSummary,
        setup: overrides.setup ?? setup,
        freezeAnimations: overrides.freezeAnimations ?? freezeAnimations,
        captureAfter: overrides.captureAfter ?? captureAfter,
        detectStaleGoldens: overrides.detectStaleGoldens ?? detectStaleGoldens,
      );

  /// [rules] with its default applied.
  List<MatrixRule> get resolvedRules => rules ?? const [];

  /// [reportFormats] with its default applied — none, reports are opt-in.
  Set<MatrixReportFormat> get resolvedReportFormats => reportFormats ?? const {};

  /// [skip] with its default applied.
  bool get resolvedSkip => skip ?? false;

  /// [printSummary] with its default applied.
  bool get resolvedPrintSummary => printSummary ?? true;

  /// [freezeAnimations] with its default applied.
  bool get resolvedFreezeAnimations => freezeAnimations ?? false;

  /// [detectStaleGoldens] with its default applied.
  bool get resolvedDetectStaleGoldens => detectStaleGoldens ?? true;
}
