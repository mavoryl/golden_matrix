import 'dart:convert';
import 'dart:io';

import '../models/matrix_result.dart';
import 'html_template.dart';
import 'junit_template.dart';
import 'markdown_template.dart';
import 'slug.dart';

/// Writes [MatrixResult] as JSON and HTML report files.
///
/// Reports are written to the golden files root directory. By default
/// this is `goldens/` but can be overridden with [outputDir].
///
/// The HTML report uses golden paths as-is from [MatrixCombinationResult],
/// so it should be opened from the same working directory where tests run.
class MatrixReportWriter {
  /// Writes the report as a JSON file.
  static Future<void> write(MatrixResult result, {String? outputDir}) async {
    final dir = outputDir ?? _findGoldensDir(result);
    final json = const JsonEncoder.withIndent('  ').convert(result.toJson());
    final file = File('$dir/${_slug(result.name)}_report.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(json);
  }

  /// Writes the report as a self-contained HTML file.
  static Future<void> writeHtml(MatrixResult result, {String? outputDir}) async {
    final dir = outputDir ?? _findGoldensDir(result);
    final html = HtmlTemplate.render(result);
    final file = File('$dir/${_slug(result.name)}_report.html');
    await file.parent.create(recursive: true);
    await file.writeAsString(html);
  }

  /// Writes the report as a Markdown summary file suitable for CI step
  /// summaries (e.g. GitHub Actions `$GITHUB_STEP_SUMMARY`), PR comment
  /// bots, and Slack notifications.
  static Future<void> writeMarkdown(MatrixResult result, {String? outputDir}) async {
    final dir = outputDir ?? _findGoldensDir(result);
    final md = MarkdownTemplate.render(result);
    final file = File('$dir/${_slug(result.name)}_report.md');
    await file.parent.create(recursive: true);
    await file.writeAsString(md);
  }

  /// Writes the report as a JUnit XML file consumed natively by GitHub
  /// Actions, GitLab CI, CircleCI, Jenkins, Buildkite, and most CI
  /// dashboards. Each matrix combination becomes a `<testcase>` element.
  static Future<void> writeJunit(MatrixResult result, {String? outputDir}) async {
    final dir = outputDir ?? _findGoldensDir(result);
    final xml = JunitTemplate.render(result);
    final file = File('$dir/${_slug(result.name)}_report.xml');
    await file.parent.create(recursive: true);
    await file.writeAsString(xml);
  }

  /// Finds the actual goldens directory by scanning for existing golden files.
  ///
  /// Golden files are written by flutter test relative to the test file,
  /// but ReportWriter runs from the package root. This method searches
  /// for the first golden file on disk to determine the correct path.
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
