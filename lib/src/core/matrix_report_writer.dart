import 'dart:convert';
import 'dart:io';

import 'package:golden_matrix/src/core/html_template.dart';
import 'package:golden_matrix/src/core/join_path.dart';
import 'package:golden_matrix/src/core/junit_template.dart';
import 'package:golden_matrix/src/core/markdown_template.dart';
import 'package:golden_matrix/src/core/report_format.dart';
import 'package:golden_matrix/src/core/slug.dart';
import 'package:golden_matrix/src/core/warn.dart';
import 'package:golden_matrix/src/models/matrix_result.dart';

/// Writes [MatrixResult] as JSON and HTML report files.
///
/// Reports are written to the golden files root directory. By default
/// this is `goldens/` but can be overridden with [outputDir].
///
/// The HTML report uses golden paths as-is from [MatrixCombinationResult],
/// so it should be opened from the same working directory where tests run.
class MatrixReportWriter {
  /// Writes every format in [formats], and nothing else.
  ///
  /// The single place that maps [MatrixReportFormat] values onto writers. The
  /// runners used to carry a copy of this dispatch each, which is how the
  /// markdown report ended up linking to an HTML file nobody had asked for.
  static Future<void> writeAll(
    MatrixResult result, {
    required Set<MatrixReportFormat> formats,
    String? outputDir,
  }) async {
    if (formats.contains(MatrixReportFormat.json)) {
      await write(result, outputDir: outputDir);
    }
    if (formats.contains(MatrixReportFormat.html)) {
      await writeHtml(result, outputDir: outputDir);
    }
    if (formats.contains(MatrixReportFormat.markdown)) {
      await writeMarkdown(result, outputDir: outputDir, formats: formats);
    }
    if (formats.contains(MatrixReportFormat.junit)) {
      await writeJunit(result, outputDir: outputDir);
    }
  }

  /// The file name a report of [format] gets for a run called [runName].
  ///
  /// One place, so the extension per format is not spelled out in four
  /// near-identical writers. The base name is `slugify(runName)`, which
  /// collapses every non-alphanumeric run to `_` — see [claimReportName] for
  /// what that means when two runs share a slug.
  static String reportFileName(String runName, MatrixReportFormat format) =>
      '${_slug(runName)}_report${_extension(format)}';

  static String _extension(MatrixReportFormat format) => switch (format) {
        MatrixReportFormat.json => '.json',
        MatrixReportFormat.html => '.html',
        MatrixReportFormat.markdown => '.md',
        MatrixReportFormat.junit => '.xml',
      };

  static final Map<String, List<String>> _reportNameClaims = {};

  /// Registers [runName] as the owner of its report file names, warning when a
  /// differently-named run has already claimed the same ones.
  ///
  /// `slugify` maps every non-alphanumeric character to `_`, so
  /// `matrixGolden: A/B` and `matrixGolden: A B` produce one set of report
  /// files. Nothing used to notice: whichever run's teardown ran last silently
  /// overwrote the other's report, and the missing one looked like a run that
  /// had never happened.
  ///
  /// Called at declaration time by the report pipeline so the warning lands
  /// next to the offending call site rather than after the whole suite. Warning
  /// rather than throwing, because a name collision is not a reason to fail a
  /// suite that is otherwise passing — the strict version belongs in a major.
  static void claimReportName(String runName) {
    final base = _slug(runName);
    final claimed = _reportNameClaims.putIfAbsent(base, () => <String>[]);
    if (claimed.contains(runName)) return;
    final first = claimed.isEmpty ? null : claimed.first;
    claimed.add(runName);
    if (first == null) return;
    warnGoldenMatrix(
      'report files ${base}_report.* are claimed by two different runs: '
      '"$first" and "$runName". Whichever finishes last overwrites the other — '
      'rename one of them, or give it its own reportDir.',
    );
  }

  /// Forgets every claim made through [claimReportName].
  ///
  /// The registry is process-wide, which is what makes cross-file collisions
  /// visible at all; tests that assert on the warning need to reset it.
  static void resetReportNameClaims() => _reportNameClaims.clear();

  /// Writes the report as a JSON file.
  static Future<void> write(MatrixResult result, {String? outputDir}) async {
    final dir = outputDir ?? _findGoldensDir(result);
    final json = const JsonEncoder.withIndent('  ').convert(result.toJson());
    final file = File(joinPath(dir, reportFileName(result.name, MatrixReportFormat.json)));
    await file.parent.create(recursive: true);
    await file.writeAsString(json);
  }

  /// Writes the report as a self-contained HTML file.
  static Future<void> writeHtml(MatrixResult result, {String? outputDir}) async {
    final dir = outputDir ?? _findGoldensDir(result);
    final html = HtmlTemplate.render(result);
    final file = File(joinPath(dir, reportFileName(result.name, MatrixReportFormat.html)));
    await file.parent.create(recursive: true);
    await file.writeAsString(html);
  }

  /// Writes the report as a Markdown summary file suitable for CI step
  /// summaries (e.g. GitHub Actions `$GITHUB_STEP_SUMMARY`), PR comment
  /// bots, and Slack notifications.
  static Future<void> writeMarkdown(
    MatrixResult result, {
    String? outputDir,
    Set<MatrixReportFormat> formats = const {MatrixReportFormat.html},
  }) async {
    final dir = outputDir ?? _findGoldensDir(result);
    final md = MarkdownTemplate.render(result, formats: formats);
    final file = File(joinPath(dir, reportFileName(result.name, MatrixReportFormat.markdown)));
    await file.parent.create(recursive: true);
    await file.writeAsString(md);
  }

  /// Writes the report as a JUnit XML file consumed natively by GitHub
  /// Actions, GitLab CI, CircleCI, Jenkins, Buildkite, and most CI
  /// dashboards. Each matrix combination becomes a `<testcase>` element.
  static Future<void> writeJunit(MatrixResult result, {String? outputDir}) async {
    final dir = outputDir ?? _findGoldensDir(result);
    final xml = JunitTemplate.render(result);
    final file = File(joinPath(dir, reportFileName(result.name, MatrixReportFormat.junit)));
    await file.parent.create(recursive: true);
    await file.writeAsString(xml);
  }

  /// Fallback resolver for the goldens directory when no [outputDir] is given.
  ///
  /// The API layer normally passes an explicit `outputDir` derived from the
  /// golden comparator's `basedir` (the authoritative location next to the
  /// golden PNGs). This heuristic only runs when that resolution is
  /// unavailable — e.g. a non-`LocalFileComparator` — and guesses the path by
  /// probing a few common test-directory prefixes for the first golden file.
  static String _findGoldensDir(MatrixResult result) {
    if (result.results.isEmpty) return 'goldens';

    final goldenPath = result.results.first.goldenPath;
    // Try to find the file as-is first
    if (File(goldenPath).existsSync()) {
      // goldenPath is e.g. "goldens/default/file.png" → dir is "goldens"
      return goldenPath.split('/').first;
    }

    // Search common test directories
    for (final prefix in ['test/', 'test/golden/', 'test/goldens/']) {
      if (File('$prefix$goldenPath').existsSync()) {
        return '$prefix${goldenPath.split('/').first}';
      }
    }

    return 'goldens';
  }

  static String _slug(String name) => slugify(name);
}
