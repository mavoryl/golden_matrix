import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Process-global registry of test-subdirectory slugs touched by
/// `matrixGolden` / `screenMatrixGolden` calls during the current test
/// session.
///
/// **Deprecated in 0.18.1.** The registry is per-isolate and
/// `flutter test` runs test files in parallel isolates by default,
/// so the registry only ever sees a subset of slugs in any given
/// process. That made [reportOrphanGoldenSubdirs] unreliable for its
/// stated purpose (detecting whole-test renames/deletions). Per-test
/// **stale detection** — enabled by default via `detectStaleGoldens`
/// on `matrixGolden` / `screenMatrixGolden` — already catches the
/// common case (scenario-level orphans like `goldens/dialog/alert/`).
/// A post-suite CLI tool for accurate top-level orphan detection is
/// planned for a future release.
@Deprecated(
  'Top-level orphan detection is unreliable under parallel-isolate test '
  'execution. Per-test stale detection (detectStaleGoldens, default true) '
  'already catches scenario-level orphans. Planned replacement: a '
  'post-suite CLI tool.',
)
abstract class MatrixGoldenRegistry {
  static final Set<String> _slugs = <String>{};

  /// Records that a `matrixGolden` / `screenMatrixGolden` call with the
  /// given [slug] is part of this test session. Called automatically by
  /// `runMatrixTests`; usually nothing for users to do.
  static void recordTouched(String slug) => _slugs.add(slug);

  /// Snapshot of slugs touched so far. Exposed primarily for testing
  /// and advanced custom assertions in `flutter_test_config.dart`.
  static Set<String> get touched => Set.unmodifiable(_slugs);

  /// Clears the registry. Mostly useful for test isolation; production
  /// users do not need to call this.
  @visibleForTesting
  static void reset() => _slugs.clear();
}

/// **Deprecated in 0.18.1.** Reports top-level subdirectories under
/// [goldensRoot] that no `matrixGolden` / `screenMatrixGolden` call
/// touched in this test session.
///
/// The function exists in 0.18.x only for backward compatibility and
/// is **unreliable** under parallel-isolate test execution (the default
/// `flutter test` mode). Use per-test stale detection instead — it's
/// enabled by default via `detectStaleGoldens` on `matrixGolden` /
/// `screenMatrixGolden` and catches scenario-level orphans like
/// `goldens/dialog/alert/`. A post-suite CLI tool for accurate
/// top-level orphan detection is planned for a future release.
///
/// Below documents the original (deprecated) semantics — kept here so
/// existing callers continue to compile.
///
/// **Scope.** This only checks the **first level** under
/// [goldensRoot] (e.g. `goldens/dialog/`). Stale **scenario** subdirs
/// inside a test (e.g. `goldens/dialog/old_scenario/`) are detected
/// per-test by the built-in stale checker that runs as part of every
/// `matrixGolden` / `screenMatrixGolden` call (see `detectStaleGoldens`
/// on those APIs). Don't expect `reportOrphanGoldenSubdirs` to catch
/// scenario-level orphans — that's a different mechanism.
///
/// **Concurrency caveat.** The matrix registry that backs this
/// function is per-isolate. `flutter test` runs test files in parallel
/// isolates by default, so each isolate only sees its own slugs. To
/// avoid false positives, this function returns early (with a debug
/// message) when the registry is empty but the goldens root contains
/// subdirectories — almost always the parallel-execution case. Run
/// `flutter test --concurrency=1` if you need orphan detection from
/// `flutter_test_config.dart`.
///
/// Returns the list of orphan directory names (sorted, just the leaf
/// name — not absolute paths). Excludes Flutter's own `failures/`
/// directory.
///
/// When [goldensRoot] is null, resolves to the current
/// `goldenFileComparator.basedir + 'goldens/'` — matches the convention
/// used throughout the package.
///
/// When [fail] is `true` and orphans are found, throws [StateError]
/// after printing the list via `debugPrint`. Use this from
/// `flutter_test_config.dart` to make CI go red on orphan accumulation:
///
/// ```dart
/// Future<void> testExecutable(FutureOr<void> Function() testMain) async {
///   await loadAppFonts();
///   await testMain();
///   await reportOrphanGoldenSubdirs(fail: isCiEnvironment);
/// }
/// ```
@Deprecated(
  'Top-level orphan detection is unreliable under parallel-isolate test '
  'execution. Use per-test stale detection (detectStaleGoldens, default true) '
  'on matrixGolden/screenMatrixGolden — it already catches scenario-level '
  'orphans. Planned replacement: a post-suite CLI tool.',
)
Future<List<String>> reportOrphanGoldenSubdirs({String? goldensRoot, bool fail = false}) async {
  final root = goldensRoot != null ? Directory(goldensRoot) : _defaultGoldensRoot();
  if (root == null || !root.existsSync()) return const [];

  final touched = MatrixGoldenRegistry.touched;
  final candidates = <Directory>[];
  for (final entity in root.listSync()) {
    if (entity is! Directory) continue;
    final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
    if (name == 'failures') continue; // Flutter's diff output
    candidates.add(entity);
  }

  final orphans = <String>[];
  for (final entity in candidates) {
    final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
    if (touched.contains(name)) continue;
    orphans.add(name);
  }
  orphans.sort();

  // Parallel `flutter test` runs each test file in its own isolate, and the
  // matrix registry is per-isolate. The signature of that case: every isolate
  // sees a small number of touched slugs but the on-disk goldens root holds
  // many more — so almost every subdir looks orphaned. Detect that and skip
  // with a clear hint instead of polluting output.
  //
  // For legitimate bulk-cleanup scenarios (e.g. deleting several tests at
  // once), run `flutter test --concurrency=1` so all matrixGolden calls
  // register in the same isolate and orphan detection becomes accurate.
  final looksParallelIsolate = orphans.length > touched.length && orphans.length > 1;
  if (touched.isEmpty || looksParallelIsolate) {
    debugPrint(
      'golden_matrix: reportOrphanGoldenSubdirs skipped — registry has '
      '${touched.length} touched slug(s) but ${candidates.length} subdir(s) '
      'on disk. This is the parallel-isolate case; run `flutter test '
      '--concurrency=1` for accurate top-level orphan detection. (Per-test '
      'stale detection still works correctly under parallel runs.)',
    );
    return const [];
  }

  if (orphans.isNotEmpty) {
    debugPrint('golden_matrix: ${orphans.length} orphan golden subdir(s):');
    for (final o in orphans) {
      debugPrint('  - ${_joinGoldens(root.path, o)}');
    }
    if (fail) {
      throw StateError(
        'golden_matrix: ${orphans.length} orphan golden subdir(s) detected: $orphans. '
        'Either remove them or restore the matrixGolden tests that produced them.',
      );
    }
  }

  return orphans;
}

/// Resolves the goldens root from the active comparator's basedir.
/// Returns null when the comparator is not a [LocalFileComparator]
/// (e.g. inside `integration_test` on a device).
Directory? _defaultGoldensRoot() {
  final comparator = goldenFileComparator;
  if (comparator is! LocalFileComparator) return null;
  final basedir = Directory.fromUri(comparator.basedir);
  return Directory(_joinGoldens(basedir.path, 'goldens'));
}

/// Joins [base] and [leaf] with a single path separator regardless of
/// whether [base] ends in one. `Directory.fromUri(...).path` for a
/// directory URI commonly contains a trailing separator, which would
/// otherwise produce `foo//bar`-style paths in user-visible output.
String _joinGoldens(String base, String leaf) {
  final sep = Platform.pathSeparator;
  final trimmed = base.endsWith(sep) ? base.substring(0, base.length - sep.length) : base;
  return '$trimmed$sep$leaf';
}
