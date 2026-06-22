# Reports

Every matrix run emits report artifacts alongside the golden PNGs — JSON, HTML, a Markdown summary, and (opt-in) JUnit XML — plus overflow and stale-golden diagnostics baked into each.

See also: [Sampling](sampling.md) · [Devices](devices.md) · [CI integration](ci.md) · [Advanced](advanced.md) · [Migration guide](migration.md) · [Home](index.md)

## Report formats

By default each `matrixGolden` / `screenMatrixGolden` run writes JSON + HTML + Markdown reports into the test's golden directory. JUnit XML is opt-in.

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

Opt in with `MatrixReportFormat.junit` to get a `<slug>_report.xml` next to the other reports. The XML follows the de-facto JUnit schema consumed natively by GitHub Actions, GitLab CI, CircleCI, Jenkins, Buildkite, and Azure DevOps test dashboards. Each scenario becomes a `<testsuite>`, each combination a `<testcase>`; failures land as `<failure>` with the captured error message.

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

`reportFormats: const {}` disables reports entirely.

!!! note "Deprecated `report: bool`"
    The legacy `report: bool` parameter still works for backward compatibility but emits a deprecation warning. `reportFormats: const {}` replaces `report: false`. When both are passed, `report:` wins.

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
