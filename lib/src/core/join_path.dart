import 'dart:io';

/// Joins [base] and [leaf] with the platform's path separator, without
/// doubling one [base] already ends with.
///
/// The report writer used to glue its output paths with a literal `'$dir/…'`
/// while the runner's own path handling went through [Platform.pathSeparator].
/// Two conventions in one package is how a Windows path ends up as
/// `C:\project\goldens/report.json`, and how a caller-supplied directory with a
/// trailing separator ends up as `goldens//report.json`.
String joinPath(String base, String leaf) {
  final sep = Platform.pathSeparator;
  final trimmed = base.endsWith(sep) ? base.substring(0, base.length - sep.length) : base;
  return '$trimmed$sep$leaf';
}
