import 'package:flutter/widgets.dart';

import 'matrix_combination.dart';

/// The status of a single combination test result.
enum MatrixResultStatus { passed, failed, skipped }

/// Result of a single combination's golden test.
///
/// One [MatrixCombinationResult] is produced for every
/// [MatrixCombination] rendered during a matrix golden run. Results
/// are aggregated in [MatrixResult] and written to the JSON/HTML
/// report.
class MatrixCombinationResult {
  /// The combination that produced this result.
  final MatrixCombination combination;

  /// Pass / fail / skip status.
  final MatrixResultStatus status;

  /// The on-disk path of the golden file compared against.
  final String goldenPath;

  /// Error message when [status] is [MatrixResultStatus.failed], else `null`.
  final String? errorMessage;

  /// Non-fatal warnings captured during the test (e.g. RenderFlex overflows).
  final List<String> warnings;

  const MatrixCombinationResult({
    required this.combination,
    required this.status,
    required this.goldenPath,
    this.errorMessage,
    this.warnings = const [],
  });

  /// Serializes this result to a JSON-compatible map.
  ///
  /// Example output:
  /// ```json
  /// {
  ///   "scenario": "default",
  ///   "theme": "dark",
  ///   "locale": "en",
  ///   "textScale": 1.0,
  ///   "device": "phoneSmall",
  ///   "direction": "ltr",
  ///   "status": "passed",
  ///   "goldenPath": "goldens/default/dark_en_ltr_1x_phone-small.png"
  /// }
  /// ```
  ///
  /// `error` is included only when [errorMessage] is non-null;
  /// `warnings` is included only when non-empty.
  Map<String, dynamic> toJson() => {
    'scenario': combination.scenario.name,
    'theme': combination.theme.name,
    'locale': combination.locale.toLanguageTag(),
    'textScale': combination.textScale,
    'device': combination.device.name,
    'direction': combination.direction == TextDirection.ltr ? 'ltr' : 'rtl',
    'status': status.name,
    'goldenPath': goldenPath,
    if (errorMessage != null) 'error': errorMessage,
    if (warnings.isNotEmpty) 'warnings': warnings,
  };
}

/// Aggregated result of a matrix golden test run.
///
/// Holds the per-combination [MatrixCombinationResult]s for a single
/// `matrixGolden` or `screenMatrixGolden` invocation, along with run
/// metadata and convenience counters.
class MatrixResult {
  /// Test group name (the first argument to `matrixGolden`).
  final String name;

  /// Per-combination results, one entry for every rendered combination.
  final List<MatrixCombinationResult> results;

  /// When the run started.
  final DateTime timestamp;

  /// Total wall-clock duration of the run.
  final Duration duration;

  /// Golden file paths (relative, e.g. `goldens/mywidget/old/light.png`)
  /// found in this test's golden subdirectory on disk but **not** produced
  /// by any combination in the current matrix.
  ///
  /// Common causes: a scenario was renamed, an axis value was dropped, or
  /// the entire matrix shape changed since the baselines were last
  /// generated. Surfaced in the console summary and the HTML / JSON
  /// reports so the user can clean them up safely.
  ///
  /// Detection is skipped (this list stays empty) when:
  /// - the runner was invoked with `detectStaleGoldens: false`, or
  /// - a custom `fileNameBuilder` is supplied (paths are not relative to
  ///   the conventional `goldens/<test>/` subdir).
  final List<String> staleGoldens;

  MatrixResult({
    required this.name,
    required this.results,
    DateTime? timestamp,
    this.duration = Duration.zero,
    this.staleGoldens = const [],
  }) : timestamp = timestamp ?? DateTime.now();

  /// Total number of combinations rendered.
  int get total => results.length;

  /// Number of combinations that passed.
  int get passed => results.where((r) => r.status == MatrixResultStatus.passed).length;

  /// Number of combinations that failed.
  int get failed => results.where((r) => r.status == MatrixResultStatus.failed).length;

  /// Number of combinations that were skipped.
  int get skipped => results.where((r) => r.status == MatrixResultStatus.skipped).length;

  /// Total number of warnings across all combinations.
  int get warningCount => results.fold(0, (sum, r) => sum + r.warnings.length);

  /// Serializes this aggregated result to a JSON-compatible map.
  ///
  /// Example output:
  /// ```json
  /// {
  ///   "name": "matrixGolden: PrimaryButton",
  ///   "timestamp": "2026-05-12T10:15:30.000Z",
  ///   "durationMs": 1240,
  ///   "total": 16,
  ///   "passed": 15,
  ///   "failed": 1,
  ///   "skipped": 0,
  ///   "warnings": 2,
  ///   "results": [ /* MatrixCombinationResult.toJson() entries */ ]
  /// }
  /// ```
  Map<String, dynamic> toJson() => {
    'name': name,
    'timestamp': timestamp.toIso8601String(),
    'durationMs': duration.inMilliseconds,
    'total': total,
    'passed': passed,
    'failed': failed,
    'skipped': skipped,
    'warnings': warningCount,
    'results': results.map((r) => r.toJson()).toList(),
    if (staleGoldens.isNotEmpty) 'staleGoldens': staleGoldens,
  };
}
