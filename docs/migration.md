# Migration guide

Moving an existing golden-test setup to `golden_matrix` — what maps to what, and what to expect.

## Why migrate

`golden_matrix` replaces hand-written combinatorial golden tests with a single declarative matrix:

- One declaration fans out across a full theme × locale × direction × text-scale × device matrix — no nested loops.
- One PNG per combination (not one giant composite image), so a diff points at the exact theme/locale/device that broke.
- HTML, JSON, Markdown, and JUnit XML reports out of the box — see [Reports](reports.md).
- [Sampling](sampling.md) (`smoke`, `pairwise`, `priorityBased`) trims a large matrix down for fast CI runs.
- Stale-golden detection flags orphan PNGs left behind by renamed scenarios or dropped axis values.
- Zero external dependencies — only the Flutter SDK.

It does not replace `flutter_test` or Flutter's own golden machinery; it sits on top of them and drives the combinations.

## Upgrading to 1.0.0

1.0.0 removes the APIs deprecated during 0.x:

- **`report: bool`** on `matrixGolden` / `screenMatrixGolden` → use `reportFormats`:
    - `report: true` → drop it (the default writes JSON + HTML + Markdown), or pass `reportFormats: defaultReportFormats`.
    - `report: false` → `reportFormats: const {}`.
- **`reportOrphanGoldenSubdirs` / `MatrixGoldenRegistry`** → removed. Per-test stale detection (`detectStaleGoldens`, on by default) already catches scenario-level orphans — see [Reports](reports.md).

## From golden_toolkit

`golden_toolkit` is the most common existing dependency. The concepts map directly:

| golden_toolkit | golden_matrix |
|---|---|
| `testGoldens(...)` | `matrixGolden` / `screenMatrixGolden` |
| `DeviceBuilder` | `MatrixAxes.devices` |
| `multiScreenGolden(...)` | a `MatrixDevice` matrix |
| custom wrapper widget | `wrapApp` / `wrapChild` (see [Advanced](advanced.md)) |
| one composite PNG per test | split scenario/device PNGs + HTML report (see [Reports](reports.md)) |
| `loadAppFonts()` | `loadAppFonts()` (same idea; call in `flutter_test_config.dart`) |

Conceptually, a `golden_toolkit` test builds a `DeviceBuilder`, adds a scenario per device, and pumps a single multi-device composite golden:

```dart
// Before (conceptual golden_toolkit shape)
testGoldens('PrimaryButton', (tester) async {
  final builder = DeviceBuilder()
    ..addScenario(widget: const PrimaryButton(label: 'OK'), name: 'default')
    ..addScenario(
      widget: const PrimaryButton(label: 'OK', enabled: false),
      name: 'disabled',
    );
  // ...plus a device list, a custom wrapper for theme/locale,
  // and one screenMatchesGolden assertion over the composite.
  await tester.pumpDeviceBuilder(builder);
  await screenMatchesGolden(tester, 'primary_button');
});
```

The equivalent `golden_matrix` declaration folds scenarios, devices, themes, and locales into one call:

```dart
// After
matrixGolden(
  'PrimaryButton',
  scenarios: [
    MatrixScenario('default', builder: () => const PrimaryButton(label: 'OK')),
    MatrixScenario('disabled',
        builder: () => const PrimaryButton(label: 'OK', enabled: false)),
  ],
  axes: MatrixAxes(
    themes: [MatrixTheme.light, MatrixTheme.dark],
    locales: [Locale('en'), Locale('ar')],
    devices: [MatrixDevice.phoneSmall, MatrixDevice.tablet],
  ),
);
```

Theme and locale stop being wrapper boilerplate and become axes. Device handling moves to `MatrixAxes.devices` — see [Devices](devices.md) for the full preset list.

## From alchemist

Both tools do golden testing; the difference is scope. `alchemist` is organized around one golden test per case — you declare the scenarios for a single comparison and it produces a golden for that group. `golden_matrix` adds the declarative axis matrix on top: the same scenario set automatically expands across themes, locales, directions, text scales, and devices, and each combination lands as its own PNG plus the [Reports](reports.md) output.

If your `alchemist` tests already enumerate cases by hand, those cases become `MatrixScenario`s and the per-case variation (theme, locale, device) becomes a `MatrixAxes`.

## From hand-rolled goldens

The README's Problem/Solution framing is exactly the hand-rolled case: nested `for` loops plus a manual wrapper per combination.

```dart
// Before: manual loops, boilerplate wrappers
for (final locale in supportedLocales) {
  for (final device in devices) {
    testGoldens('screen_${locale.languageCode}_${device.name}', (tester) async {
      // 30+ lines of wrapper setup per combination...
    });
  }
}
```

```dart
// After: one declaration, full coverage
matrixGolden(
  'PrimaryButton',
  scenarios: [
    MatrixScenario('default', builder: () => const PrimaryButton(label: 'OK')),
    MatrixScenario('disabled',
        builder: () => const PrimaryButton(label: 'OK', enabled: false)),
  ],
  axes: MatrixAxes(
    themes: [MatrixTheme.light, MatrixTheme.dark],
    locales: [Locale('en'), Locale('ar')],
    textScales: [1.0, 2.0],
    devices: [MatrixDevice.phoneSmall, MatrixDevice.phoneLarge],
  ),
);
// 2 scenarios x 2 themes x 2 locales x 2 scales x 2 devices = 32 golden files
```

The loop, the per-iteration test name, and the wrapper all collapse into the declaration. If you have custom wrapping logic, move it to `wrapApp` (above `MaterialApp`) or `wrapChild` (inside `MaterialApp.home`) — see [Advanced](advanced.md). DI providers (Riverpod / Bloc / Provider) belong in `wrapApp`.

## What changes for your goldens

The file layout becomes one PNG per combination:

```
goldens/<test>/<scenario>/<theme>_<locale>_<dir>_<scale>_<device>.png
```

This almost certainly differs from your old naming, so existing baselines won't match. After migrating a test, regenerate its baselines:

```bash
flutter test --update-goldens   # write new baselines
flutter test                    # verify regression run is green
```

!!! note
    Review the regenerated PNGs once before committing — they are your new source of truth. After the first `--update-goldens`, stale-golden detection will flag any orphan files left over from the old layout so you can `git rm` them.

See [CI integration](ci.md) for wiring reports into your pipeline, or head back [Home](index.md).
