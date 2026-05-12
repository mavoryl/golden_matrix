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
- **Overflow detection** — captures `RenderFlex overflow` and layout errors as warnings in reports
- **HTML reports** — self-contained HTML with thumbnails, scenario grouping, filters, dark mode
- **Tolerance** — configurable pixel diff threshold for flaky-free CI
- **Custom themes** — `MatrixTheme.data` for attaching arbitrary context (custom theme systems, brand config)
- **7 device presets** — phoneSmall, phoneMedium, phoneLarge, androidSmall, androidMedium, tablet, tabletLandscape (+ named aliases)
- **Font loading** — `loadAppFonts()` loads real fonts (Roboto + app fonts) instead of Ahem squares
- **Zero external dependencies** — only Flutter SDK

## Quick Start

### 1. Add dependency

```yaml
# pubspec.yaml
dev_dependencies:
  golden_matrix: ^0.6.0
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

Override the default `Scaffold(body: Center(child:))` layout:

```dart
matrixGolden(
  'Widget',
  scenarios: [...],
  axes: axes,
  wrapChild: (child) => child, // no Scaffold, no Center
);
```

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
// Generic sizes
MatrixDevice.phoneSmall      // 375x667, 2.0x (iPhone SE)
MatrixDevice.phoneMedium     // 390x844, 3.0x (iPhone 15)
MatrixDevice.phoneLarge      // 414x896, 3.0x (iPhone 15 Pro Max)
MatrixDevice.androidSmall    // 360x800, 4.0x (Galaxy S20)
MatrixDevice.androidMedium   // 412x915, 2.625x (Galaxy A51)
MatrixDevice.tablet          // 768x1024, 2.0x (iPad)
MatrixDevice.tabletLandscape // 1024x768, 2.0x

// Named aliases
MatrixDevice.iphoneSE        // = phoneSmall
MatrixDevice.iphone15        // = phoneMedium
MatrixDevice.galaxyS20       // = androidSmall
MatrixDevice.galaxyA51       // = androidMedium

// Custom
MatrixDevice(name: 'pixel7', logicalSize: Size(412, 915), pixelRatio: 2.75)
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
  default/
    light_en_ltr_1x_phonesmall.png
    dark_ar_rtl_2x_phonelarge.png
  disabled/
    light_en_ltr_1x_phonesmall.png
```

Naming: `goldens/<scenario>/<theme>_<locale>_<direction>_<textScale>_<device>.png`

## Requirements

- Flutter SDK >= 3.16.0
- Dart SDK >= 3.2.0

## License

MIT
