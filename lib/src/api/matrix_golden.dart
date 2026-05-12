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
/// This is the primary API for component-level golden testing.
/// The widget from each scenario is automatically wrapped in a [MaterialApp]
/// shell with the appropriate theme, locale, direction, and text scale.
///
/// Set [report] to `false` to disable JSON/HTML report generation.
///
/// Example:
/// ```dart
/// matrixGolden(
///   'PrimaryButton',
///   scenarios: [
///     MatrixScenario('default', builder: () => const PrimaryButton(label: 'OK')),
///     MatrixScenario('disabled', builder: () => const PrimaryButton(label: 'OK', enabled: false)),
///   ],
///   preset: MatrixPreset.componentSmoke,
/// );
/// ```
void matrixGolden(
  String name, {
  required List<MatrixScenario> scenarios,
  MatrixAxes? axes,
  MatrixPreset? preset,
  MatrixSampling? sampling,
  int? maxCombinations,
  List<MatrixRule> rules = const [],
  List<String>? tags,
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
    tags: tags,
    fileNameBuilder: fileNameBuilder,
    report: report,
    reportDir: reportDir,
    skip: skip,
    tolerance: tolerance,
    printSummary: printSummary,
  );
}
