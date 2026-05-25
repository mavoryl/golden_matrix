/// Generates pairwise (all-pairs) covering arrays using a greedy algorithm.
///
/// Given a list of parameter sizes (number of values per parameter),
/// produces a minimal set of test cases that covers all pairs of
/// parameter values.
///
/// Example:
/// ```dart
/// // 3 parameters with 2, 3, and 2 values respectively
/// final testCases = PairwiseGenerator.generate([2, 3, 2]);
/// // Returns ~6 test cases instead of 12 (full Cartesian)
/// // Each test case is a List<int> of value indices
/// ```
class PairwiseGenerator {
  /// Generates a pairwise covering array.
  ///
  /// [parameterSizes] is a list where each element is the number of
  /// possible values for that parameter. For example, `[2, 3, 4]` means
  /// 3 parameters with 2, 3, and 4 values respectively.
  ///
  /// Returns a list of test cases. Each test case is a `List<int>` where
  /// the i-th element is the chosen value index for parameter i.
  static List<List<int>> generate(List<int> parameterSizes) {
    if (parameterSizes.isEmpty) return [];
    if (parameterSizes.length == 1) {
      // Single parameter: one test case per value
      return List.generate(parameterSizes[0], (i) => [i]);
    }

    final numParams = parameterSizes.length;

    // Generate all uncovered pairs
    final uncovered = <_Pair>{};
    for (var i = 0; i < numParams; i++) {
      for (var j = i + 1; j < numParams; j++) {
        for (var vi = 0; vi < parameterSizes[i]; vi++) {
          for (var vj = 0; vj < parameterSizes[j]; vj++) {
            uncovered.add(_Pair(i, vi, j, vj));
          }
        }
      }
    }

    final result = <List<int>>[];

    // Greedy loop: build one test case at a time
    while (uncovered.isNotEmpty) {
      final testCase = _buildGreedyTestCase(parameterSizes, uncovered);
      result.add(testCase);

      // Mark pairs covered by this test case
      for (var i = 0; i < numParams; i++) {
        for (var j = i + 1; j < numParams; j++) {
          uncovered.remove(_Pair(i, testCase[i], j, testCase[j]));
        }
      }
    }

    return result;
  }

  /// Builds one test case greedily, choosing each parameter value to
  /// maximize the number of newly covered pairs.
  static List<int> _buildGreedyTestCase(List<int> parameterSizes, Set<_Pair> uncovered) {
    final numParams = parameterSizes.length;
    final chosen = List<int>.filled(numParams, -1);

    for (var paramIdx = 0; paramIdx < numParams; paramIdx++) {
      var bestValue = 0;
      var bestScore = -1;

      for (var value = 0; value < parameterSizes[paramIdx]; value++) {
        var score = 0;

        // Count pairs with already-chosen parameters
        for (var prev = 0; prev < paramIdx; prev++) {
          if (uncovered.contains(_Pair(prev, chosen[prev], paramIdx, value))) {
            score++;
          }
        }

        // Count potential pairs with not-yet-chosen parameters
        for (var next = paramIdx + 1; next < numParams; next++) {
          for (var nv = 0; nv < parameterSizes[next]; nv++) {
            if (uncovered.contains(_Pair(paramIdx, value, next, nv))) {
              score++;
            }
          }
        }

        if (score > bestScore) {
          bestScore = score;
          bestValue = value;
        }
      }

      chosen[paramIdx] = bestValue;
    }

    return chosen;
  }
}

/// Represents a pair of (parameter, value) tuples.
class _Pair {
  const _Pair(this.param1, this.value1, this.param2, this.value2);
  final int param1;
  final int value1;
  final int param2;
  final int value2;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Pair &&
          param1 == other.param1 &&
          value1 == other.value1 &&
          param2 == other.param2 &&
          value2 == other.value2;

  @override
  int get hashCode => Object.hash(param1, value1, param2, value2);
}
