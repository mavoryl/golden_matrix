# Reports

A matrix run can emit report artifacts alongside the golden PNGs — JSON, HTML, a Markdown summary, and JUnit XML — plus overflow and stale-golden diagnostics baked into each. Since 1.3.0 all of them are **opt-in**: pass `reportFormats`.

See also: [Sampling](sampling.md) · [Devices](devices.md) · [CI integration](ci.md) · [Advanced](advanced.md) · [Migration guide](migration.md) · [Home](index.md)

## Report formats

By default (`reportFormats: const {}`) a run writes **no** reports. Ask for them explicitly:

```dart
matrixGolden(
  'ProfileCard',
  scenarios: [...],
  reportFormats: defaultReportFormats, // JSON + HTML + Markdown
);
```

`defaultReportFormats` is the ready-made JSON + HTML + Markdown bundle (the pre-1.3.0 default); JUnit XML is never in it. Reports land in the test's golden directory.

| Format | File | Contents |
| --- | --- | --- |
| JSON | `<slug>_report.json` | Machine-readable run data; gains a `staleGoldens` field and overflow warnings. |
| HTML | `<slug>_report.html` | Self-contained visual report with thumbnails, filters, dark mode, inline diff tiles. |
| Markdown | `<slug>_report.md` | Summary list, failed table, stale list, link to HTML. |
| JUnit XML | `<slug>_report.xml` | De-facto JUnit schema for CI test dashboards. |

### HTML report

Self-contained HTML generated alongside the golden files:

- Summary with pass / fail / warning / stale counts
- Scenario grouping with collapsible sections
- Thumbnail grid with clickable full-size images
- Filter by scenario, theme, or status
- Dark mode via `prefers-color-scheme`
- **Diff thumbnails on failure** — each failed combination shows a 4-tile inline grid (expected · actual · diff · masked) pulled from Flutter's own `failures/` outputs. No extra setup, no flag.

### Markdown summary

Each run writes a `<slug>_report.md` next to the JSON and HTML reports. It contains a summary list, a `## Failed` table (when any), a `## Stale goldens` list (when any), and a link to the HTML.

Drop-in for a GitHub Actions step summary, PR-comment bots, or Slack/Discord notifiers — anything that takes Markdown. For the workflow recipe, see [CI integration](ci.md).

### JUnit XML

Add `MatrixReportFormat.junit` to get a `<slug>_report.xml` next to the other reports. The XML follows the de-facto JUnit schema consumed natively by GitHub Actions, GitLab CI, CircleCI, Jenkins, Buildkite, and Azure DevOps test dashboards. Each scenario becomes a `<testsuite>`, each combination a `<testcase>`; failures land as `<failure>` with the captured error message.

The `<failure type>` says which phase broke, so a dashboard does not blame the pixels for a layout error:

| Phase | `type` | What threw |
| --- | --- | --- |
| `build` | `BuildError` | The scenario's widget builder |
| `pump` | `PumpError` | `pumpWidget` / `pumpAndSettle` — layout errors, settle timeouts |
| `setup` | `SetupError` | The `setup:` callback or the settle after it |
| `comparison` | `GoldenMismatch` | The golden comparison itself |
| unclassified | `Failure` | Recorded without a phase |

The same value appears as `"phase"` in the JSON report for failed combinations, and as `MatrixCombinationResult.failurePhase` if you consume results programmatically.

### Timings

Every report carries three numbers, and as of 1.6.0 all three are measured:

| Field | Where | What it is |
| --- | --- | --- |
| `timestamp` | JSON, JUnit `<testsuites timestamp>`, HTML header | When the run's first test started |
| `durationMs` / `time` | JSON, JUnit `<testsuites time>` | Wall-clock from the first test to the last teardown |
| `durationMs` per result / `<testcase time>` | JSON results, JUnit | Wall-clock of one combination: build, pump, setup, comparison |

Before 1.6.0 the run clock started when the runner was *declared*, so it
included the execution of every group declared above it in the same file;
`timestamp` was stamped at the end of the run despite being documented as its
start; and every `<testcase>` reported `time="0"`. Skipped combinations report
`0`, because they never ran.

### One report per run name

Report file names come from `slugify(runName)`, which collapses every
non-alphanumeric run to `_`. Two runs called `A/B` and `A B` therefore claim the
same files, and whichever finishes last overwrites the other. Since 1.6.0 the
second one says so at declaration time:

```
golden_matrix: report files matrixgolden__a_b_report.* are claimed by two
different runs: "matrixGolden: A/B" and "matrixGolden: A B". Whichever finishes
last overwrites the other — rename one of them, or give it its own reportDir.
```

## Choosing formats per run

Use `reportFormats` to write only what your pipeline needs:

```dart
matrixGolden(
  'ProfileCard',
  scenarios: [...],
  reportFormats: const {MatrixReportFormat.markdown}, // step summary only
);
```

Combine formats freely:

```dart
matrixGolden(
  'ProfileCard',
  scenarios: [...],
  reportFormats: const {
    MatrixReportFormat.html,
    MatrixReportFormat.markdown,
    MatrixReportFormat.junit, // opt-in
  },
);
```

`reportFormats: const {}` — the default — disables reports entirely.

!!! note "Removed `report: bool`"
    The legacy `report: bool` parameter was removed in 1.3.0. `reportFormats: defaultReportFormats` replaces `report: true`, and reports are opt-in since that release — the default writes nothing.

## Overflow detection

golden_matrix automatically captures `RenderFlex overflow` and layout errors during rendering. Warnings appear in the JSON and HTML reports with orange badges — no configuration needed.

## Stale golden detection

After each run, the runner walks the test's golden subdirectory and reports any `*.png` files that no combination produced — orphans left behind by renamed scenarios, dropped axis values, or removed `matrixGolden` calls.

```
matrixGolden: SampleButton
  48 total | 48 passed | 1 stale (1.0s)
  Stale (orphan goldens — not produced by any combination):
    - goldens/samplebutton/old_scenario/light_en_ltr_1x_phonesmall.png
```

JSON reports gain a `staleGoldens` field; HTML reports get a `Stale` stat card and a collapsible list. Flutter's own `failures/` diff images are excluded.

Detection is **on by default**. Opt out per call:

```dart
matrixGolden(
  'Widget',
  scenarios: [...],
  axes: axes,
  detectStaleGoldens: false, // turn off for this test
);
```

It is automatically skipped when `fileNameBuilder` is supplied — the default subdir assumption no longer holds. The runner **never deletes files**; you decide what to do with the list (`git rm`, or regenerate via `flutter test --update-goldens`).

For CI-mode console output when reports are disabled, see [CI integration](ci.md).

## Golden file structure

```
goldens/
  mybutton/
    default/
      light_en_ltr_1x_phonesmall.png
      dark_ar_rtl_2x_phonelarge.png
    disabled/
      light_en_ltr_1x_phonesmall.png
```

Naming: `goldens/<test>/<scenario>/<theme>_<locale>_<direction>_<textScale>_<device>.png`

The `<test>` prefix prevents collisions when two `matrixGolden` calls use scenarios with the same name.

## Live example

Browse generated reports and golden files in the repository: <https://github.com/mavoryl/golden_matrix/tree/main/example/test/golden/goldens>
