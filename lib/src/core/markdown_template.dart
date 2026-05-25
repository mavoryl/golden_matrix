import 'package:flutter/widgets.dart';

import '../models/matrix_result.dart';
import 'slug.dart';

/// Renders a [MatrixResult] as a Markdown document suitable for
/// CI step summaries (e.g. GitHub Actions `$GITHUB_STEP_SUMMARY`),
/// PR comment bots, and Slack notifications.
///
/// Structure:
/// - `# <test name>` H1
/// - `## Summary` bullet list with counts + duration
/// - `## Failed` table when there are failures
/// - `## Stale goldens` bullet list when non-empty
/// - Trailing link to the sibling HTML report
class MarkdownTemplate {
  /// Renders [result] as a GitHub-Flavored Markdown report.
  static String render(MatrixResult result) {
    final buf = StringBuffer();
    _writeHeader(buf, result);
    _writeSummary(buf, result);
    _writeFailed(buf, result);
    _writeStale(buf, result);
    _writeHtmlLink(buf, result);
    return '${buf.toString().trimRight()}\n';
  }

  static void _writeHeader(StringBuffer buf, MatrixResult result) {
    buf.writeln('# ${result.name}');
    buf.writeln();
  }

  static void _writeSummary(StringBuffer buf, MatrixResult result) {
    buf.writeln('## Summary');
    buf.writeln();
    final duration = result.duration.inMilliseconds < 1000
        ? '${result.duration.inMilliseconds}ms'
        : '${result.duration.inSeconds}s';
    buf.writeln('- **Total:** ${result.total}');
    buf.writeln('- **Passed:** ${result.passed}');
    if (result.failed > 0) buf.writeln('- **Failed:** ${result.failed}');
    if (result.skipped > 0) buf.writeln('- **Skipped:** ${result.skipped}');
    if (result.warningCount > 0) buf.writeln('- **Warnings:** ${result.warningCount}');
    if (result.staleGoldens.isNotEmpty) {
      buf.writeln('- **Stale goldens:** ${result.staleGoldens.length}');
    }
    buf.writeln('- **Duration:** $duration');
    buf.writeln();
  }

  static void _writeFailed(StringBuffer buf, MatrixResult result) {
    final failed = result.results.where((r) => r.status == MatrixResultStatus.failed).toList();
    if (failed.isEmpty) return;

    buf.writeln('## Failed');
    buf.writeln();
    buf.writeln('| Scenario | Theme | Locale | Dir | Scale | Device | Error |');
    buf.writeln('|---|---|---|---|---|---|---|');
    for (final f in failed) {
      final c = f.combination;
      final dir = c.direction == TextDirection.ltr ? 'ltr' : 'rtl';
      final scale = c.textScale % 1 == 0 ? '${c.textScale.toInt()}x' : '${c.textScale}x';
      final error = _excerpt(f.errorMessage);
      buf.writeln(
        '| ${_mdCell(c.scenario.name)} '
        '| ${_mdCell(c.theme.name)} '
        '| ${_mdCell(c.locale.toLanguageTag())} '
        '| $dir '
        '| $scale '
        '| ${_mdCell(c.device.name)} '
        '| ${_mdCell(error)} |',
      );
    }
    buf.writeln();
  }

  static void _writeStale(StringBuffer buf, MatrixResult result) {
    if (result.staleGoldens.isEmpty) return;
    buf.writeln('## Stale goldens');
    buf.writeln();
    buf.writeln(
      'Orphan PNGs in this test\'s golden subdirectory that no '
      'combination produced. Safe to delete or regenerate.',
    );
    buf.writeln();
    for (final path in result.staleGoldens) {
      buf.writeln('- `$path`');
    }
    buf.writeln();
  }

  static void _writeHtmlLink(StringBuffer buf, MatrixResult result) {
    final htmlName = '${slugify(result.name)}_report.html';
    buf.writeln('[View HTML report]($htmlName)');
  }

  /// Truncate a long error message to keep the markdown table readable.
  /// Pipe escaping is left to `_mdCell` so escapes aren't doubled.
  static String _excerpt(String? message, {int max = 120}) {
    if (message == null || message.isEmpty) return '';
    final flat = message.replaceAll('\n', ' ').trim();
    if (flat.length <= max) return flat;
    return '${flat.substring(0, max - 1)}…';
  }

  /// Escape `|` and newlines in a markdown table cell.
  static String _mdCell(String value) {
    return value.replaceAll('|', '\\|').replaceAll('\n', ' ');
  }
}
