import 'package:golden_matrix/src/core/matrix_generator.dart';
import 'package:golden_matrix/src/core/naming_strategy.dart';
import 'package:golden_matrix/src/core/warn.dart';
import 'package:golden_matrix/src/models/matrix_axes.dart';
import 'package:golden_matrix/src/models/matrix_combination.dart';
import 'package:golden_matrix/src/models/matrix_preset.dart';
import 'package:golden_matrix/src/models/matrix_rule.dart';
import 'package:golden_matrix/src/models/matrix_sampling.dart';
import 'package:golden_matrix/src/models/matrix_scenario.dart';

/// Which default naming scheme a run uses for its golden files.
enum MatrixPathScheme {
  /// `matrixGolden` / `screenMatrixGolden`: the capture is the device
  /// viewport, so the device is part of the golden's identity.
  viewport,

  /// `componentMatrixGolden`: the capture is the widget's intrinsic size, so
  /// the device segment is dropped — and with it the reason to keep more than
  /// one device on the axis.
  component,
}

/// One planned test: a combination and the golden file it will write.
typedef MatrixPlannedTest = ({MatrixCombination combination, String goldenPath});

/// Everything a run is going to do, decided before a single widget is pumped.
///
/// Resolves the preset/axes/sampling/rules precedence, filters scenarios by
/// tag, generates and samples the matrix, and assigns each surviving
/// combination its golden path. The three public test functions and
/// `previewMatrixGolden` all go through here, so there is exactly one answer
/// to "what does this configuration mean" instead of one per call site.
class MatrixRunPlan {
  MatrixRunPlan._({
    required this.name,
    required this.axes,
    required this.sampling,
    required this.rules,
    required this.scenarios,
    required this.tests,
    required this.pathScheme,
    required this.usesCustomPaths,
  });

  /// Resolves a configuration into a plan.
  ///
  /// [name] is the bare identifier the caller passed to `matrixGolden` and
  /// friends — without the `matrixGolden: ` display prefix — because it is
  /// also the leading path segment of every default golden path.
  ///
  /// Throws [ArgumentError] when [scenarioTags] matches no scenario, and
  /// whatever [MatrixGenerator.generate] throws for invalid axes.
  static MatrixRunPlan resolve({
    required String name,
    required List<MatrixScenario> scenarios,
    MatrixAxes? axes,
    MatrixPreset? preset,
    MatrixSampling? sampling,
    int? maxCombinations,
    List<MatrixRule> rules = const [],
    List<String>? scenarioTags,
    String Function(MatrixCombination)? fileNameBuilder,
    MatrixPathScheme pathScheme = MatrixPathScheme.viewport,
  }) {
    final declaredAxes = axes ?? preset?.axes ?? const MatrixAxes();
    // Component mode renders at intrinsic size and its paths carry no device
    // segment, so a second device would register another test writing the very
    // same PNG. Collapsing here — before generation — also keeps the device out
    // of rules, sampling and report counters.
    final effectiveAxes =
        pathScheme == MatrixPathScheme.component && declaredAxes.devices.length > 1
            ? declaredAxes.copyWith(devices: [declaredAxes.devices.first])
            : declaredAxes;
    final effectiveSampling = sampling ?? preset?.sampling ?? MatrixSampling.full;
    final effectiveRules = [...?preset?.rules, ...rules];

    final filteredScenarios = scenarioTags != null
        ? scenarios.where((s) => s.tags.any((t) => scenarioTags.contains(t))).toList()
        : scenarios;

    // Without this, tag filtering that matches nothing surfaces as the
    // generator's generic "scenarios must not be empty", pointing at the wrong
    // argument.
    if (filteredScenarios.isEmpty && scenarios.isNotEmpty) {
      throw ArgumentError.value(
        scenarioTags,
        'scenarioTags',
        'matched none of the ${scenarios.length} scenarios '
            '(their tags: ${scenarios.expand((s) => s.tags).toSet().join(', ')})',
      );
    }

    final combinations = MatrixGenerator.generate(
      scenarios: filteredScenarios,
      axes: effectiveAxes,
      sampling: effectiveSampling,
      rules: effectiveRules,
      maxCombinations: maxCombinations,
    );

    final tests = <MatrixPlannedTest>[
      for (final c in combinations)
        (combination: c, goldenPath: _pathFor(c, name, pathScheme, fileNameBuilder)),
    ];

    return MatrixRunPlan._(
      name: name,
      axes: effectiveAxes,
      sampling: effectiveSampling,
      rules: effectiveRules,
      scenarios: filteredScenarios,
      tests: List.unmodifiable(tests),
      pathScheme: pathScheme,
      usesCustomPaths: fileNameBuilder != null,
    );
  }

  static String _pathFor(
    MatrixCombination c,
    String name,
    MatrixPathScheme scheme,
    String Function(MatrixCombination)? fileNameBuilder,
  ) {
    if (fileNameBuilder != null) return fileNameBuilder(c);
    return switch (scheme) {
      MatrixPathScheme.viewport => NamingStrategy.goldenPath(c, testName: name),
      MatrixPathScheme.component => NamingStrategy.componentGoldenPath(c, testName: name),
    };
  }

  /// Bare test identifier — also the leading segment of default golden paths.
  final String name;

  /// Axes after preset resolution and, in component mode, device collapse.
  final MatrixAxes axes;

  /// Sampling strategy after preset resolution.
  final MatrixSampling sampling;

  /// Preset rules followed by call-site rules, in application order.
  final List<MatrixRule> rules;

  /// Scenarios surviving [MatrixRunPlan.resolve]'s tag filter.
  final List<MatrixScenario> scenarios;

  /// Every combination that will run, paired with the golden it will write.
  final List<MatrixPlannedTest> tests;

  /// Naming scheme used for default golden paths.
  final MatrixPathScheme pathScheme;

  /// Whether golden paths came from a caller-supplied `fileNameBuilder`.
  ///
  /// Stale detection is off in that case: the scanner only understands the
  /// built-in layout, so any custom path looks orphaned to it.
  final bool usesCustomPaths;

  /// Number of planned tests.
  int get length => tests.length;

  /// Whether the configuration filtered every combination out.
  bool get isEmpty => tests.isEmpty;

  /// Planned combinations, in run order.
  List<MatrixCombination> get combinations => [for (final t in tests) t.combination];

  /// Planned golden paths, in run order and parallel to [combinations].
  List<String> get goldenPaths => [for (final t in tests) t.goldenPath];

  /// Planned tests grouped by scenario name, preserving declaration order.
  late final Map<String, List<MatrixPlannedTest>> byScenario = () {
    final grouped = <String, List<MatrixPlannedTest>>{};
    for (final t in tests) {
      (grouped[t.combination.scenario.name] ??= []).add(t);
    }
    return grouped;
  }();

  /// Golden paths claimed by more than one combination, each listed once in
  /// first-occurrence order.
  ///
  /// A duplicate means two tests write and compare the same PNG: whichever
  /// runs last wins, and the other combination is never actually verified.
  late final List<String> duplicatePaths = () {
    final counts = <String, int>{};
    for (final t in tests) {
      counts[t.goldenPath] = (counts[t.goldenPath] ?? 0) + 1;
    }
    final seen = <String>{};
    return <String>[
      for (final t in tests)
        if (counts[t.goldenPath]! > 1 && seen.add(t.goldenPath)) t.goldenPath,
    ];
  }();

  /// Size of the full Cartesian product, before rules and sampling.
  late final int rawCount = () {
    if (scenarios.isEmpty) return 0;
    final themes = axes.themes.isEmpty ? 1 : axes.themes.length;
    final locales = axes.locales.isEmpty ? 1 : axes.locales.length;
    final textScales = axes.textScales.isEmpty ? 1 : axes.textScales.length;
    final devices = axes.devices.isEmpty ? 1 : axes.devices.length;
    // When directions is empty the generator infers one direction per locale.
    final directions = axes.directions.isEmpty ? 1 : axes.directions.length;
    return scenarios.length * themes * locales * textScales * devices * directions;
  }();

  /// Combinations surviving the rules, before sampling and the cap.
  ///
  /// Computed on demand: only `previewMatrixGolden` reports it, and paying for
  /// a second generation on every test run would be pure waste.
  late final int afterRulesCount = scenarios.isEmpty
      ? 0
      : MatrixGenerator.generate(scenarios: scenarios, axes: axes, rules: rules).length;

  /// A human-readable warning when the plan will not do what the caller
  /// probably meant, or null when it will.
  ///
  /// Covers the two silent failures: registering no tests at all (which looks
  /// exactly like a passing run) and two combinations sharing one golden file.
  String? describeProblems() {
    if (isEmpty) {
      final componentNote = pathScheme == MatrixPathScheme.component
          ? ' Note that component mode collapses the devices axis to its first '
              'value, so rules matching on c.device only ever see that one.'
          : '';
      return '"$name" produced no combinations — rules or scenarioTags filtered '
          'every one out, so no tests were registered.$componentNote';
    }
    if (duplicatePaths.isNotEmpty) {
      final shown = duplicatePaths.take(5).join(', ');
      final more = duplicatePaths.length > 5 ? ', …' : '';
      return '"$name" maps ${duplicatePaths.length} golden path(s) to more than '
          'one combination, so each is written by whichever test runs last and '
          'the others are never really compared: $shown$more';
    }
    return null;
  }

  /// Prints [describeProblems] to the console when there is something to say.
  void warnAboutProblems() {
    final problem = describeProblems();
    if (problem != null) warnGoldenMatrix(problem);
  }
}
