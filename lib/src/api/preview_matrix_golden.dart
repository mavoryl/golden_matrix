import '../core/matrix_generator.dart';
import '../core/naming_strategy.dart';
import '../models/matrix_axes.dart';
import '../models/matrix_combination.dart';
import '../models/matrix_preset.dart';
import '../models/matrix_preview.dart';
import '../models/matrix_rule.dart';
import '../models/matrix_sampling.dart';
import '../models/matrix_scenario.dart';
import 'matrix_test_runner.dart';

/// Returns a [MatrixPreview] describing what a `matrixGolden` or
/// `screenMatrixGolden` call with the same parameters would do — without
/// rendering widgets or writing golden files.
///
/// Useful for:
/// - Sanity-checking that `scenarioTags` did not filter everything out.
/// - Estimating CI cost before adding a new axis.
/// - Detecting golden-path collisions before they overwrite each other.
/// - Inspecting which combinations a sampling strategy actually picked.
///
/// The signature mirrors `matrixGolden` minus the rendering-only parameters
/// (`widgetBuilder`, `tolerance`, `skip`, report flags).
MatrixPreview previewMatrixGolden({
  required String name,
  required List<MatrixScenario> scenarios,
  MatrixAxes? axes,
  MatrixPreset? preset,
  MatrixSampling? sampling,
  int? maxCombinations,
  List<MatrixRule> rules = const [],
  List<String>? scenarioTags,
  String Function(MatrixCombination)? fileNameBuilder,
}) {
  final effectiveAxes = axes ?? preset?.axes ?? const MatrixAxes();
  final effectiveSampling = sampling ?? preset?.sampling ?? MatrixSampling.full;
  final effectiveRules = [...?preset?.rules, ...rules];

  final filteredScenarios = scenarioTags != null
      ? scenarios.where((s) => s.tags.any((t) => scenarioTags.contains(t))).toList()
      : scenarios;

  final rawCount = _cartesianSize(filteredScenarios.length, effectiveAxes);

  final afterRulesCount = MatrixGenerator.generate(
    scenarios: filteredScenarios,
    axes: effectiveAxes,
    rules: effectiveRules,
  ).length;

  final combinations = resolveCombinations(
    scenarios: scenarios,
    axes: axes,
    preset: preset,
    sampling: sampling,
    rules: rules,
    scenarioTags: scenarioTags,
    maxCombinations: maxCombinations,
  );

  final goldenPaths = [
    for (final c in combinations)
      fileNameBuilder != null ? fileNameBuilder(c) : NamingStrategy.goldenPath(c, testName: name),
  ];

  final duplicatePaths = _findDuplicates(goldenPaths);

  return MatrixPreview(
    name: name,
    rawCount: rawCount,
    afterRulesCount: afterRulesCount,
    afterSamplingCount: combinations.length,
    combinations: List.unmodifiable(combinations),
    goldenPaths: List.unmodifiable(goldenPaths),
    duplicatePaths: List.unmodifiable(duplicatePaths),
    samplingLabel: effectiveSampling.name,
  );
}

int _cartesianSize(int scenarios, MatrixAxes axes) {
  if (scenarios == 0) return 0;
  final themes = axes.themes.isEmpty ? 1 : axes.themes.length;
  final locales = axes.locales.isEmpty ? 1 : axes.locales.length;
  final textScales = axes.textScales.isEmpty ? 1 : axes.textScales.length;
  final devices = axes.devices.isEmpty ? 1 : axes.devices.length;
  // When directions is empty the generator infers one direction per locale.
  final directions = axes.directions.isEmpty ? 1 : axes.directions.length;
  return scenarios * themes * locales * textScales * devices * directions;
}

List<String> _findDuplicates(List<String> paths) {
  final counts = <String, int>{};
  for (final p in paths) {
    counts[p] = (counts[p] ?? 0) + 1;
  }
  final dups = <String>[];
  final seen = <String>{};
  for (final p in paths) {
    if (counts[p]! > 1 && seen.add(p)) {
      dups.add(p);
    }
  }
  return dups;
}
