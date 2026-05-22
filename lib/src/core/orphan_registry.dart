import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Process-global registry of test-subdirectory slugs touched by
/// `matrixGolden` / `screenMatrixGolden` calls during the current test
/// session.
///
/// Each `runMatrixTests` records its slug — `slugify(_stripPrefix(name))`
/// — at the start of its `group` body. After all tests finish (typically
/// in `flutter_test_config.dart`'s `testExecutable` after
/// `await testMain()`), call [reportOrphanGoldenSubdirs] to detect
/// top-level directories under `goldens/` that no test wrote to.
///
/// The registry is a process-global. Each `flutter test` run starts a
/// fresh process so cross-run contamination is impossible. Within a run,
/// multiple `matrixGolden` calls append cumulatively.
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

/// Reports top-level subdirectories under [goldensRoot] that no
/// `matrixGolden` / `screenMatrixGolden` call touched in this test
/// session — typically caused by renamed or deleted matrix tests.
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
Future<List<String>> reportOrphanGoldenSubdirs({String? goldensRoot, bool fail = false}) async {
  final root = goldensRoot != null ? Directory(goldensRoot) : _defaultGoldensRoot();
  if (root == null || !root.existsSync()) return const [];

  final touched = MatrixGoldenRegistry.touched;
  final orphans = <String>[];
  for (final entity in root.listSync()) {
    if (entity is! Directory) continue;
    final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
    if (name == 'failures') continue; // Flutter's diff output
    if (touched.contains(name)) continue;
    orphans.add(name);
  }
  orphans.sort();

  if (orphans.isNotEmpty) {
    debugPrint('golden_matrix: ${orphans.length} orphan golden subdir(s):');
    for (final o in orphans) {
      debugPrint('  - ${root.path}/$o');
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
  return Directory('${basedir.path}${Platform.pathSeparator}goldens');
}
