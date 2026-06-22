# Advanced

Deep configuration for `golden_matrix`: filtering rules, RTL, tolerance, skipping, wrappers, dependency injection, post-pump state, custom theme data, dry-run previews, and font loading.

See also: [Sampling](sampling.md) · [Devices](devices.md) · [Reports](reports.md) · [CI integration](ci.md) · [Migration guide](migration.md) · [Home](index.md).

## Rules

Filter the generated combinations with predicates. Rules compose and run sequentially.

```dart
MatrixRule.exclude((c) => c.theme.name == 'dark' && c.textScale > 1.5)
MatrixRule.includeOnly((c) => c.device.name == 'phoneSmall' || c.device.name == 'tablet')
```

Passed to a test via the `rules` list:

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

## Direction / RTL auto-inference

Arabic, Hebrew, and Farsi locales automatically get `TextDirection.rtl` — no manual setup. Combinations expose `c.direction`, which you can read in rules (see above) or flip on a one-off combination with `copyWith`:

```dart
final rtl = combination.copyWith(direction: TextDirection.rtl);
```

## Tolerance

Allow small pixel differences for stable CI:

```dart
matrixGolden(
  'Widget',
  scenarios: [...],
  axes: axes,
  tolerance: 0.05 / 100, // 0.05% pixel diff allowed
);
```

## Skip

Conditionally skip tests (e.g. platform-specific golden files):

```dart
matrixGolden(
  'Widget',
  scenarios: [...],
  axes: axes,
  skip: !Platform.isMacOS,
);
```

## Custom Wrapper (`wrapChild`)

Override the default `Scaffold(body: Center(child:))` layout. `wrapChild` runs **inside** the auto-built `MaterialApp.home`, so it's the right level for layout shells (padding, alignment), `Theme` overrides, or scoped providers that live below MaterialApp:

```dart
matrixGolden(
  'Widget',
  scenarios: [...],
  axes: axes,
  wrapChild: (child) => child, // no Scaffold, no Center
);
```

## App-level decorator (`wrapApp`)

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

## Post-pump state: `setup`, `freezeAnimations`, `captureAfter`

Three orthogonal parameters (available on both `matrixGolden` and `screenMatrixGolden`) for snapshotting non-initial states.

### `setup` — interact before capture

```dart
matrixGolden(
  'LoginForm',
  scenarios: [MatrixScenario('validation_error', builder: () => const LoginForm())],
  axes: axes,
  setup: (tester, combination) async {
    await tester.enterText(find.byKey(emailKey), 'bad-email');
    await tester.tap(find.byKey(submitKey));
    await tester.pumpAndSettle();
  },
);
```

Runs after `pumpAndSettle`, before the golden is captured. Use to tap, scroll, enter text, expand menus — anything needed to bring the widget into the visual state you want to snapshot.

### `freezeAnimations` — kill infinite shimmer/skeletons

```dart
matrixGolden(
  'UserCardSkeleton',
  scenarios: [MatrixScenario('loading', builder: () => const UserCardSkeleton())],
  axes: axes,
  freezeAnimations: true, // halts Tickers below — snapshot is stable
);
```

Wraps the widget tree in `TickerMode(enabled: false)`. Halts every `AnimationController` / `Ticker`, including shimmer, skeleton loaders, Lottie, breathing dots, marquee — all the things that otherwise make `pumpAndSettle` hang or produce non-deterministic frames.

### `captureAfter` — snapshot a specific frame

```dart
matrixGolden(
  'SlideInDialog',
  scenarios: [MatrixScenario('mid_slide', builder: () => const SlideInDialog())],
  axes: axes,
  captureAfter: const Duration(milliseconds: 150), // catch dialog half-open
);
```

Pumps the test clock for the given duration after settling (and after `setup`), before capture. Use to catch a deterministic mid-animation frame.

### Composing them

All three combine cleanly:

```dart
matrixGolden(
  'FormAfterSubmit',
  scenarios: [...],
  axes: axes,
  setup: (tester, _) async {
    await tester.tap(submitButton);
    await tester.pump(); // one frame so the loader appears
  },
  freezeAnimations: true,  // freeze the loader spinner
);
```

## Custom Theme Data

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

## Dry-run preview

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

## Font loading

Set up font loading once in `test/flutter_test_config.dart` so real fonts (Roboto + app fonts) render instead of Ahem squares:

```dart
// test/flutter_test_config.dart
import 'dart:async';
import 'package:golden_matrix/golden_matrix.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadAppFonts();
  return testMain();
}
```

!!! tip "Layout-deterministic tests (since 0.18.0)"
    `loadAppFonts(textFonts: false)` loads only icon fonts and uses Ahem
    placeholders for text. Text geometry becomes predictable across
    macOS/Linux CI, while icons still render with real glyphs for review.
