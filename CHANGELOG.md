## 1.6.0

Eight fixes to things the package reported or resolved incorrectly, plus three
new public symbols. Nothing is removed and no signature changes. One fix can
rename goldens: `ku` is now inferred LTR (see Fixed), so a matrix that tests it
needs `--update-goldens` once.

### Added

- **`MatrixAxes.directionResolver`** — replaces the built-in direction inference
  outright, for the custom subtags and app-flag-driven mirroring no table over
  locales can cover:

  ```dart
  TextDirection myDirection(Locale locale) =>
      locale.languageCode == 'xx' ? TextDirection.rtl : TextDirection.ltr;

  matrixGolden(
    'Button',
    scenarios: [...],
    axes: const MatrixAxes(
      locales: [Locale('en'), Locale('xx')],
      directionResolver: myDirection,   // a top-level fn keeps the axes const
    ),
  );
  ```

  An explicit `directions` list still wins: that axis enumerates both directions
  regardless of locale, which is a different question from "which way does this
  locale read".

- **`MatrixCombinationResult.duration`** — wall-clock time of one combination
  across build, pump, setup and comparison. Surfaces as `durationMs` in the JSON
  report and as the JUnit `<testcase time>`; `<testsuite time>` is the sum of its
  cases. Skipped combinations report zero, because they never ran.

- **`MatrixReportWriter.reportFileName`** — the report file name for a run name
  and format, in one place instead of an extension spelled out in four
  near-identical writers.

### Fixed

- **Run timings were fiction.** The stopwatch was opened in the runner body,
  which executes at test *declaration* time — before a single test has run, and
  before every group declared below it. A run's reported duration therefore
  included the execution of unrelated groups in the same file. `timestamp` had
  the mirror problem: stamped with `DateTime.now()` in `tearDownAll`, i.e. when
  the run *ended*, while its dartdoc promised "when the run started". Both now
  read one clock the run itself starts, from a `setUpAll` inside its own group.
  A run whose clock never started — no tests registered, or all of them skipped
  — reports no start rather than a fabricated one.

- **JUnit reported `time="0"` on every `<testcase>`.** No CI dashboard could
  rank slow combinations and no per-suite total added up. Timings are measured
  now (see `MatrixCombinationResult.duration` above).

- **Direction inference ignored `scriptCode` and knew seven languages.** Sindhi,
  Uyghur, Divehi, Sorani Kurdish, Syriac, N'Ko, Dari, Kashmiri and the rest of
  CLDR's right-to-left languages were laid out left to right — a mirrored
  screenshot that passed as correct, which is worse than a missing test. The
  script subtag is now checked first, so `az-Arab` is RTL because of its script
  and `ar-Latn` is LTR for the same reason.

  **`ku` changed direction.** It was hardcoded RTL, but Kurmanji Kurdish — what
  `ku` means in CLDR — is written in the Latin alphabet; the Arabic-script
  variant is `ckb`. If you test `ku`, its goldens are renamed from `_rtl_` to
  `_ltr_` and need `--update-goldens` once.

- **`loadAppFonts` could not find the SDK on Windows.** It shelled out to
  `which flutter`, which is not a command there, and derived the root by
  splitting on the literal `'/bin/flutter'` — POSIX separators and the POSIX
  launcher name both baked in. `PATH` is now walked directly: no subprocess,
  launcher names per platform (`flutter.bat` included), and the root taken as
  the parent of `bin/`. The failure was silent, because a missing font falls
  back to Ahem.

- **One odd `FontManifest.json` entry took down a whole test file.** The manifest
  was decoded straight into `Iterable<dynamic>` and each entry cast without
  isolation, so an unexpected shape threw out of `flutter_test_config.dart` — the
  exact failure mode the per-family registration isolation was written to
  prevent. Each entry is now isolated and a bad one is named and skipped; a
  manifest that is not a list at all is reported instead of thrown.

- **Two runs could silently overwrite each other's report.** Report file names
  come from `slugify(runName)`, which collapses every non-alphanumeric run to
  `_`, so `A/B` and `A B` claim the same files. The second run now says so at
  declaration time, naming both runs and the files they are fighting over. A
  warning rather than an error — the strict version belongs in a major.

- **Report paths used two conventions.** The writer glued output paths with a
  literal `'$dir/…'` while the runner used `Platform.pathSeparator`, so a
  Windows directory came out as `C:\project\goldens/report.json` and a
  `reportDir` ending in a separator produced `goldens//report.json`.

- **Font bytes were the whole buffer, not the bytes.** `ByteData.view(bytes.buffer)`
  ignores the list's offset and length, so a `Uint8List` that is a view into a
  larger buffer reached `FontLoader` with garbage glued to both ends.
  `readAsBytes` returns offset-0 lists today, which is why nothing caught fire.

### Internal

- `MatrixRunClock` replaces the raw `Stopwatch` in all three runners.
- `joinPath`, `warnGoldenMatrix` and the markup escapers each collapse two or
  three hand-written copies into one; the escapers stay one function per context
  (text content, HTML attribute, XML attribute) because the contexts genuinely
  differ and a single function with flags would be worse.
- `findFlutterRoot` takes its filesystem touches as parameters, all defaulting to
  the real thing, so the SDK lookup walk is coverable.

### Coming in 2.0

Advance notice, not a deprecation — these change behaviour rather than remove
symbols, so there is nothing to mark `@Deprecated`:

- **Golden file names change.** Locale segments will use
  `Locale.toLanguageTag()` and slugs will get a canonical escaping, which
  renames every existing golden. Colliding paths, warned about since 1.5.0, will
  be refused outright — as will colliding report names, warned about since
  1.6.0.
- **Model equality changes.** `MatrixDevice` and friends compare by name today;
  they will compare by identity or by full value.
- **The barrel narrows.** Test seams currently reachable through
  `package:golden_matrix/golden_matrix.dart` move to files it does not export.

## 1.5.0

Internal restructuring plus one behaviour fix and one new public class. No
signature is removed; the six shared parameters that used to have non-null
defaults are now nullable, which is source-compatible — `skip: true` and
`rules: [...]` compile exactly as before.

### Added

- **`MatrixRunConfig`** — the sixteen options every entry point shares, in one
  reusable, `const`-constructible object:

  ```dart
  const ciRun = MatrixRunConfig(
    axes: MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
    reportFormats: {MatrixReportFormat.json, MatrixReportFormat.junit},
    tolerance: 0.001,
    printSummary: false,
  );

  matrixGolden('PrimaryButton', scenarios: [...], config: ciRun);
  matrixGolden('Badge', scenarios: [...], config: ciRun, skip: true);
  ```

  An argument passed directly to the function always overrides the same field of
  the config — including when it repeats the parameter's own default, which is
  why those parameters are nullable now. Mode-specific options (`captureScale`,
  `pixelRatio`, `padding`, `extraLocalizationsDelegates`, `wrapChild`,
  `wrapApp`, `appBuilder`) stay on their own functions rather than becoming
  fields two of three entry points would ignore.

- **`previewMatrixGolden(component: true)`** — previews a `componentMatrixGolden`
  call: device segment dropped from paths, `devices` axis collapsed. Without it,
  a component run's path collisions were invisible, because the default scheme
  keeps the device that makes every path unique.

### Changed

- **All three runners now warn before they run.** A configuration that produces
  no combinations at all registers zero tests, which reads exactly like a
  passing run; two combinations claiming the same golden file mean the second
  overwrites the first, so the first is never really compared. Both were
  previously visible only through `previewMatrixGolden`. Both now print a
  warning while the tests are being registered.

### Fixed

- **`pixelRatio` no longer shrinks the component layout surface.**
  `tester.view.physicalSize` is in physical pixels, so a fixed 800×800 left the
  widget 400×400 logical points at `pixelRatio: 2.0` and ~267×267 at `3.0`. A
  parameter documented as capture density was deciding how much room the
  component had to lay itself out in, and anything wider was silently
  constrained. The surface is now 800×800 logical at every ratio.

  **Migration:** affects `componentMatrixGolden` only, and only where
  `pixelRatio != 1.0` left a component squeezed — those goldens need one
  `flutter test --update-goldens`. The default `1.0` path is byte-identical.

### Internal

- One `MatrixRunPlan` behind all three runners and the preview: config
  resolution, matrix generation, the component device-axis collapse and golden
  path assignment happen in one place instead of three that had already drifted.
- One `CaptureStrategy` pipeline: the viewport and intrinsic modes shared a
  pump/settle/setup/compare sequence written out twice and now differ only in
  view setup, widget tree, boundary key and capture scale. Parity tests run one
  combination through both and compare results, skip behaviour, failure phase,
  `setup` and `captureAfter`.
- One tolerant comparator and one report pipeline instead of a copy per runner.
  Neither copy of the comparator had ever been covered by a test — every
  tolerance test stopped at argument validation.

## 1.4.0

Bug-fix release across sampling, component mode and reporting. No signature
changes; the additions are `MatrixFailurePhase`,
`MatrixCombinationResult.failurePhase` and a `formats` parameter on the Markdown
writer.

### Fixed

- **`MatrixSampling.pairwise` lost pair coverage under correlated rules.** Axis
  domains were collected independently from the surviving combinations, and
  tuples that no longer existed were dropped in silence. On a 2×2×2 matrix, 154
  of 255 possible rule subsets lost coverage — in the worst case 1 selected
  combination out of 2 feasible, with a green CI. Selection now runs a
  constraint-aware greedy over the surviving combinations whenever rules made
  the feasible set sparse.

  **Migration:** matrices with no rules, or with rules that remove a whole axis
  value, keep going through the previous code path and select exactly the same
  combinations — nothing to do. Only matrices whose rules correlate two or more
  axes (e.g. "dark only with `en`") get a different, larger set, so some goldens
  are new and some become stale. Run `flutter test --update-goldens` and delete
  what the stale report lists.

- **`componentMatrixGolden` did not ignore the `devices` axis it documents as
  ignored.** Since the golden path has no device segment, N devices registered N
  tests with identical descriptions writing and comparing the same PNG.
  `MatrixPreset.componentFull` triggered this by construction: 16 tests over 8
  files. The axis is now collapsed to its first value before generation, so it
  affects neither rules, sampling, nor report counters.

  **Migration:** golden file names are unchanged. Component runs with a
  multi-device axis simply register fewer tests — `componentFull` yields 8
  combinations there instead of 16. Rules matching on `c.device` now only ever
  see the first device; a matrix that ends up empty because of one is reported.

- **Failures before the golden comparison never reached the report.** A throw
  from the widget builder, `pumpWidget`, `pumpAndSettle` or `setup` escaped
  through `finally` with no result recorded, so reports undercounted
  `total`/`failed`, JUnit lost the `testcase` entirely, and the stale detector
  flagged the live golden of a failing combination as an orphan. Both runners
  now share one lifecycle that records exactly one result per combination and
  rethrows with `Error.throwWithStackTrace`, keeping the original stack.

- **Reports named the wrong cause.** Every JUnit failure was
  `type="PixelMismatch"`, including builder throws and layout errors raised
  before a pixel was compared, and the Markdown footer always linked to an HTML
  report even when only Markdown was requested.

- **`MatrixSampling.priorityBased` was not reproducible across matrix sizes.**
  `List.sort` is only stable below 32 elements, so above that the order of
  equal-score combinations scrambled and `maxCombinations` kept a different
  subset depending on matrix size and SDK version. Equal scores now break by
  declared order.

- **Stale-golden scan failures were indistinguishable from "nothing is stale".**
  A permission error silently disabled stale detection; it is now reported.

### Added

- **`MatrixFailurePhase`** (`build`, `pump`, `setup`, `comparison`) and
  `MatrixCombinationResult.failurePhase`, written to JSON as `phase` and mapped
  in JUnit to `BuildError` / `PumpError` / `SetupError` / `GoldenMismatch`, with
  a neutral `Failure` when unclassified.

  **Migration:** CI dashboards filtering on `type="PixelMismatch"` need updating
  — that value is no longer emitted.

- **`const MatrixRule`.** `MatrixRule.exclude` / `includeOnly` are generative
  const constructors, so a `const MatrixPreset` with rules is finally possible —
  which the docs had been recommending all along. Existing call sites with
  closures compile unchanged.

- **Warnings for silently degraded runs** — a `maxCombinations` cap that breaks
  pairwise coverage or eats smoke's per-axis deltas, and a matrix that rules or
  `scenarioTags` filtered down to nothing.

### Changed

- **Input validation throws `ArgumentError` instead of asserting.** Asserts
  vanish outside debug builds and carry no argument context. Newly rejected:
  non-finite or non-positive `textScales`, non-finite `tolerance` (NaN passed
  every range check and then failed every golden), device `logicalSize` with
  non-positive extents, `maxCombinations` below 1 (it used to surface as a
  `RangeError` from `sublist`), and zero-sized `PairwiseGenerator` domains. A
  `scenarioTags` value matching no scenario now says so instead of blaming
  `scenarios`.

## 1.3.0

- **BREAKING — `componentMatrixGolden`'s `pixelRatio` now defaults to `1.0`.**
  1.2.0 made the parameter honest (it finally drives the raster) but kept its
  historical `2.0` default, which silently doubled every component golden. The
  default is now `1.0`, so component PNGs are the widget's logical size again —
  the same files 1.1.2 and earlier produced, and consistent with `captureScale`
  at screen level.

  **Migration:** if you regenerated goldens on 1.2.0, they are 2× and will fail
  on dimensions (`image sizes do not match`). Either regenerate:

  ```bash
  flutter test --update-goldens
  ```

  or pass `pixelRatio: 2.0` explicitly to keep the 1.2.0 files. Coming from
  1.1.2 or earlier, nothing changes.

- **BREAKING — reports are opt-in.** `reportFormats` on `matrixGolden`,
  `screenMatrixGolden` and `componentMatrixGolden` now defaults to `const {}`:
  a run writes no JSON/HTML/Markdown files unless you ask for them. Golden
  runs no longer scatter report artifacts through the repo by default.

  **Migration:** pass the bundle where you want reports —

  ```dart
  matrixGolden('Button', scenarios: [...], reportFormats: defaultReportFormats);
  ```

  `defaultReportFormats` still exports the JSON + HTML + Markdown set it always
  did; it is simply no longer the default value. Stale-golden detection is
  unaffected — with reports off, stale paths are printed to the console.

- **Smaller published archive — 272 KB → 127 KB.** The package no longer ships
  `test/`, the docs-site config, or the example's bracketed-font fixture, none
  of which run from a pub cache. It also no longer ships `coverage/` and
  golden-failure artifacts: those are gitignored, but a `.pubignore` makes pub
  skip `.gitignore` entirely, so they had been leaking into the archive.
  `lib/` and the `example/` usage surface are unchanged.

## 1.2.0

- **BREAKING — `componentMatrixGolden` now really captures at `pixelRatio`.**
  Its docs have always said *"PNG resolution in physical pixels = widget logical
  size × this value"* with a default of `2.0`, but every component golden was in
  fact written at logical size: the capture went through
  `matchesGoldenFile(Finder)`, which rasterizes the boundary's layer at
  `pixelRatio: 1.0` regardless of `tester.view.devicePixelRatio` (the
  device-pixel-ratio transform lives in `RenderView`, above the boundary). The
  documented behavior is now the real one.

  **Migration:** since the affected value is the *default*, every existing
  component golden changes size — a 117×53 badge becomes 234×106. The comparator
  reports `image sizes do not match` before comparing any pixels, so the failure
  is loud and the fix is one command:

  ```bash
  flutter test --update-goldens
  ```

  Pass `pixelRatio: 1.0` to keep the old files instead. `matrixGolden` and
  `screenMatrixGolden` are unaffected.

- **`captureScale` on `matrixGolden` / `screenMatrixGolden`** (default `1.0`,
  opt-in — existing goldens are untouched). Sets physical pixels per logical
  pixel in the captured PNG, so supersampled output is finally reachable:
  `captureScale: 2.0` turns a `phoneSmall` golden from 375×667 into 750×1334.
  Raising it invalidates that call's baselines by dimension; the scale is
  deliberately not part of the golden path.

- **`MatrixDevice.pixelRatio` documented as layout-only.** It drives
  `MediaQuery.devicePixelRatio`, resolution-aware asset variants and the
  physical viewport — never the golden's resolution. Capturing screens at
  logical size stays the default, matching golden_toolkit and alchemist. See
  the new sections in `docs/devices.md` and `docs/advanced.md`.

## 1.1.2

- **Variable fonts with square brackets in the filename now load.**
  `Geist[wght].ttf`, `Inter[opsz,wght].ttf` and friends — the upstream naming
  convention for variable fonts — were unloadable, and worse, took the whole
  test file down with them (see below). `[` and `]` are URI gen-delims, so
  `flutter_tools` percent-encodes the key it writes into `FontManifest.json`
  (`Geist%5Bwght%5D.ttf`); `PlatformAssetBundle.load` then encodes it *again*,
  looks for `Geist%255Bwght%255D.ttf` and misses. `loadAppFonts()` now retries
  such an asset with the percent-**decoded** key, whose single encoding lands on
  the real filename. Verified end to end on Flutter 3.44.8 for a project-level
  asset, a dependency's `packages/<pkg>/…` asset and the self-test alias: text
  renders with real glyphs instead of Ahem squares. The raw key is always tried
  first, so nothing changes for fonts that already worked.
- **`loadAppFonts()` no longer fails the whole test file when a font asset is
  unloadable.** Any font that could not be loaded threw out of `loadAppFonts()`,
  and because it is awaited in `flutter_test_config.dart`'s `testExecutable`, the
  **entire test file failed at load time** — every golden in it, including those
  that never render that font. Such a family is now skipped with a warning naming
  the family, its assets and the underlying error, and the rest of the suite
  runs. Families sharing the same assets (a family and its `packages/<pkg>/`
  alias) warn once.
- **Fixed: a failed `Roboto` / `MaterialIcons` manifest entry suppressed the
  Flutter SDK fallbacks.** Families were marked as loaded before the load was
  awaited, so a failure left the family "claimed" and skipped the SDK fallback,
  silently degrading text to Ahem squares and icons to empty boxes. Only
  successfully loaded families are recorded now.

## 1.1.1

- **`loadAppFonts()` now resolves a package's own prefixed fonts in its self-test.**
  A package that references its bundled fonts as `packages/<pkg>/<family>` (the
  form required in consumer apps) previously rendered Ahem in its *own* test
  suite: the generated `FontManifest.json` lists those families un-prefixed, so
  the requested `packages/<pkg>/...` name never matched. `loadAppFonts()` now
  reads the package name from `pubspec.yaml` and additionally registers each
  bundled **text** family under its `packages/<pkg>/<family>` alias, so both
  names resolve — no manual `FontLoader` workaround needed. Icon families are
  not aliased; combine with `loadAppFonts(iconFonts: false)` to skip Material
  icon loading. See the
  [Font namespacing guide](https://mavoryl.github.io/golden_matrix/font-namespacing/).

## 1.1.0

- **Typed scenarios — `MatrixScenario.typed<T>`.** Attach a
  compile-time-checked `payload` to a scenario and feed it to a builder you can
  reuse across all scenarios — ideal for one widget rendered across several
  state-manager states (loading / loaded / error / empty). Replaces stringly-typed
  `switch (combination.scenario.name)` and per-scenario `BlocProvider` boilerplate.

  ```dart
  Widget build(UserState s) =>
      BlocProvider<UserCubit>(create: (_) => UserCubit()..emit(s), child: const UserList());

  matrixGolden('UserList', scenarios: [
    MatrixScenario.typed('loading', payload: const UserState.loading(), builder: build),
    MatrixScenario.typed('loaded',  payload: UserState.loaded([...]), builder: build),
    MatrixScenario.typed('error',   payload: const UserState.error('x'), builder: build),
  ]);
  ```

  Fully **non-breaking**: the plain `MatrixScenario(name, builder: () => widget)`
  constructor is unchanged; the typed builder is wrapped into the zero-argument
  builder internally. The payload is also exposed as `scenario.payload`. See the
  [Advanced guide](https://mavoryl.github.io/golden_matrix/advanced/#typed-scenarios).

## 1.0.0

First stable release. Visual identity, a documentation site, and removal of the
APIs deprecated during 0.x.

### BREAKING

- **Removed the deprecated `report: bool` parameter** from `matrixGolden` and
  `screenMatrixGolden` (deprecated since 0.16.0). Use `reportFormats` instead:
  - `report: true` → drop it (the default already writes JSON + HTML + Markdown),
    or pass an explicit set like `reportFormats: defaultReportFormats`.
  - `report: false` → `reportFormats: const {}`.
- **Removed `reportOrphanGoldenSubdirs` and `MatrixGoldenRegistry`** (deprecated
  since 0.18.1). Top-level orphan detection was unreliable under Flutter's
  default parallel-isolate test execution. Per-test stale detection
  (`detectStaleGoldens`, enabled by default) already catches scenario-level
  orphans; a post-suite CLI tool for accurate top-level detection is planned.

### Added

- **Brand identity** — README hero banner plus a package logo / favicon
  ("golden snapshot grid": a 3×3 grid of widget variants, gold on the diagonal).

### Changed

- **Widened the SDK constraint to `>=3.2.0 <4.0.0` (Flutter ≥ 3.16)**, verified
  via a CI compatibility matrix down to the `TextScaler` API floor. The package
  no longer needlessly required Dart 3.9.

## 0.19.2

- **Documentation site + leaner README.** Full documentation now lives at a
  dedicated MkDocs Material site (Home, Sampling, Devices, Reports, CI
  integration, Advanced, Migration guide). The pub.dev/GitHub README is now a
  concise landing card that links out to the site. No API changes.
- **Repository moved to the `mavoryl` organization.** Homepage, repository,
  and issue-tracker links now point to `github.com/mavoryl/golden_matrix`.

## 0.19.1

- **Reports now land next to their golden PNGs for any test directory layout.**
  When `reportDir` is omitted, the report directory is derived from the active
  golden comparator's `basedir` (`<test-file-dir>/goldens`) instead of guessing
  from a fixed list of prefixes (`test/`, `test/golden/`, `test/goldens/`).
  Previously, tests living in any other directory — e.g. `test/golden_component/`
  or `test/widget/screens/` — had their `*_report.{json,html,md,xml}` written to
  a stray top-level `goldens/` relative to the working directory, away from the
  PNGs they describe (so the HTML report's image links resolved to nothing).
  Tests under the conventional `test/golden/` layout are unaffected — the
  resolved path is identical, just absolute instead of relative.

## 0.19.0

- **`componentMatrixGolden` — new API for small widgets at their intrinsic size.** Sister function to `matrixGolden`/`screenMatrixGolden` for component-level testing (buttons, badges, chips, list tiles). Instead of rendering inside a full `Scaffold` and capturing the whole 375×667 viewport with the widget centered in 95% whitespace, the function keeps the `MaterialApp` context (so theme/fonts/icons/locale all work) but anchors the widget via `Align(widthFactor: 1, heightFactor: 1)` and places the `RepaintBoundary` directly around it. The resulting PNG is exactly widget-sized plus optional padding.

  ```dart
  componentMatrixGolden(
    'ShadButton',
    scenarios: [
      MatrixScenario('primary',
          builder: () => const ShadButton(child: Text('Click'))),
      MatrixScenario('destructive',
          builder: () => const ShadButton.destructive(child: Text('Delete'))),
    ],
    axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
  );
  ```

  Configuration:
  - `pixelRatio: double` (default `2.0`) — PNG resolution in physical pixels = widget logical size × this value.
  - `padding: EdgeInsets` (default `EdgeInsets.all(8)`) — visual breathing room around the widget; pass `EdgeInsets.zero` for the tightest crop.

  File naming drops the device segment: `goldens/<test>/<scenario>/<theme>_<locale>_<dir>_<scale>.png`. The `devices` field of `MatrixAxes` is ignored in component mode because intrinsic size does not depend on device geometry.

  Limitations: widgets without an intrinsic size (e.g. plain `Container()` with no `width`/`height`) throw a layout error — wrap them in `SizedBox(width:..., height:...)`. Widgets that need an `Overlay` ancestor (Tooltip, `showDialog`, `Hero` animations across routes) still work because we keep the full `MaterialApp` context, but `Scaffold`-positioned widgets (AppBar, FAB) belong in `matrixGolden`.

## 0.18.1

- **Stale-golden detection now runs even when reports are disabled.** Previously, setting `reportFormats: const {}` silently disabled stale detection too — projects that opted out of report files lost the regression check entirely. As of 0.18.1, stale paths print directly to the test console in that mode, so you always see scenario-level orphans like `goldens/dialog/old_scenario/*.png` regardless of report configuration.

  ```
  golden_matrix: screenMatrixGolden: dialog has 2 stale golden file(s):
    - goldens/dialog/alert/dark_en_ltr_1x_phonesmall.png
    - goldens/dialog/alert/light_en_ltr_1x_phonesmall.png
  ```

- **Deprecated `reportOrphanGoldenSubdirs` and `MatrixGoldenRegistry`.** The cross-test, top-level orphan detection from `flutter_test_config.dart` cannot be made reliable under Flutter's default parallel-isolate test execution — the registry is per-isolate, so each `flutter test` process saw only its own slugs and emitted false positives for sibling tests. Per-test stale detection (`detectStaleGoldens`, enabled by default) already catches the common scenario-level case. A post-suite CLI tool for accurate top-level orphan detection is planned for a future release. Existing callers continue to compile; the deprecation is informational only.

- **Fixed double-slash in path output.** `reportOrphanGoldenSubdirs` and the internal stale detector both built paths like `components//goldens/...` when the comparator's `basedir` URI carried a trailing separator. Path joining now collapses the redundant separator.

## 0.18.0

- **Selective text/icon font loading.** New optional `textFonts` and `iconFonts` parameters on `loadAppFonts()` (both default `true`, fully backward compatible). Enables layout-deterministic golden tests where text uses the Ahem placeholder (predictable geometry across macOS/Linux CI) while icons render with real glyphs.

  ```dart
  // test/flutter_test_config.dart — Ahem text + real icons
  Future<void> testExecutable(FutureOr<void> Function() testMain) async {
    await loadAppFonts(textFonts: false);
    return testMain();
  }
  ```

  Icon families are detected by a substring heuristic (`'icons'` / `'symbols'`, case-insensitive) that catches `MaterialIcons`, `CupertinoIcons`, `FontAwesomeIcons`, `MaterialSymbolsRounded/Sharp/Outlined`. Icon fonts that don't follow this convention (e.g. `Phosphor`) are treated as text — file an issue if your project hits this.

- **MaterialIcons SDK fallback.** When `MaterialIcons` is not in `FontManifest.json` (i.e. no `cupertino_icons` dependency or similar), the loader now reads `$FLUTTER_ROOT/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf` automatically. Closes the gap where icons rendered as empty boxes in projects without that dependency. **Heads-up**: if you previously relied on the missing-glyph behavior for goldens, this will change those goldens to show real icon glyphs.

- New `isIconFamily(String)` helper exposed via `@visibleForTesting` for projects that want to mirror the same filter logic.

## 0.17.0

- **JUnit XML report (`MatrixReportFormat.junit`).** New opt-in report format consumed natively by GitHub Actions, GitLab CI, CircleCI, Jenkins, Buildkite, Azure DevOps, and most CI dashboards. Each scenario becomes a `<testsuite>`, each combination becomes a `<testcase>`; failures emit `<failure>` with the captured error message; skipped combinations emit `<skipped/>`. Output file is `<slug>_report.xml` alongside the other reports.

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

  GitHub Actions integration (one extra step):

  ```yaml
  - name: publish JUnit test results
    if: always()
    uses: dorny/test-reporter@v1
    with:
      name: Golden Matrix
      path: '**/test/golden/goldens/*_report.xml'
      reporter: java-junit
  ```

  Pure additive — `defaultReportFormats` deliberately omits `junit` so existing behaviour is unchanged.

- **Monorepo / melos friendly.** Multi-module setups aggregate XMLs via path glob — no special API needed. Documented in README. Recommendation: prefix `matrixGolden` test names with the module name (`'wallet/Button'`) to avoid tree collisions between modules.

- Coverage stayed at **92.2%** (was 91.6%). New `junit_template.dart` at 100%.

## 0.16.0

Three additive items, one deprecation. No breaking changes.

- **`reportFormats: Set<MatrixReportFormat>` parameter** on `matrixGolden` and `screenMatrixGolden`. Per-format toggle for `MatrixReportFormat.json` / `.html` / `.markdown`. Default is all three (matches previous behaviour). Pass an empty set to skip reporting entirely (`reportFormats: const {}`). Stale detection now gated by `formats.isNotEmpty`; console summary stays controlled by `printSummary`.

  ```dart
  matrixGolden(
    'ProfileCard',
    scenarios: [...],
    reportFormats: const {MatrixReportFormat.markdown}, // CI: only the MD sidecar
  );
  ```

- **`isCiEnvironment` exported getter.** Best-effort CI detection so users can branch their `reportFormats` without rolling their own env-var check. Detects via `CI=true|1` (GitHub Actions, GitLab CI, CircleCI, Travis, Buildkite, Drone, Netlify) plus vendor-specific env-var presence: GitHub Actions, GitLab CI, CircleCI, Buildkite, Azure Pipelines, Bitbucket Pipelines, Codemagic, Jenkins, TeamCity, Bamboo.

  ```dart
  matrixGolden(
    ...,
    reportFormats: isCiEnvironment
        ? const {MatrixReportFormat.markdown}
        : const {MatrixReportFormat.html},
  );
  ```

- **Cross-test orphan-subdir detection** completes pain #6 from 0.14.0. Each `matrixGolden` / `screenMatrixGolden` call automatically records its slug in a process-global `MatrixGoldenRegistry`. New exported `reportOrphanGoldenSubdirs({String? goldensRoot, bool fail = false})` walks the goldens root and lists top-level subdirs not touched by any test — catches whole renamed/deleted `matrixGolden` calls that per-test stale detection can't see. Opt-in via one line in `flutter_test_config.dart`:

  ```dart
  Future<void> testExecutable(FutureOr<void> Function() testMain) async {
    await loadAppFonts();
    await testMain();
    await reportOrphanGoldenSubdirs(fail: isCiEnvironment);
  }
  ```

- **Deprecated: `report: bool` parameter.** Use `reportFormats` instead. `report: true` resolves to all three formats; `report: false` resolves to the empty set. When both are passed, `report:` wins (backwards-compat). Will be removed in a future minor release. Existing code is unaffected — only triggers an analyzer info-level deprecation warning.

- **Coverage push.** Line coverage from ~87% to **91.6%**. New tests in `screen_matrix_golden_test.dart`, `font_loader_test.dart`, `ci_detection_test.dart`, `orphan_registry_test.dart`, plus extensions to `matrix_combination_test.dart` covering equality/hashCode/toString/assertions on `MatrixScenario` / `MatrixTheme` / `MatrixDevice`.

## 0.15.0 — Review DX

Two additive reporting upgrades plus a long-standing failure-tracking bug fix. No breaking changes.

- **Diff thumbnails in HTML report.** Every failed test now shows a 4-tile grid (expected · actual · diff · masked) inline next to the error message, pulling Flutter's own `failures/<base>_{masterImage,testImage,isolatedDiff,maskedDiff}.png` outputs. No image processing on our side — we just reference what Flutter already writes. Missing files hide gracefully via `onerror`. Passed and skipped tests are unaffected.
- **Markdown summary sidecar.** A new `<slug>_report.md` is written alongside the existing JSON and HTML reports. Includes a summary list (counts + duration), an optional `## Failed` table, an optional `## Stale goldens` list, and a link to the HTML report. Drop-in for GitHub Actions step summary (`$GITHUB_STEP_SUMMARY`), PR-comment bots, and Slack notifications.
- **Fix: failed-result tracking.** Golden mismatches were being recorded as `status: passed` in JSON / HTML / Markdown reports even though `flutter test` correctly marked the run as failed. Pixel-mismatch errors from the comparator are routed through `FlutterError.reportError` (via `runAsync`) rather than propagating through the matcher's await chain — so `await expectLater(...)` returned cleanly and we mistakenly recorded a pass. The runner now also consults `tester.binding.takeException()` after the matcher returns. Existing passing tests are unaffected.

Reporting features are gated by the existing `report: true` parameter — no new public API.

## 0.14.0

- **Automatic stale-golden detection.** After every `matrixGolden` / `screenMatrixGolden` run, the runner walks the test's golden subdirectory on disk and reports any PNG files that no combination produced. Catches orphans from renamed scenarios, dropped axes, or removed locale/device coverage. Surfaced in three places:
  - **Console summary**: a `Stale` count and full list under the existing test summary block.
  - **JSON report**: new top-level `staleGoldens: [...]` field (only present when non-empty).
  - **HTML report**: a `Stale` stat card next to Warnings, plus a collapsible orange section listing each orphan path.
- Detection is **on by default**. Opt out per call with `detectStaleGoldens: false`.
- Detection is **automatically skipped** when `fileNameBuilder` is supplied — paths are custom, the conventional `goldens/<test-slug>/` layout assumption breaks.
- Flutter's own `failures/` diff outputs are correctly excluded from the orphan list.
- Pure additive — no breaking changes. Existing tests on clean repos produce byte-identical reports.

## 0.13.0 — BREAKING (only if you used `tolerance:`)

- **Fix: `tolerance:` was silently looking up goldens in the wrong directory.** The `_TolerantComparator` passed the delegate's `basedir` directly to `LocalFileComparator(Uri testFile)` — which interprets its argument as a test-file URI and applies `dirname()`, shifting the effective basedir one level up. As a result, tolerance-enabled goldens were generated and matched at a path one directory above where they should have been.
- **Impact:** Tests using `tolerance:` will now look for goldens at the correct path. Pre-existing baselines on the shifted path will not be found → tests fail with `Could not be compared against non-existent file`.
- **Migration:** For every `matrixGolden` / `screenMatrixGolden` call that uses `tolerance:`, either:
  - Move existing golden files from the shifted location down one directory to the correct one, **or**
  - Run `flutter test --update-goldens` once to regenerate baselines at the correct path. The pixel content is unchanged — only the file location.
- **Bonus:** the example test suite (`example/test/golden/sample_golden_test.dart`) now applies `tolerance: 0.01 / 100` (0.01%) to every test, absorbing cross-macOS anti-aliasing noise and unblocking CI on `macos-latest`.

## 0.12.0

Post-pump-state release. Three orthogonal additions that together unlock a huge class of previously impossible tests.

- **`setup` callback** — `(WidgetTester tester, MatrixCombination combination) async {...}` runs after `pumpAndSettle` and before the golden is captured. Tap, scroll, enter text, open menus — snapshot the post-interaction state. Available on `matrixGolden` and `screenMatrixGolden`.
- **`freezeAnimations: bool = false`** — wraps the widget tree in `TickerMode(enabled: false)`, halting every `AnimationController` / `Ticker`. Use for widgets with infinite shimmer / skeleton / loader animations that otherwise hang `pumpAndSettle`. Snapshot reflects the initial frame.
- **`captureAfter: Duration?`** — pumps the test clock for the given duration *after* settling (and after `setup`), before capture. Pair with `freezeAnimations: false` to catch a specific mid-animation frame.

Pure additive — all three default to no-op behavior. Existing 140 example goldens pass without `--update-goldens`.

## 0.11.0

- **`wrapApp` — app-level decorator for `matrixGolden`.** New optional parameter that wraps the auto-built `MaterialApp` from the outside. This is the seam for dependency injection above MaterialApp: `ProviderScope` (Riverpod) with overrides, `BlocProvider` / `MultiBlocProvider`, `MultiProvider`, or any custom root-level `InheritedWidget` (e.g. brand themes that must sit above MaterialApp). The callback receives the current `MatrixCombination` so providers can vary per scenario. Pure additive — when `null`, the widget tree is byte-identical to previous versions, existing golden files unchanged.

## 0.10.0

- **More device presets** — modern phones (`iphone15Pro`, `iphone16ProMax`, `pixel8`, `pixel8Pro`, `galaxyS24`), foldables (`galaxyZFoldFolded`, `galaxyZFoldUnfolded`), and full iPad lineup (`ipadMini`, `ipadAir`, `ipadPro11`, `ipadPro11Landscape`, `ipadPro13`, `ipadPro13Landscape`).
- **`copyWith()` on models** — `MatrixAxes.copyWith`, `MatrixDevice.copyWith`, `MatrixCombination.copyWith`. Tweak a preset axes set, rotate a device into landscape, or fabricate a near-identical combination without re-declaring every field.

## 0.9.1

- **Dry-run preview** — new `previewMatrixGolden(...)` returns a `MatrixPreview` describing what the runner would do (combination counts before/after rules and sampling, golden paths, duplicate-path detection) without rendering widgets or writing files. Use it to sanity-check `scenarioTags`, estimate CI cost, or spot golden-path collisions before they overwrite each other.

## 0.9.0 — BREAKING

- **Breaking: `tags` → `scenarioTags`.** The parameter was documented as Flutter test tags but actually filtered scenarios. Renamed for clarity. **Migration:** replace `tags:` with `scenarioTags:` at call sites.
- **Fix: pairwise sampling honors rules.** Pairwise now derives its parameter domain from combinations surviving exclude/includeOnly rules, restoring coverage guarantees over the feasible set. Direction stays inferred from locale unless `axes.directions` is set explicitly.
- **Fix: `maxCombinations` is now a global cap.** Applied uniformly after any sampling strategy, not only `priorityBased`.
- **Fix: tolerance hardening.** Validates `tolerance` is in 0.0..1.0, and fails with a clear `StateError` when the active `goldenFileComparator` is not a `LocalFileComparator` instead of a force-cast crash.
- **Fix: `ErrorCapture` no longer downgrades layout-contract failures.** "RenderBox was not laid out" and similar are forwarded to the test framework. Only true overflow patterns remain whitelisted.

## 0.8.3

- **Better failure messages** — warnings for `priorityBased` sampling without `maxCombinations` on large matrices, and when `loadAppFonts` cannot find Roboto.
- **Validation** — asserts on empty `MatrixScenario`, `MatrixTheme.custom`, `MatrixDevice` names and non-positive `pixelRatio`.
- **Switched to `debugPrint`** — replaces `print` in summary output and warnings.

## 0.8.2

- **Docs** — update install snippet version in README to current.

## 0.8.1

- **Docs** — expanded dartdoc across the public API: per-parameter docs on `matrixGolden`/`screenMatrixGolden`, sampling strategy comparisons, preset descriptions, complex rule examples, device preset table, custom theme system pattern, error capture pattern list.

## 0.8.0 — BREAKING

- **Breaking: golden file paths now include the test name** — fixes a silent collision bug where two `matrixGolden` calls with scenarios sharing names (e.g. `'default'`) would overwrite each other's golden files.
  - Old path: `goldens/<scenario>/<theme>_<locale>_<dir>_<scale>_<device>.png`
  - New path: `goldens/<test>/<scenario>/<theme>_<locale>_<dir>_<scale>_<device>.png`
  - **Migration:** delete your existing `goldens/` directory and run `flutter test --update-goldens` to regenerate at the new paths. If you used `fileNameBuilder` you are unaffected.

## 0.7.1

- **Fix** — overflow warnings no longer fail the test. ErrorCapture was forwarding captured layout warnings to the default handler, which marked the test as failed.

## 0.7.0

- **Console summary** — prints test counts, duration, and failed combinations in `tearDownAll`. Opt-out via `printSummary: false`.

## 0.6.3

- **Smaller package** — excluded example golden PNG files from the published package (~900 KB → much smaller). Reference outputs available in the GitHub repository.

## 0.6.2

- **Fix** — shorter description in pubspec.yaml (pub.dev recommends 60-180 characters)

## 0.6.1

- **Fix** — use `dev_dependencies` in README examples (was incorrectly `dependencies`)
- **Docs** — add pub.dev badge to README

## 0.6.0

- **Value equality** — `MatrixTheme`, `MatrixDevice`, `MatrixScenario` now use `==`/`hashCode` instead of name-string comparisons
- **Input validation** — asserts on empty axes lists in `MatrixGenerator.generate()`
- **Skipped result tracking** — combinations recorded as `skipped` when `skip: true`
- **Centralized slugify** — single `slugify()` utility used across all models and report writer
- **Runner refactoring** — `runMatrixTests` split into focused helpers (`resolveCombinations`, `groupByScenario`, `_executeGoldenTest`, etc.)
- **108 tests** — 68 unit + 30 integration + 10 runner helper tests

## 0.5.0

- **Overflow detection** — automatically captures `RenderFlex overflow` and layout errors during golden tests, reports them as warnings in JSON/HTML
- **Pairwise sampling** — `MatrixSampling.pairwise` covers all parameter pairs with minimal test cases (e.g. 270 → ~30)
- **HTML reports** — self-contained HTML report with thumbnails, filters, dark mode support
- **Tolerance** — `tolerance` parameter for pixel diff threshold (e.g. `0.05 / 100` for 0.05%)
- **Skip** — `skip` parameter to conditionally skip tests (e.g. `skip: !Platform.isMacOS`)
- **Custom wrapper** — `wrapChild` parameter to customize inner layout (remove default Scaffold+Center)
- **Theme data** — `MatrixTheme.custom('name', themeData, data: customObject)` for arbitrary context
- **Report directory** — `reportDir` parameter to control report output location

## 0.4.0

- **Pairwise sampling** — greedy all-pairs algorithm via `MatrixSampling.pairwise`

## 0.3.0

- **HTML report** — auto-generated self-contained HTML with scenario grouping, filters, thumbnails
- **Result collection** — automatic test result tracking with JSON/HTML export via `tearDownAll`

## 0.2.0

- **Sampling strategies** — `MatrixSampling.smoke`, `MatrixSampling.priorityBased` with `maxCombinations`
- **Presets** — `MatrixPreset.componentSmoke`, `componentFull`, `screenSmoke`
- **Include rules** — `MatrixRule.includeOnly(predicate)`
- **Device aliases** — `iphoneSE`, `iphone15`, `galaxyS20`, `galaxyA51`, `tabletLandscape`
- **JSON reports** — `MatrixResult.toJson()` with timestamp, duration, per-combination results
- **Tags** — filter scenarios by tags
- **Custom filename** — `fileNameBuilder` parameter

## 0.1.0

- Initial release
- `matrixGolden()` and `screenMatrixGolden()` APIs
- Full Cartesian product generation with direction inference (RTL for ar, he, fa, ur, ps, ku, yi)
- `MatrixRule.exclude()` for combination filtering
- 6 device presets with realistic pixel ratios and safe areas
- `loadAppFonts()` for real font rendering in golden tests
- Deterministic naming: `goldens/<scenario>/<theme>_<locale>_<dir>_<scale>_<device>.png`
