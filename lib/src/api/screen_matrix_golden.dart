import 'package:flutter/material.dart';

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
/// Unlike [matrixGolden], the user provides their own app shell via
/// [appBuilder], which receives the full [MatrixCombination] for
/// configuring theme, locale, and state.
///
/// Set [report] to `false` to disable JSON/HTML report generation.
///
/// Example:
/// ```dart
/// screenMatrixGolden(
///   'TransferScreen',
///   appBuilder: (combination) => MaterialApp(
///     theme: combination.theme.resolve(),
///     locale: combination.locale,
///     home: TransferScreen(),
///   ),
///   preset: MatrixPreset.screenSmoke,
/// );
/// ```
void screenMatrixGolden(
  String name, {
  required MatrixAppBuilder appBuilder,
  MatrixAxes? axes,
  MatrixPreset? preset,
  List<MatrixScenario>? states,
  MatrixSampling? sampling,
  int? maxCombinations,
  List<MatrixRule> rules = const [],
  List<String>? tags,
  String Function(MatrixCombination)? fileNameBuilder,
  bool report = true,
  String? reportDir,
  bool skip = false,
  double? tolerance,
  bool printSummary = true,
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
    tags: tags,
    fileNameBuilder: fileNameBuilder,
    report: report,
    reportDir: reportDir,
    skip: skip,
    tolerance: tolerance,
    printSummary: printSummary,
  );
}
