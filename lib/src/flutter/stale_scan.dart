import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/src/core/join_path.dart';
import 'package:golden_matrix/src/core/stale_detector.dart';
import 'package:golden_matrix/src/core/warn.dart';

/// Scans the golden directory of [testSlug] for files the current run did not
/// produce, given the [expectedPaths] it did produce.
///
/// Returns an empty list when the goldens cannot be scanned at all: no
/// `LocalFileComparator` in place (custom comparators own their storage), or no
/// golden directory yet — [findStaleGoldens] treats a missing directory as
/// "nothing stale", which is the correct answer before the first
/// `--update-goldens`.
Future<List<String>> scanStaleGoldens({
  required String testSlug,
  required Set<String> expectedPaths,
}) async {
  final comparator = goldenFileComparator;
  if (comparator is! LocalFileComparator) return const [];

  if (expectedPaths.isEmpty) {
    // Nothing ran, so nothing can be judged orphaned. Reporting every file on
    // disk here would invite deleting a directory over a filtering mistake —
    // rules or scenarioTags that matched nothing.
    warnGoldenMatrix(
      'no combinations were produced for "$testSlug", so stale-golden '
      'detection is skipped — check the rules and scenarioTags for this run',
    );
    return const [];
  }

  final basedir = Directory.fromUri(comparator.basedir);
  final goldensRoot = Directory(joinPath(basedir.path, 'goldens'));
  final testSubdir = Directory(joinPath(goldensRoot.path, testSlug));

  try {
    return await findStaleGoldens(
      expectedPaths: expectedPaths,
      testSubdir: testSubdir,
      goldensRoot: goldensRoot,
    );
  } on FileSystemException catch (e) {
    // A missing directory is already handled inside findStaleGoldens, so
    // reaching here means the filesystem actually refused: permissions, a
    // broken symlink, a path deleted mid-scan. Reporting "nothing is stale"
    // for that is a lie — stale detection is simply off for this run, and the
    // user needs to know.
    warnGoldenMatrix('cannot scan ${testSubdir.path} for stale goldens: ${e.osError ?? e.message}');
    return const [];
  } catch (e) {
    warnGoldenMatrix('unexpected error while scanning ${testSubdir.path} for stale goldens: $e');
    return const [];
  }
}
