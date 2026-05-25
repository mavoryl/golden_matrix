import '../models/matrix_result.dart';

/// Renders a [MatrixResult] as JUnit XML — the de-facto industry-standard
/// test-report format consumed natively by GitHub Actions, GitLab CI,
/// CircleCI, Jenkins, Buildkite, Azure DevOps, and most reporter tools.
///
/// Output structure follows the Apache Ant XSD plus the pytest/testmoapp
/// convention: `<testsuites>` wrapping per-scenario `<testsuite>`s, with
/// one `<testcase>` per matrix combination. Failed combinations emit a
/// `<failure>` child with the captured error message; skipped ones emit
/// a self-closing `<skipped/>` tag.
class JunitTemplate {
  /// Renders [result] as a JUnit XML document string.
  static String render(MatrixResult result) {
    final byScenario = <String, List<MatrixCombinationResult>>{};
    for (final r in result.results) {
      (byScenario[r.combination.scenario.name] ??= []).add(r);
    }

    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.write('<testsuites');
    _attr(buf, 'name', result.name);
    _attr(buf, 'tests', result.total.toString());
    _attr(buf, 'failures', result.failed.toString());
    _attr(buf, 'errors', '0');
    _attr(buf, 'skipped', result.skipped.toString());
    _attr(buf, 'time', _seconds(result.duration));
    _attr(buf, 'timestamp', result.timestamp.toUtc().toIso8601String());
    buf.writeln('>');

    for (final entry in byScenario.entries) {
      _writeSuite(buf, entry.key, entry.value, result.name);
    }

    buf.writeln('</testsuites>');
    return buf.toString();
  }

  static void _writeSuite(
    StringBuffer buf,
    String scenarioName,
    List<MatrixCombinationResult> results,
    String runName,
  ) {
    final failures = results.where((r) => r.status == MatrixResultStatus.failed).length;
    final skipped = results.where((r) => r.status == MatrixResultStatus.skipped).length;

    buf.write('  <testsuite');
    _attr(buf, 'name', scenarioName);
    _attr(buf, 'tests', results.length.toString());
    _attr(buf, 'failures', failures.toString());
    _attr(buf, 'errors', '0');
    _attr(buf, 'skipped', skipped.toString());
    buf.writeln('>');

    for (final r in results) {
      _writeCase(buf, r, runName, scenarioName);
    }

    buf.writeln('  </testsuite>');
  }

  static void _writeCase(
    StringBuffer buf,
    MatrixCombinationResult r,
    String runName,
    String scenarioName,
  ) {
    final c = r.combination;
    final dir = c.direction.toString() == 'TextDirection.ltr' ? 'ltr' : 'rtl';
    final scale = c.textScale % 1 == 0 ? '${c.textScale.toInt()}x' : '${c.textScale}x';
    final caseName = '${c.theme.name} ${c.locale.toLanguageTag()} $dir $scale ${c.device.name}';
    final className = '$runName.$scenarioName';

    buf.write('    <testcase');
    _attr(buf, 'classname', className);
    _attr(buf, 'name', caseName);
    _attr(buf, 'time', '0');

    switch (r.status) {
      case MatrixResultStatus.passed:
        buf.writeln('/>');
        return;
      case MatrixResultStatus.failed:
        buf.writeln('>');
        final msg = r.errorMessage ?? 'failed';
        final firstLine = msg.split('\n').first.trim();
        buf.write('      <failure');
        _attr(buf, 'type', 'PixelMismatch');
        _attr(buf, 'message', firstLine);
        buf.writeln('>');
        buf.writeln(_escText(msg));
        buf.writeln('      </failure>');
        buf.writeln('    </testcase>');
        return;
      case MatrixResultStatus.skipped:
        buf.writeln('>');
        buf.writeln('      <skipped/>');
        buf.writeln('    </testcase>');
        return;
    }
  }

  /// Append ` name="value"` with attribute-context XML escaping.
  static void _attr(StringBuffer buf, String name, String value) {
    buf.write(' $name="${_escAttr(value)}"');
  }

  static String _escAttr(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll('\n', '&#10;')
      .replaceAll('\r', '');

  static String _escText(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  static String _seconds(Duration d) {
    final ms = d.inMilliseconds;
    return (ms / 1000).toStringAsFixed(3);
  }
}
