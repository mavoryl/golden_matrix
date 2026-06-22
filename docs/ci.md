# CI integration

Wire matrix golden runs into your pipeline: surface results as step summaries, JUnit checks, and stale-golden warnings.

Reports are written next to your goldens after every run. Pick the formats that match your pipeline — JSON, HTML, Markdown, and JUnit XML are all toggleable per call. For full format details see [Reports](reports.md).

## GitHub Actions step summary (Markdown)

Each run writes a `<slug>_report.md` next to the JSON and HTML reports — a summary list, a failure table, a stale-goldens list, and a link to the HTML. Pipe every Markdown report into the GitHub Actions step summary:

```yaml
- name: golden matrix step summary
  if: always()
  run: |
    for f in $(find test -name '*_report.md' 2>/dev/null); do
      cat "$f" >> "$GITHUB_STEP_SUMMARY"
      echo >> "$GITHUB_STEP_SUMMARY"
    done
```

The same file works for PR-comment bots, Slack/Discord notifiers, or any tool that takes Markdown.

## JUnit XML for CI dashboards

Opt in with `MatrixReportFormat.junit` to get a `<slug>_report.xml` next to the other reports. Each scenario becomes a `<testsuite>`, each combination a `<testcase>`; failures land as `<failure>` with the captured error message.

```dart
matrixGolden(
  'ProfileCard',
  scenarios: [...],
  reportFormats: const {
    MatrixReportFormat.html,
    MatrixReportFormat.markdown,
    MatrixReportFormat.junit, // ← opt-in
  },
);
```

Publish the XML with one extra workflow step:

```yaml
- name: publish JUnit test results
  if: always()
  uses: dorny/test-reporter@v1
  with:
    name: Golden Matrix
    path: '**/test/golden/goldens/*_report.xml'
    reporter: java-junit
    fail-on-error: false
```

The job needs:

```yaml
permissions:
  checks: write
  contents: read
```

for the action to create the check run.

Result in the GitHub UI: a "Golden Matrix" check that lists every test → scenario → combination as a tree, with failures annotated next to the changed code in PR diffs.

## Multi-module / monorepo

Each `matrixGolden` call produces one XML in the calling test's golden directory. In a melos / multi-package monorepo the files scatter across `packages/*/test/golden/goldens/`. Aggregate them in a single CI step via path glob:

```yaml
- uses: dorny/test-reporter@v1
  with:
    name: Golden Matrix (all modules)
    path: 'packages/**/test/golden/goldens/*_report.xml'
    reporter: java-junit
```

The result is one tree grouped by `matrixGolden` test name. To avoid two modules colliding on the same test name in the tree, prefix the test name with the module:

```dart
// packages/feature_wallet/test/...
matrixGolden('wallet/Button', scenarios: [...]);

// packages/feature_marketing/test/...
matrixGolden('marketing/Button', scenarios: [...]);
```

Per-test stale-golden detection (enabled by default) catches scenario-level orphans inside each module automatically — no extra setup.

## `isCiEnvironment` helper

Switch report formats based on where the test runs — step summary in CI, visual review locally:

```dart
matrixGolden(
  'ProfileCard',
  scenarios: [...],
  reportFormats: isCiEnvironment
      ? const {MatrixReportFormat.markdown} // CI: only step summary
      : const {MatrixReportFormat.html},    // local: visual review
);
```

Detection is best-effort and recognises `CI=true|1` (GitHub Actions, GitLab CI, CircleCI, Travis, Buildkite, Drone, Netlify) plus vendor env-vars: `GITHUB_ACTIONS`, `GITLAB_CI`, `CIRCLECI`, `BUILDKITE`, `TF_BUILD` (Azure Pipelines), `BITBUCKET_COMMIT`, `CM_BUILD_ID` (Codemagic), `JENKINS_URL`, `TEAMCITY_VERSION`, `bamboo_planKey`. Force-enable on any other CI by setting `CI=true` in your pipeline.

## Stale-golden detection in CI

Per-test stale-golden detection runs automatically and catches files in a test's subdir that weren't produced by any combination — for example, a scenario was renamed and the old PNGs were left behind. See [Reports](reports.md) for the detection concept.

When reports are enabled (default), stale paths appear in the JSON/HTML/Markdown/JUnit output. When you've disabled reports with `reportFormats: const {}`, stale files are printed to the console:

```
golden_matrix: screenMatrixGolden: dialog has 2 stale golden file(s):
  - goldens/dialog/old_scenario/dark_en_ltr_1x_phonesmall.png
  - goldens/dialog/old_scenario/light_en_ltr_1x_phonesmall.png
```

Opt out per test with `detectStaleGoldens: false` if you have an intentional reason for extra files in the subdir.

## See also

- [Reports](reports.md) — JSON / HTML / Markdown / JUnit format details and the stale-detection concept
- [Sampling](sampling.md) — trim large matrices before they hit CI
- [Devices](devices.md) — device presets and pixel ratios
- [Advanced](advanced.md) — wrappers, decorators, post-pump state
- [Migration guide](migration.md) — upgrading across versions
- [Home](index.md)
