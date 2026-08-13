import 'package:golden_matrix/src/core/matrix_run_plan.dart';
import 'package:golden_matrix/src/models/matrix_axes.dart';
import 'package:golden_matrix/src/models/matrix_combination.dart';
import 'package:golden_matrix/src/models/matrix_preset.dart';
import 'package:golden_matrix/src/models/matrix_preview.dart';
import 'package:golden_matrix/src/models/matrix_rule.dart';
import 'package:golden_matrix/src/models/matrix_sampling.dart';
import 'package:golden_matrix/src/models/matrix_scenario.dart';

/// Returns a [MatrixPreview] describing what a `matrixGolden`,
/// `screenMatrixGolden` or `componentMatrixGolden` call with the same
/// parameters would do — without rendering widgets or writing golden files.
///
/// Useful for:
/// - Sanity-checking that `scenarioTags` did not filter everything out.
/// - Estimating CI cost before adding a new axis.
/// - Detecting golden-path collisions before they overwrite each other.
/// - Inspecting which combinations a sampling strategy actually picked.
///
/// The signature mirrors `matrixGolden` minus the rendering-only parameters
/// (`widgetBuilder`, `tolerance`, `skip`, report flags).
///
/// Pass [component] to preview a `componentMatrixGolden` call instead: golden
/// paths lose their device segment and the `devices` axis is collapsed to its
/// first value, exactly as the component runner does. Without it, a component
/// run's path collisions are invisible here, because the default scheme keeps
/// the device that makes every path unique.
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
  bool component = false,
}) {
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
    pathScheme: component ? MatrixPathScheme.component : MatrixPathScheme.viewport,
  );

  return MatrixPreview(
    name: name,
    rawCount: plan.rawCount,
    afterRulesCount: plan.afterRulesCount,
    afterSamplingCount: plan.length,
    combinations: List.unmodifiable(plan.combinations),
    goldenPaths: List.unmodifiable(plan.goldenPaths),
    duplicatePaths: List.unmodifiable(plan.duplicatePaths),
    samplingLabel: plan.sampling.name,
  );
}
