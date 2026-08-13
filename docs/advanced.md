# Advanced

Deep configuration for `golden_matrix`: typed scenarios, filtering rules, RTL, tolerance, skipping, wrappers, dependency injection, post-pump state, custom theme data, dry-run previews, and font loading.

See also: [Sampling](sampling.md) · [Devices](devices.md) · [Reports](reports.md) · [CI integration](ci.md) · [Migration guide](migration.md) · [Home](index.md).

## Typed scenarios

A common case is **one widget rendered across several state-manager states**
(loading / loaded / error / empty from a Cubit, Bloc, Riverpod provider, or
`ChangeNotifier`). `MatrixScenario.typed<T>` attaches a compile-time-checked
`payload` to each scenario and feeds it to a builder you can reuse across all
of them — no stringly-typed `switch` on the scenario name, no per-scenario
`BlocProvider` boilerplate.

```dart
sealed class UserState { ... }   // your state-manager state

Widget buildUserList(UserState state) => BlocProvider<UserCubit>(
  create: (_) => UserCubit()..emit(state),
  child: const UserListScreen(),
);

matrixGolden(
  'UserList',
  scenarios: [
    MatrixScenario.typed('loading', payload: const UserState.loading(), builder: buildUserList),
    MatrixScenario.typed('loaded',  payload: UserState.loaded([alice, bob]), builder: buildUserList),
    MatrixScenario.typed('error',   payload: const UserState.error('Timeout'), builder: buildUserList),
    MatrixScenario.typed('empty',   payload: const UserState.empty(), builder: buildUserList),
  ],
  axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
);
```

`T` is inferred from `payload`/`builder` (write `MatrixScenario.typed<UserState>(...)`
to pin it). Each scenario can carry a different payload type — the typedness is
per-scenario, so it composes with every axis (themes × locales × devices × scales).

!!! note "Non-breaking"
    `MatrixScenario.typed` is additive — the plain `MatrixScenario(name, builder: () => widget)`
    constructor is unchanged. Internally the typed builder is wrapped into the
    zero-argument builder (it closes over the payload), so nothing else in the
    matrix changes. The payload is also exposed as `scenario.payload` (typed as
    `Object?`) for introspection.

### Mocks, GetIt, and per-combination setup

Each combination is its own `testWidgets` block, so `setUp`/`tearDown` run
per-combination (fresh mocks) and `setUpAll` runs once per matrix. That layers
cleanly with the typed builder, which is the right home for per-scenario stub
variations:

```dart
late MockUserRepository repo;

setUpAll(() => provideDummy<Either<Failure, List<User>>>(const Right([])));
setUp(() {
  repo = MockUserRepository();
  GetIt.I.registerSingleton<UserRepository>(repo);
});
tearDown(() => GetIt.I.reset());

Widget build(UserPayload p) {
  when(repo.fetchUsers()).thenAnswer((_) async =>
      p.error != null ? Left(Failure(p.error!)) : Right(p.users));
  return BlocProvider<UserCubit>(
    create: (_) => UserCubit(repo: repo)..loadUsers(),
    child: const UserListScreen(),
  );
}

matrixGolden('UserList', scenarios: [
  MatrixScenario.typed('loaded', payload: UserPayload(users: [alice, bob]), builder: build),
  MatrixScenario.typed('empty',  payload: const UserPayload(), builder: build),
  MatrixScenario.typed('error',  payload: const UserPayload(error: 'net'), builder: build),
]);
```

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

## Capture resolution (`captureScale`)

Goldens are captured at the device's **logical** size: a `phoneSmall`
(375×667 @ 2x) golden is a 375×667 PNG. `MatrixDevice.pixelRatio` drives layout
and `MediaQuery` — not the file's resolution (see
[Devices](devices.md#what-pixelratio-does-and-does-not)).

Pass `captureScale` when you want a denser raster — supersampled marketing
shots, or reviewing fine detail:

```dart
matrixGolden(
  'Hero',
  scenarios: [...],
  axes: const MatrixAxes(devices: [MatrixDevice.phoneSmall]),
  captureScale: 2.0,   // 750×1334 instead of 375×667
);
```

Same parameter on `screenMatrixGolden()`. In component mode the equivalent is
`componentMatrixGolden(pixelRatio: ...)`, which also defaults to `1.0` — both
levels write logical-size goldens unless you ask for more.

!!! warning "Changing the scale invalidates existing goldens"
    The comparator fails on differing dimensions before it ever compares
    pixels (`image sizes do not match`), so regenerate with
    `flutter test --update-goldens`. The scale is deliberately **not** part of
    the golden path — two calls that write the same path with different scales
    will fight over the file.

File size scales with the square of the value: `captureScale: 3.0` is ~9× the
pixels. Raise it for the handful of goldens that need it, not matrix-wide.

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

To preview a `componentMatrixGolden` call instead, pass `component: true`. Component paths carry no device segment and the `devices` axis is collapsed to its first value, so the counts and paths only match the real run with that flag set:

```dart
previewMatrixGolden(
  name: 'PrimaryButton',
  scenarios: [MatrixScenario('default', builder: () => const PrimaryButton())],
  component: true,
);
// -> goldens/primarybutton/default/light_en_ltr_1x.png   (no device)
```

The runners no longer wait for you to ask: `matrixGolden`, `screenMatrixGolden` and `componentMatrixGolden` all print a warning while registering tests when a configuration produces no combinations at all, or when two combinations claim the same golden file.

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

!!! note "Variable fonts and font failures (since 1.1.2)"
    Fonts whose filename contains `[` / `]` (`Geist[wght].ttf` — the variable-font
    convention) now load: `loadAppFonts()` retries the percent-decoded asset key
    that `flutter_tools` double-encodes. And if a family still fails, it is
    skipped with a warning instead of throwing out of `testExecutable` and
    failing the entire test file before any test runs.
    See [Font namespacing](font-namespacing.md#variable-fonts-with-brackets-in-the-filename).
