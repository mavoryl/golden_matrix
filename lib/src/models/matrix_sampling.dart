/// Strategy for reducing the matrix of combinations.
///
/// Combinatorial golden testing grows multiplicatively: 3 themes ×
/// 4 locales × 3 text scales × 5 devices = 180 tests per scenario. Most
/// of those tests catch nothing new. Sampling strategies trade exhaustive
/// coverage for runtime by selecting a representative subset.
///
/// ## Example reductions
///
/// Assume axes: 2 themes × 3 locales × 3 text scales × 5 devices = 90.
///
/// | Strategy        | Tests | Notes                                    |
/// |-----------------|-------|------------------------------------------|
/// | `full`          | 90    | Exhaustive.                              |
/// | `smoke`         | ~5    | Base + one delta per axis.               |
/// | `pairwise`      | ~15   | Every value pair appears at least once.  |
/// | `priorityBased` | top N | Sorted by "scariness" score.             |
///
/// Pairwise is usually the best balance for CI; smoke is best for local
/// dev feedback; priorityBased is best for catching high-risk regressions.
enum MatrixSampling {
  /// Full Cartesian product of every axis.
  ///
  /// Use when you need exhaustive coverage and the matrix is small
  /// (under ~50 combinations) — for example a flagship widget with two
  /// themes and three devices. For larger matrices the runtime cost is
  /// usually prohibitive.
  full,

  /// Minimal representative subset: one base combo plus one delta per axis.
  ///
  /// Picks the first value from every axis as a baseline, then for each
  /// axis with more than one value adds a single combination that varies
  /// only that axis. With four multi-value axes you get roughly 5 tests
  /// instead of 32.
  ///
  /// Use for fast local feedback. Trade-off: smoke sampling does not
  /// exercise interactions between axes (e.g. dark theme + RTL +
  /// largest text together), so it can miss interaction bugs.
  smoke,

  /// High-value combinations first, sorted by a "scariness" score.
  ///
  /// Each combination is scored by how likely it is to expose layout
  /// regressions — dark theme combined with large text, RTL on the
  /// smallest device, non-default locale on a non-default device, and
  /// so on. The list is sorted by descending score.
  ///
  /// Pair with `maxCombinations` to keep only the top N most likely
  /// failure modes. Best when you have a known budget of N tests and
  /// want them to be the most informative N possible.
  priorityBased,

  /// All-pairs coverage via the greedy pairwise (Microsoft PICT)
  /// algorithm.
  ///
  /// Guarantees that every pair of parameter values from any two axes
  /// appears together in at least one test case. Catches most
  /// interaction bugs at a fraction of the cost of [full] — for example
  /// roughly 12 tests instead of 270.
  ///
  /// Recommended default for CI matrices with three or more multi-value
  /// axes.
  ///
  /// The coverage guarantee holds over the **feasible** set: when exclusion
  /// rules leave only a sparse set of tuples, selection runs over the surviving
  /// combinations rather than over per-axis domains.
  ///
  /// A `maxCombinations` cap below what the covering array needs cannot be
  /// honoured together with the guarantee — the cap wins, the guarantee is lost,
  /// and a warning is printed. Use [priorityBased] when a hard budget matters
  /// more than pair coverage.
  pairwise,
}
