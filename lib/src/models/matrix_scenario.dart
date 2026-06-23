import 'package:flutter/widgets.dart';

import 'package:golden_matrix/src/core/slug.dart';

/// A builder function that creates a widget for a test scenario.
typedef ScenarioBuilder = Widget Function();

/// A builder that creates a widget from a typed [payload].
///
/// Used by [MatrixScenario.typed] so one builder can be reused across
/// scenarios that differ only by their (compile-time-checked) state.
typedef TypedScenarioBuilder<T> = Widget Function(T payload);

/// Represents a single test scenario in the matrix.
class MatrixScenario {
  /// Creates a scenario with [name] and a widget [builder].
  ///
  /// [tags] can be used to filter scenarios via `scenarioTags:` on
  /// `matrixGolden`/`screenMatrixGolden`.
  ///
  /// [payload] is optional and usually set via [MatrixScenario.typed]; it is
  /// attached for introspection/reporting and does not affect identity.
  const MatrixScenario(
    this.name, {
    required this.builder,
    this.tags = const [],
    this.payload,
  }) : assert(name != '', 'MatrixScenario name must not be empty');

  /// Creates a scenario from a typed [payload] and a [builder] that consumes
  /// it. The same builder can be reused across scenarios that differ only by
  /// their state, with the payload type checked at compile time:
  ///
  /// ```dart
  /// Widget build(UserState s) =>
  ///     BlocProvider(create: (_) => UserCubit()..emit(s), child: const UserList());
  ///
  /// matrixGolden('UserList', scenarios: [
  ///   MatrixScenario.typed('loading', payload: UserState.loading(), builder: build),
  ///   MatrixScenario.typed('loaded',  payload: UserState.loaded([...]), builder: build),
  ///   MatrixScenario.typed('error',   payload: UserState.error('x'),  builder: build),
  /// ]);
  /// ```
  ///
  /// Non-breaking sibling of the default constructor: the typed builder is
  /// wrapped into the zero-argument [builder] (it closes over [payload]), so
  /// the rest of the matrix machinery is unchanged.
  ///
  /// Implemented as a static method (not a named constructor) because Dart
  /// constructors cannot declare their own type parameters; the call syntax
  /// `MatrixScenario.typed<T>(...)` is identical, and `T` is inferred from
  /// [payload]/[builder].
  static MatrixScenario typed<T>(
    String name, {
    required T payload,
    required TypedScenarioBuilder<T> builder,
    List<String> tags = const [],
  }) {
    return MatrixScenario(
      name,
      builder: () => builder(payload),
      tags: tags,
      payload: payload,
    );
  }

  /// Human-readable name used in golden file paths and reports.
  final String name;

  /// Builder that returns the widget under test.
  final ScenarioBuilder builder;

  /// Tags used to selectively include/exclude this scenario.
  final List<String> tags;

  /// The typed payload attached via [MatrixScenario.typed], or `null` for a
  /// plain scenario. Exposed for introspection and reporting; identity is
  /// still based on [name] alone.
  final Object? payload;

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
