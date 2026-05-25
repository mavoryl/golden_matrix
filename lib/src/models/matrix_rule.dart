import 'matrix_combination.dart';

/// The type of matrix rule.
enum MatrixRuleType {
  /// Excludes combinations matching the predicate.
  exclude,

  /// Keeps only combinations matching the predicate.
  includeOnly,
}

/// A rule for filtering matrix combinations.
///
/// Rules are predicate-based and composable. They are applied to the
/// full Cartesian product before sampling — all `exclude` rules run
/// first, then all `includeOnly` rules.
///
/// ## Examples
///
/// Exclude RTL combinations unless the locale is Arabic:
///
/// ```dart
/// MatrixRule.exclude(
///   (c) => c.direction == TextDirection.rtl && c.locale.languageCode != 'ar',
/// );
/// ```
///
/// Skip the dark-theme + large-text combination (known visual noise):
///
/// ```dart
/// MatrixRule.exclude((c) => c.theme.isDark && c.textScale >= 1.5);
/// ```
///
/// Include only the smallest device — useful for triaging a single
/// failing form factor:
///
/// ```dart
/// MatrixRule.includeOnly((c) => c.device == MatrixDevice.phoneSmall);
/// ```
///
/// Skip a specific scenario on tablets:
///
/// ```dart
/// MatrixRule.exclude(
///   (c) => c.scenario.name == 'compact' && c.device == MatrixDevice.tablet,
/// );
/// ```
class MatrixRule {
  const MatrixRule._(this.predicate, this.type);

  /// Creates a rule that excludes combinations matching the [predicate].
  ///
  /// Combinations for which [predicate] returns `true` are removed from
  /// the matrix.
  factory MatrixRule.exclude(bool Function(MatrixCombination) predicate) =>
      MatrixRule._(predicate, MatrixRuleType.exclude);

  /// Creates a rule that keeps only combinations matching the [predicate].
  ///
  /// Combinations for which [predicate] returns `false` are removed
  /// from the matrix. Multiple `includeOnly` rules compose as logical
  /// AND.
  factory MatrixRule.includeOnly(bool Function(MatrixCombination) predicate) =>
      MatrixRule._(predicate, MatrixRuleType.includeOnly);

  /// The predicate used to evaluate each [MatrixCombination].
  final bool Function(MatrixCombination) predicate;

  /// Whether this rule excludes or includes matching combinations.
  final MatrixRuleType type;
}
