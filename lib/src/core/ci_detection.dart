import 'dart:io';

import 'package:flutter/foundation.dart';

/// `true` when the current process appears to be running under a
/// continuous integration service.
///
/// Detection is best-effort and uses two layers:
///
/// 1. The vendor-neutral `CI` environment variable, set to `'true'` or
///    `'1'` by most modern CI services — GitHub Actions, GitLab CI,
///    CircleCI, Travis, Buildkite, Drone, Netlify.
/// 2. Vendor-specific environment variables for CI services that don't
///    set `CI` by default: Bitbucket Pipelines, Codemagic, Jenkins,
///    TeamCity, Azure Pipelines, Bamboo.
///
/// Users on any CI not in the list above can force the helper to return
/// `true` by setting `CI=true` in their pipeline configuration.
///
/// Typical usage in test config or test files:
///
/// ```dart
/// matrixGolden(
///   'ProfileCard',
///   scenarios: [...],
///   reportFormats: isCiEnvironment
///       ? const {MatrixReportFormat.markdown}
///       : const {MatrixReportFormat.html},
/// );
/// ```
bool get isCiEnvironment => isCiFromEnv(Platform.environment);

/// Pure detection used by [isCiEnvironment]. Exposed for unit testing
/// with crafted env maps; production code should call [isCiEnvironment].
///
/// Detection layers (any match → CI):
///
/// 1. Vendor-neutral `CI=true|1` (GitHub Actions, GitLab CI, CircleCI,
///    Travis, Buildkite, Drone, Netlify default behaviour).
/// 2. Vendor-specific env var presence — covers cases where users
///    intentionally unset `CI` or vendors that don't set it by default.
@visibleForTesting
bool isCiFromEnv(Map<String, String> env) {
  final ci = env['CI'];
  if (ci == 'true' || ci == '1') return true;

  const vendorKeys = [
    'GITHUB_ACTIONS', // GitHub Actions
    'GITLAB_CI', // GitLab CI
    'CIRCLECI', // CircleCI
    'BUILDKITE', // Buildkite
    'TF_BUILD', // Azure Pipelines
    'BITBUCKET_COMMIT', // Bitbucket Pipelines
    'CM_BUILD_ID', // Codemagic (Flutter-focused)
    'JENKINS_URL', // Jenkins
    'TEAMCITY_VERSION', // TeamCity
    'bamboo_planKey', // Bamboo
  ];
  return vendorKeys.any(env.containsKey);
}
