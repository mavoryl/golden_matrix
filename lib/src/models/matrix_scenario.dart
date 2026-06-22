import 'package:flutter/widgets.dart';

import 'package:golden_matrix/src/core/slug.dart';

/// A builder function that creates a widget for a test scenario.
typedef ScenarioBuilder = Widget Function();

/// Represents a single test scenario in the matrix.
class MatrixScenario {
  /// Creates a scenario with [name] and a widget [builder].
  ///
  /// [tags] can be used to filter scenarios via `scenarioTags:` on
  /// `matrixGolden`/`screenMatrixGolden`.
  const MatrixScenario(this.name, {required this.builder, this.tags = const []})
      : assert(name != '', 'MatrixScenario name must not be empty');

  /// Human-readable name used in golden file paths and reports.
  final String name;

  /// Builder that returns the widget under test.
  final ScenarioBuilder builder;

  /// Tags used to selectively include/exclude this scenario.
  final List<String> tags;

  /// Slugified [name] suitable for use in file paths.
  String get slug => slugify(name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MatrixScenario && other.name == name);

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'MatrixScenario($name)';
}
