import 'package:flutter/widgets.dart';

import 'matrix_combination.dart';

/// A side-effect-free description of what `matrixGolden`/`screenMatrixGolden`
/// would do for a given configuration, without rendering widgets or writing
/// files.
///
/// Returned by `previewMatrixGolden`.
class MatrixPreview {
  /// Creates a preview snapshot of what a matrix run would produce.
  const MatrixPreview({
    required this.name,
    required this.rawCount,
    required this.afterRulesCount,
    required this.afterSamplingCount,
    required this.combinations,
    required this.goldenPaths,
    required this.duplicatePaths,
    required this.samplingLabel,
  });

  /// The test name as passed to `previewMatrixGolden`.
  final String name;

  /// Cartesian product size: scenarios × themes × locales × textScales × devices
  /// × directionMultiplier — before rules and sampling.
  final int rawCount;

  /// Combination count after `MatrixRule.exclude` / `includeOnly` are applied.
  final int afterRulesCount;

  /// Final combination count after sampling and `maxCombinations` cap.
  /// Equal to `combinations.length`.
  final int afterSamplingCount;

  /// The final list of combinations that would execute as `testWidgets`.
  final List<MatrixCombination> combinations;

  /// Golden file paths the runner would write, one per combination (same order).
  final List<String> goldenPaths;

  /// Golden paths produced by more than one combination — usually a sign of
  /// scenario-name collisions or a buggy custom `fileNameBuilder`.
  final List<String> duplicatePaths;

  /// Name of the active sampling strategy ('full', 'smoke', 'pairwise',
  /// 'priorityBased') — used in `toString()`.
  final String samplingLabel;

  @override
  String toString() {
    final buf = StringBuffer();
    buf.writeln(name);

    final scenarioNames = <String>{};
    for (final c in combinations) {
      scenarioNames.add(c.scenario.name);
    }
    buf.writeln('  Scenarios: ${scenarioNames.length} (${scenarioNames.join(', ')})');
    buf.writeln('  Raw combinations: $rawCount');
    buf.writeln('  After rules: $afterRulesCount');
    buf.writeln('  After sampling ($samplingLabel): $afterSamplingCount');
    buf.writeln();
    buf.writeln('  Combinations:');
    for (var i = 0; i < combinations.length; i++) {
      final c = combinations[i];
      final dir = c.direction == TextDirection.ltr ? 'ltr' : 'rtl';
      buf.writeln(
        '    ${i + 1}. ${c.scenario.name} | ${c.theme.name} $dir ${c.locale} ${c.textScale}x ${c.device.name}',
      );
      buf.writeln('       -> ${goldenPaths[i]}');
    }

    if (duplicatePaths.isNotEmpty) {
      buf.writeln();
      buf.writeln('  WARNING: ${duplicatePaths.length} duplicate path(s) detected:');
      for (final p in duplicatePaths) {
        buf.writeln('    - $p');
      }
    }

    return buf.toString().trimRight();
  }
}
