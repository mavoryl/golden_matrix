import 'package:flutter/widgets.dart';

import '../core/slug.dart';

/// A builder function that creates a widget for a test scenario.
typedef ScenarioBuilder = Widget Function();

/// Represents a single test scenario in the matrix.
class MatrixScenario {
  final String name;
  final ScenarioBuilder builder;
  final List<String> tags;

  const MatrixScenario(this.name, {required this.builder, this.tags = const []})
    : assert(name != '', 'MatrixScenario name must not be empty');

  String get slug => slugify(name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MatrixScenario && other.name == name);

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'MatrixScenario($name)';
}
