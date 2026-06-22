import 'dart:io';

/// Detects "stale" golden PNG files in [testSubdir] — files on disk that
/// the matrix did not produce in the current run.
///
/// A file is considered stale when its path (relative to [testSubdir]'s
/// parent — typically `goldens/`) is not in [expectedPaths].
///
/// Flutter's own `failures/` subdirectories (where `LocalFileComparator`
/// writes diff images) are entirely skipped: anything under a path
/// segment named `failures` is ignored.
///
/// Returns an empty list when [testSubdir] does not exist (e.g. the very
/// first run before `flutter test --update-goldens`).
///
/// Results are sorted lexicographically for stable test output and
/// diffable reports.
Future<List<String>> findStaleGoldens({
  required Set<String> expectedPaths,
  required Directory testSubdir,
  required Directory goldensRoot,
}) async {
  if (!testSubdir.existsSync()) return const [];

  final stale = <String>[];
  await for (final entity in testSubdir.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    if (!entity.path.toLowerCase().endsWith('.png')) continue;
    if (_isInsideFailuresDir(entity.path)) continue;

    final relPath = _relativePosix(entity.path, goldensRoot.path);
    final asGolden = 'goldens/$relPath';
    if (!expectedPaths.contains(asGolden)) {
      stale.add(asGolden);
    }
  }

  stale.sort();
  return stale;
}

bool _isInsideFailuresDir(String filePath) {
  final segments = filePath.split(Platform.pathSeparator);
  return segments.contains('failures');
}

/// Computes a POSIX-style relative path from [base] to [target].
/// Used to keep golden paths consistent across operating systems (so
/// the same JSON/HTML output is produced on Linux and macOS CI).
String _relativePosix(String target, String base) {
  final normalizedBase =
      base.endsWith(Platform.pathSeparator) ? base : '$base${Platform.pathSeparator}';
  final rel = target.startsWith(normalizedBase) ? target.substring(normalizedBase.length) : target;
  return rel.replaceAll(Platform.pathSeparator, '/');
}
