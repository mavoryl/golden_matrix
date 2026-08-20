import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:golden_matrix/src/core/join_path.dart';
import 'package:golden_matrix/src/core/matrix_report_writer.dart';
import 'package:golden_matrix/src/core/report_format.dart';
import 'package:golden_matrix/src/core/run_clock.dart';
import 'package:golden_matrix/src/core/slug.dart';
import 'package:golden_matrix/src/flutter/stale_scan.dart';
import 'package:golden_matrix/src/models/matrix_result.dart';

/// Registers the `setUpAll` that opens a run's clock and the `tearDownAll` that
/// closes the run out: stops the clock, scans for stale goldens, assembles the
/// [MatrixResult], writes every requested report format and prints the console
/// summary.
///
/// The clock is started from `setUpAll` rather than by the caller, because a
/// runner body executes at *declaration* time — starting it there timed the
/// declaration of every group below it as part of this run.
///
/// Shared by all three runners. Each used to carry its own copy of this
/// teardown, and the copies had already drifted — the component one resolved
/// its default report directory through a second, identical private helper and
/// slugged a different name for the stale scan.
///
/// - [reportName] is the display name (`matrixGolden: Foo`) that ends up in the
///   report and in its file name.
/// - [testSlug] is the bare identifier used to locate the golden directory for
///   stale detection — the leading path segment of the run's goldens.
void installReportPipeline({
  required String reportName,
  required String testSlug,
  required List<MatrixCombinationResult> results,
  required MatrixRunClock clock,
  required String? reportDir,
  required bool printSummary,
  required Set<MatrixReportFormat> formats,
  required bool detectStaleGoldens,
}) {
  // At declaration time, so a name collision surfaces next to the offending
  // call site instead of after the whole suite has run.
  MatrixReportWriter.claimReportName(reportName);
  setUpAll(clock.start);
  tearDownAll(
    () => finishRun(
      reportName: reportName,
      testSlug: testSlug,
      results: results,
      clock: clock,
      reportDir: reportDir,
      printSummary: printSummary,
      formats: formats,
      detectStaleGoldens: detectStaleGoldens,
    ),
  );
}

/// The body of [installReportPipeline]'s teardown, callable on its own.
///
/// Split out so the closing sequence can be tested without staging a run and
/// racing the test framework's own teardown ordering.
Future<void> finishRun({
  required String reportName,
  required String testSlug,
  required List<MatrixCombinationResult> results,
  required MatrixRunClock clock,
  required String? reportDir,
  required bool printSummary,
  required Set<MatrixReportFormat> formats,
  required bool detectStaleGoldens,
}) async {
  clock.stop();
  final stale = detectStaleGoldens
      ? await scanStaleGoldens(
          testSlug: slugify(testSlug),
          expectedPaths: results.map((r) => r.goldenPath).toSet(),
        )
      : <String>[];

  final result = MatrixResult(
    name: reportName,
    results: results,
    // A run whose clock never started registered no tests, or had all of them
    // skipped; there is no start time to report, so `MatrixResult` stamps now.
    timestamp: clock.startedAt,
    duration: clock.elapsed,
    staleGoldens: stale,
  );

  await MatrixReportWriter.writeAll(
    result,
    outputDir: reportDir ?? resolveDefaultReportDir(),
    formats: formats,
  );

  if (printSummary) {
    debugPrint(formatSummary(result));
  }

  // When no reports are written, surface stale goldens to the console so
  // users who deliberately disable reports still see correctness issues.
  if (formats.isEmpty && stale.isNotEmpty) {
    debugPrint('golden_matrix: $reportName has ${stale.length} stale golden file(s):');
    for (final path in stale) {
      debugPrint('  - $path');
    }
  }
}

/// Resolves the default report directory when `reportDir` is omitted.
///
/// Derives the goldens root from the active golden comparator's `basedir`
/// (`<test-file-dir>/goldens`) — the authoritative location next to the
/// golden PNGs, regardless of what the test file's directory is named. This
/// replaces the old prefix-guessing heuristic, which only knew `test/`,
/// `test/golden/`, and `test/goldens/` and dumped reports into a stray
/// top-level `goldens/` for any other layout. Returns null for non-local
/// comparators so the writer falls back to its own heuristic.
String? resolveDefaultReportDir() {
  final comparator = goldenFileComparator;
  if (comparator is! LocalFileComparator) return null;
  return joinPath(Directory.fromUri(comparator.basedir).path, 'goldens');
}

/// Formats a human-readable summary of a [MatrixResult] for console output.
///
/// Includes counts, duration, and a list of failed combinations.
String formatSummary(MatrixResult result) {
  final buf = StringBuffer();
  buf.writeln(result.name);

  final parts = <String>[
    '${result.total} total',
    '${result.passed} passed',
    if (result.failed > 0) '${result.failed} failed',
    if (result.skipped > 0) '${result.skipped} skipped',
    if (result.warningCount > 0) '${result.warningCount} warnings',
    if (result.staleGoldens.isNotEmpty) '${result.staleGoldens.length} stale',
  ];
  final duration = result.duration.inMilliseconds < 1000
      ? '${result.duration.inMilliseconds}ms'
      : '${result.duration.inSeconds}s';
  buf.writeln('  ${parts.join(' | ')} ($duration)');

  final failed = result.results.where((r) => r.status == MatrixResultStatus.failed);
  if (failed.isNotEmpty) {
    buf.writeln('  Failed:');
    for (final f in failed) {
      final c = f.combination;
      final dir = c.direction == TextDirection.ltr ? 'ltr' : 'rtl';
      buf.writeln(
        '    - ${c.scenario.name} | ${c.theme.name} ${c.locale} $dir ${c.textScale}x ${c.device.name}',
      );
    }
  }

  if (result.staleGoldens.isNotEmpty) {
    buf.writeln('  Stale (orphan goldens — not produced by any combination):');
    for (final path in result.staleGoldens) {
      buf.writeln('    - $path');
    }
  }

  return buf.toString().trimRight();
}
