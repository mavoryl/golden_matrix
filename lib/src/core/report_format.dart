/// Output formats produced by the matrix golden runner after a test run.
///
/// Pass a subset to `matrixGolden` / `screenMatrixGolden` via the
/// `reportFormats` parameter to control which report files are written
/// alongside golden images. Since 1.3.0 reports are **opt-in**: the
/// parameter defaults to `const {}` and nothing is written unless you
/// ask for it. [defaultReportFormats] is the ready-made JSON + HTML +
/// Markdown bundle for callers who want all of the usual ones.
enum MatrixReportFormat {
  /// Structured JSON report (`<slug>_report.json`) for downstream tooling.
  json,

  /// Self-contained HTML report (`<slug>_report.html`) with thumbnails,
  /// filters, and inline diff thumbnails for failed combinations.
  html,

  /// Markdown summary (`<slug>_report.md`) suitable for CI step summaries,
  /// PR comment bots, and Slack notifications.
  markdown,

  /// JUnit XML report (`<slug>_report.xml`) consumed natively by GitHub
  /// Actions, GitLab CI, CircleCI, Jenkins, Buildkite, and most CI
  /// dashboards. Surfaces matrix combinations as test cases in the
  /// CI's native test-results UI.
  junit,
}

/// Ready-made `reportFormats` bundle — JSON + HTML + Markdown.
///
/// **This is no longer the default.** Up to 1.2.0 it was; since 1.3.0 the
/// `reportFormats` parameter defaults to `const {}` and writes nothing.
/// Pass this constant to get the three usual reports back:
///
/// ```dart
/// matrixGolden('Button', scenarios: [...], reportFormats: defaultReportFormats);
/// ```
///
/// JUnit XML is not included (set `reportFormats: { ..., MatrixReportFormat.junit }`)
/// because most local dev workflows don't need it.
const defaultReportFormats = <MatrixReportFormat>{
  MatrixReportFormat.json,
  MatrixReportFormat.html,
  MatrixReportFormat.markdown,
};
