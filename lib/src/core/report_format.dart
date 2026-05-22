/// Output formats produced by the matrix golden runner after a test run.
///
/// Pass a subset to `matrixGolden` / `screenMatrixGolden` via the
/// `reportFormats` parameter to control which report files are written
/// alongside golden images. The default — all three — matches the
/// historical behaviour of `report: true`.
enum MatrixReportFormat {
  /// Structured JSON report (`<slug>_report.json`) for downstream tooling.
  json,

  /// Self-contained HTML report (`<slug>_report.html`) with thumbnails,
  /// filters, and inline diff thumbnails for failed combinations.
  html,

  /// Markdown summary (`<slug>_report.md`) suitable for CI step summaries,
  /// PR comment bots, and Slack notifications.
  markdown,
}

/// Default `reportFormats` value — all three formats written.
const defaultReportFormats = <MatrixReportFormat>{
  MatrixReportFormat.json,
  MatrixReportFormat.html,
  MatrixReportFormat.markdown,
};

/// Resolves the effective set of report formats from the new
/// [reportFormats] parameter and the legacy [report] boolean.
///
/// Compatibility rule (verified by `report_formats_test.dart`):
/// - `report == null`  → honour [reportFormats] as given (default or user-specified)
/// - `report == true`  → all three formats (legacy "report everything" behaviour)
/// - `report == false` → empty set (legacy "report nothing" behaviour)
///
/// The legacy [report] parameter overrides [reportFormats] when both are
/// supplied, matching the principle of least surprise for code that was
/// passing `report: false` before 0.16.0.
Set<MatrixReportFormat> resolveReportFormats({
  required Set<MatrixReportFormat> reportFormats,
  required bool? report,
}) {
  if (report == null) return reportFormats;
  return report ? defaultReportFormats : const <MatrixReportFormat>{};
}
