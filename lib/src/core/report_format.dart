/// Output formats produced by the matrix golden runner after a test run.
///
/// Pass a subset to `matrixGolden` / `screenMatrixGolden` via the
/// `reportFormats` parameter to control which report files are written
/// alongside golden images. The default ([defaultReportFormats]) writes
/// JSON + HTML + Markdown; pass `const {}` to disable reports entirely.
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

/// Default `reportFormats` value — JSON + HTML + Markdown.
///
/// JUnit XML is opt-in (set `reportFormats: { ..., MatrixReportFormat.junit }`)
/// because most local dev workflows don't need it.
const defaultReportFormats = <MatrixReportFormat>{
  MatrixReportFormat.json,
  MatrixReportFormat.html,
  MatrixReportFormat.markdown,
};
