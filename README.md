# golden_matrix

[![pub package](https://img.shields.io/pub/v/golden_matrix.svg)](https://pub.dev/packages/golden_matrix)

Matrix-based visual regression testing for Flutter widgets and screens.

Write one golden test declaration, run it across themes, locales, devices, text scales, and UI states.

## The Problem

Flutter golden tests check **one specific case**. When you add themes, locales, device sizes, and states — you get copy-paste and combinatorial explosion:

```dart
// Without golden_matrix: manual loops, boilerplate wrappers
for (final locale in supportedLocales) {
  for (final device in devices) {
    testGoldens('screen_${locale.languageCode}_${device.name}', (tester) async {
      // 30+ lines of wrapper setup per combination...
    });
  }
}
```

## The Solution

```dart
// With golden_matrix: one declaration, full coverage
matrixGolden(
  'PrimaryButton',
  scenarios: [
    MatrixScenario('default', builder: () => const PrimaryButton(label: 'OK')),
    MatrixScenario('disabled', builder: () => const PrimaryButton(label: 'OK', enabled: false)),
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

## Features

- **Declarative matrix** — define axes (themes, locales, devices, text scales, directions), get all combinations automatically
- **Smart defaults** — `MatrixAxes()` with no arguments produces one valid test (light, en, 1.0x, phoneSmall)
- **Direction inference** — Arabic, Hebrew, Farsi automatically get RTL; no manual setup
- **Sampling strategies** — `full`, `smoke`, `priorityBased`, `pairwise` (all-pairs coverage)
- **Pairwise sampling** — covers all parameter pairs with minimal test cases (e.g. 270 → ~30)
- **Presets** — `MatrixPreset.componentSmoke`, `componentFull`, `screenSmoke` for quick setup
- **Exclude/include rules** — `MatrixRule.exclude(...)`, `MatrixRule.includeOnly(...)` with predicates
- **Screen-level testing** — `screenMatrixGolden()` with full control via `appBuilder`
- **DI-friendly** — `wrapApp` hooks `ProviderScope` / `BlocProvider` / `MultiProvider` above the auto-built MaterialApp, with per-combination access
- **Overflow detection** — captures `RenderFlex overflow` and layout errors as warnings in reports
- **HTML reports** — self-contained HTML with thumbnails, scenario grouping, filters, dark mode
- **Tolerance** — configurable pixel diff threshold for flaky-free CI
- **Dry-run preview** — `previewMatrixGolden(...)` reports what the runner would do (counts, paths, collisions) without rendering anything
- **Custom themes** — `MatrixTheme.data` for attaching arbitrary context (custom theme systems, brand config)
- **20+ device presets** — generic size classes, modern iPhones (15 Pro / 16 Pro Max), Android (Pixel 8/8 Pro, Galaxy S24), foldables (Z Fold), and full iPad lineup (mini / Air / Pro 11" / Pro 13" + landscape) — plus `MatrixDevice.copyWith()` for tweaks
- **`copyWith()` on models** — `MatrixAxes`, `MatrixDevice`, `MatrixCombination` — extend presets without re-declaring every field
- **Font loading** — `loadAppFonts()` loads real fonts (Roboto + app fonts) instead of Ahem squares
- **Zero external dependencies** — only Flutter SDK

## Quick Start

### 1. Add dependency

```yaml
# pubspec.yaml
dev_dependencies:
  golden_matrix: ^0.11.0
```

### 2. Set up font loading

```dart
// test/flutter_test_config.dart
import 'dart:async';
import 'package:golden_matrix/golden_matrix.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadAppFonts();
  return testMain();
}
```

### 3. Write your first matrix test

```dart
import 'package:flutter/widgets.dart';
import 'package:golden_matrix/golden_matrix.dart';

void main() {
  matrixGolden(
    'MyButton',
    scenarios: [
      MatrixScenario('default', builder: () => const MyButton(label: 'OK')),
      MatrixScenario('disabled', builder: () => const MyButton(label: 'OK', enabled: false)),
    ],
    axes: MatrixAxes(
      themes: [MatrixTheme.light, MatrixTheme.dark],
      devices: [MatrixDevice.phoneSmall, MatrixDevice.tablet],
    ),
  );
}
```

### 4. Generate baselines and run

```bash
flutter test --update-goldens  # generate baselines
flutter test                   # run regression tests
```

## API

### matrixGolden — component testing

Auto-wraps your widget in a `MaterialApp` with theme, locale, directionality, text scale, and device configuration.

```dart
matrixGolden(
  'ProfileCard',
  scenarios: [
    MatrixScenario('loading', builder: () => const ProfileCard.loading()),
    MatrixScenario('data', builder: () => ProfileCard(user: fakeUser)),
    MatrixScenario('error', builder: () => const ProfileCard.error('Timeout')),
  ],
  axes: MatrixAxes(
    themes: [MatrixTheme.light, MatrixTheme.dark],
    locales: [Locale('en'), Locale('ru'), Locale('ar')],
    textScales: [1.0, 2.0],
    devices: [MatrixDevice.iphoneSE, MatrixDevice.galaxyA51, MatrixDevice.tablet],
  ),
  rules: [
    MatrixRule.exclude((c) => c.locale.languageCode != 'ar' && c.direction == TextDirection.rtl),
  ],
);
```

### screenMatrixGolden — screen testing

You provide the full `MaterialApp` via `appBuilder` — for DI, navigation, custom themes, etc.

```dart
screenMatrixGolden(
  'LoginScreen',
  appBuilder: (combination) => MaterialApp(
    theme: combination.theme.resolve(),
    locale: combination.locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: LoginScreen(
      errorMessage: combination.scenario.name == 'error' ? 'Invalid credentials' : null,
    ),
  ),
  states: [
    MatrixScenario('default', builder: () => const SizedBox.shrink()),
    MatrixScenario('error', builder: () => const SizedBox.shrink()),
  ],
  preset: MatrixPreset.screenSmoke,
);
```

### Presets

```dart
matrixGolden('Widget', scenarios: [...], preset: MatrixPreset.componentSmoke);
matrixGolden('Widget', scenarios: [...], preset: MatrixPreset.componentFull);
screenMatrixGolden('Screen', appBuilder: ..., preset: MatrixPreset.screenSmoke);
```

### Sampling

```dart
// Full Cartesian product (default)
matrixGolden('Widget', scenarios: [...], axes: axes);

// Smoke: base combo + one delta per axis (~5 instead of 32)
matrixGolden('Widget', scenarios: [...], axes: axes, sampling: MatrixSampling.smoke);

// Pairwise: all parameter pairs covered (~12 instead of 36)
matrixGolden('Widget', scenarios: [...], axes: axes, sampling: MatrixSampling.pairwise);

// Priority-based: high-value combos first, capped at N
matrixGolden('Widget', scenarios: [...], axes: axes,
  sampling: MatrixSampling.priorityBased, maxCombinations: 10);
```

### Rules

```dart
MatrixRule.exclude((c) => c.theme.name == 'dark' && c.textScale > 1.5)
MatrixRule.includeOnly((c) => c.device.name == 'phoneSmall' || c.device.name == 'tablet')
```

### Tolerance

Allow small pixel differences for stable CI:

```dart
matrixGolden(
  'Widget',
  scenarios: [...],
  axes: axes,
  tolerance: 0.05 / 100, // 0.05% pixel diff allowed
);
```

### Skip

Conditionally skip tests (e.g. platform-specific golden files):

```dart
matrixGolden(
  'Widget',
  scenarios: [...],
  axes: axes,
  skip: !Platform.isMacOS,
);
```

### Custom Wrapper

Override the default `Scaffold(body: Center(child:))` layout. `wrapChild` runs **inside** the auto-built `MaterialApp.home`, so it's the right level for layout shells (padding, alignment), `Theme` overrides, or scoped providers that live below MaterialApp:

```dart
matrixGolden(
  'Widget',
  scenarios: [...],
  axes: axes,
  wrapChild: (child) => child, // no Scaffold, no Center
);
```

### App-level decorator (`wrapApp`)

Wrap the auto-built `MaterialApp` from **outside**. This is the seam for DI providers that must sit above MaterialApp — `ProviderScope` (Riverpod), `BlocProvider` / `MultiBlocProvider`, `MultiProvider`, or any root-level `InheritedWidget` (e.g. brand theme scopes). The callback receives the current combination so providers can vary per scenario:

```dart
matrixGolden(
  'ProfileCard',
  scenarios: [...],
  axes: axes,
  // Riverpod
  wrapApp: (app, combination) => ProviderScope(
    overrides: [
      userRepoProvider.overrideWithValue(FakeUserRepo()),
    ],
    child: app,
  ),
);

matrixGolden(
  'CounterCard',
  scenarios: [
    MatrixScenario('zero', builder: () => const CounterCard()),
    MatrixScenario('high', builder: () => const CounterCard()),
  ],
  axes: axes,
  // Bloc, varying state by scenario
  wrapApp: (app, c) => BlocProvider<CounterBloc>.value(
    value: FakeCounterBloc(c.scenario.name == 'high' ? 99 : 0),
    child: app,
  ),
);
```

`wrapApp` is complementary to `wrapChild`:
- `wrapApp` sits **above** MaterialApp (DI providers)
- `wrapChild` sits **inside** MaterialApp.home (layout shells)

Use them together when needed. When `wrapApp` is omitted, the widget tree is identical to previous versions — existing goldens unaffected.

For full-screen tests where you want even more control, use `screenMatrixGolden` with its `appBuilder`.

### Dry-run preview

Inspect what a `matrixGolden` / `screenMatrixGolden` call **would do** — combination counts, sampled list, golden paths, collisions — without rendering widgets or writing files:

```dart
final preview = previewMatrixGolden(
  name: 'PrimaryButton',
  scenarios: [MatrixScenario('default', builder: () => const PrimaryButton())],
  axes: MatrixAxes(
    themes: [MatrixTheme.light, MatrixTheme.dark],
    locales: [Locale('en'), Locale('ar')],
  ),
  sampling: MatrixSampling.pairwise,
);

print(preview);
// PrimaryButton
//   Scenarios: 1 (default)
//   Raw combinations: 4
//   After rules: 4
//   After sampling (pairwise): 4
//   Combinations:
//     1. default | light ltr en 1.0x phoneSmall
//        -> goldens/primarybutton/default/light_en_ltr_1x_phonesmall.png
//     ...

preview.afterSamplingCount;   // 4
preview.goldenPaths;          // list of paths the runner would write
preview.duplicatePaths;       // non-empty when scenarios collide on the same path
```

Use it to sanity-check `scenarioTags`, estimate CI cost before adding a new axis, or catch golden-path collisions before they silently overwrite each other.

### Custom Theme Data

Attach arbitrary context to themes — custom theme systems, brand configs, feature flags:

```dart
matrixGolden(
  'Widget',
  scenarios: [...],
  axes: MatrixAxes(
    themes: [
      MatrixTheme.custom('light', ThemeData.light(), data: MyTheme.light()),
      MatrixTheme.custom('dark', ThemeData.dark(), data: MyTheme.dark()),
    ],
  ),
);

// Access in screenMatrixGolden appBuilder:
appBuilder: (combination) {
  final myTheme = combination.theme.data as MyTheme;
  return MyThemeProvider(theme: myTheme, child: MaterialApp(...));
}
```

### Device Presets

```dart
// Generic size classes
MatrixDevice.phoneSmall      // 375x667, 2.0x
MatrixDevice.phoneMedium     // 390x844, 3.0x
MatrixDevice.phoneLarge      // 414x896, 3.0x
MatrixDevice.androidSmall    // 360x800, 4.0x
MatrixDevice.androidMedium   // 412x915, 2.625x

// Modern iPhones
MatrixDevice.iphone15Pro     // 393x852, 3.0x
MatrixDevice.iphone16ProMax  // 440x956, 3.0x

// Modern Android
MatrixDevice.pixel8          // 412x915, 2.625x
MatrixDevice.pixel8Pro       // 448x998, 2.625x
MatrixDevice.galaxyS24       // 384x832, 3.0x

// Foldables
MatrixDevice.galaxyZFoldFolded    // 374x882, 3.0x
MatrixDevice.galaxyZFoldUnfolded  // 716x882, 2.625x

// Tablets
MatrixDevice.tablet              // 768x1024, 2.0x  (generic iPad portrait)
MatrixDevice.tabletLandscape     // 1024x768, 2.0x
MatrixDevice.ipadMini            // 744x1133, 2.0x
MatrixDevice.ipadAir             // 820x1180, 2.0x
MatrixDevice.ipadPro11           // 834x1194, 2.0x
MatrixDevice.ipadPro11Landscape  // 1194x834, 2.0x
MatrixDevice.ipadPro13           // 1024x1366, 2.0x
MatrixDevice.ipadPro13Landscape  // 1366x1024, 2.0x

// Legacy named aliases
MatrixDevice.iphoneSE        // = phoneSmall
MatrixDevice.iphone15        // = phoneMedium
MatrixDevice.iphone15ProMax  // = phoneLarge
MatrixDevice.galaxyS20       // = androidSmall
MatrixDevice.galaxyA51       // = androidMedium
MatrixDevice.ipadPortrait    // = tablet

// Tweak a preset with copyWith — e.g. force a custom name and rotate
final landscape = MatrixDevice.ipadPro11.copyWith(
  name: 'ipadPro11Custom',
  logicalSize: const Size(1194, 834),
);

// Or fully custom
MatrixDevice(name: 'pixel7', logicalSize: Size(412, 915), pixelRatio: 2.75)
```

### `copyWith` on Models

`MatrixAxes`, `MatrixDevice`, and `MatrixCombination` expose `copyWith()` so
you can derive a tweaked instance without re-declaring every field:

```dart
// Extend a preset's axes with one extra device
final axes = MatrixPreset.componentFull.axes.copyWith(
  devices: [...MatrixPreset.componentFull.axes.devices, MatrixDevice.ipadPro13],
);

// Flip a combination's direction or device in a one-off assertion
final rtl = combination.copyWith(direction: TextDirection.rtl);
```

## Overflow Detection

golden_matrix automatically captures `RenderFlex overflow` and layout errors during rendering. Warnings appear in JSON and HTML reports with orange badges — no configuration needed.

## HTML Reports

After tests run, golden_matrix generates self-contained HTML reports alongside golden files:
- Summary with pass/fail/warning counts
- Scenario grouping with collapsible sections
- Thumbnail grid with clickable full-size images
- Filter by scenario, theme, or status
- Dark mode support via `prefers-color-scheme`

See example reports and golden files in the [GitHub repository](https://github.com/Autocrab/golden_matrix/tree/main/example/test/golden/goldens).

## Golden File Structure

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

## Requirements

- Flutter SDK >= 3.16.0
- Dart SDK >= 3.2.0

## License

MIT
