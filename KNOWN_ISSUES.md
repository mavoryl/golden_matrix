# Known Issues

## Golden capture ignores `MatrixDevice.pixelRatio` (captures at 1.0)

**Version:** 1.1.1
**Reported:** 2026-08-01 (found while building the achievement_companion marketing-golden harness)
**Severity:** medium — blocks supersampled/high-DPR golden output

### Symptom

A `MatrixDevice` with `pixelRatio: 2.0` and `logicalSize: Size(1920, 1080)` produces a golden PNG of **1920×1080**, not the expected **3840×2160**. The device's `pixelRatio` has no effect on the captured image dimensions — output is always `logicalSize × 1.0`.

### Root cause (suspected)

`PumpHelpers.configureView` sets `tester.view.physicalSize = logicalSize × pixelRatio` and `tester.view.devicePixelRatio = pixelRatio` (see `lib/src/flutter/pump_helpers.dart:12-13`), so layout/MediaQuery see the right DPR. But the actual capture — `matchesGoldenFile(find.byKey(_goldenBoundaryKey))` in `lib/src/api/matrix_test_runner.dart` (~line 252/289) — rasterizes the `RepaintBoundary` at Flutter's default layer pixel ratio (1.0), not at `view.devicePixelRatio`. So the on-disk PNG is the logical size, and `pixelRatio` only influences layout, never resolution.

### Impact

Consumers wanting crisp/supersampled goldens (e.g. marketing screenshots rendered at 2× then downscaled) cannot get them via `pixelRatio` — the captured file is already at logical resolution with nothing to downscale.

### Workaround

Set `pixelRatio: 1.0` and treat the logical size as the final output resolution. For achievement_companion the target (1920×1080, Steam store) equals the logical size, so this is acceptable — just no supersampling.

### Confirmed mechanism

`matchesGoldenFile(Finder)` goes through flutter_test's `captureImage()`, which walks up to the nearest repaint boundary and calls `layer.toImage(renderObject.paintBounds)` — and `OffsetLayer.toImage` defaults to `pixelRatio: 1.0`. The DPR transform lives in `RenderView`, *above* our boundary (`matrix_test_runner.dart:222`), so it never enters the captured layer. Capturing at logical size is also what golden_toolkit/alchemist do; this is a convention, not a regression.

### Possible fix (for later) — must be opt-in

Rasterize via `RenderRepaintBoundary.toImage(pixelRatio: ...)` and hand the `Future<ui.Image>` to `matchesGoldenFile` (the matcher accepts images, not just finders).

Design constraints found while analysing this:

- **Do not re-purpose `MatrixDevice.pixelRatio`.** Every built-in preset declares 2.0–4.0 (`matrix_device.dart:91-275`); honoring it at capture time would grow every consumer's PNGs 4–16× in area and require regenerating every golden. That is a major release with a migration, for a behavior most users don't want.
- Prefer an orthogonal, default-1.0 `captureScale` on `matrixGolden()` / `screenMatrixGolden()`, plus explicit docs that `pixelRatio` affects layout/MediaQuery only.
- **Four call sites, not two:** `matrix_test_runner.dart:252,289` *and* `component_matrix_golden.dart:237,265`.
- `RenderRepaintBoundary.toImage()` inside a widget test lives in a fake-async zone and usually needs `tester.runAsync`; prototype before committing to the approach.

## `loadAppFonts` aborts the whole suite when one font asset has URI-unsafe characters (`[`, `]`)

**Version:** 1.1.1
**Reported:** 2026-08-04 (found while upgrading achievement_companion to Flutter 3.44.8 / Dart 3.12.2)
**Severity:** high — a single unloadable font asset in *any* dependency fails **every** test file that calls `loadAppFonts()`
**Status: FIXED in 1.1.2** — both halves. The font itself now loads (`loadFontAsset` retries the percent-**decoded** key), and any font that still fails is isolated to its own family instead of killing the test file (`loadFontRegistrations`).

> **Correction to the original analysis below:** it claimed a `Uri.decodeFull` retry cannot work because `PlatformAssetBundle.load` re-encodes the key. That is wrong — re-encoding is exactly what makes it work. Measured on a purpose-built repro (Flutter 3.44.8), see [Verified behavior](#verified-behavior).

### Symptom

A dependency ships a variable font whose filename contains square brackets — the convention for variable fonts, e.g. `Geist[wght].ttf`. Every test file whose `flutter_test_config.dart` calls `loadAppFonts()` then fails **at load time**, before a single test runs:

```
Failed to load ".../test/marketing/hero_golden_test.dart":
Unable to load asset: "packages/shadcn_ui/fonts/Geist%5Bwght%5D.ttf".
The asset does not exist or has empty data.
package:flutter/src/services/asset_bundle.dart 340:7      PlatformAssetBundle.load
package:golden_matrix/src/flutter/font_loader.dart 90:37  loadAppFonts
===== asynchronous gap ===========================
test/marketing/flutter_test_config.dart 9:3               testExecutable
```

Reproduced with `shadcn_ui: 0.56.0` (0.54+ replaced 9 static Geist weights with `fonts/Geist[wght].ttf` + `fonts/GeistMono[wght].ttf`), Flutter 3.44.8, golden_matrix 1.1.1. Downgrading to `shadcn_ui: 0.53.6` (static weights, no brackets) makes it go away.

### Root cause

Two independent parts, only the second of which golden_matrix owns:

1. **Not ours — the asset key is URI-encoded before it reaches us.** The `%5B`/`%5D` are already present in the key golden_matrix reads out of `FontManifest.json`. Note the error message prints the *unencoded* argument: `PlatformAssetBundle.load` builds its platform message via `utf8.encode(Uri(path: Uri.encodeFull(key)).path)` but reports the failure through `_errorSummaryWithKey(key)` (`asset_bundle.dart:328-343`) — so a `%5B` in the message means it was in the manifest entry itself, not added by `load()`. `[` and `]` are URI gen-delims, so they get percent-encoded somewhere on the `asset path → Uri → manifest string` path in `flutter_tools`, while the file on disk is still literally named `Geist[wght].ttf`. The lookup therefore misses.

   ~~Consequence worth noting: this makes the asset effectively unreachable through `AssetBundle` in the test harness, so a "retry with `Uri.decodeFull(asset)`" fallback does **not** help — the decoded key is re-encoded by `Uri.encodeFull` inside `load()` and misses again.~~

   **Wrong on two counts** (see [Verified behavior](#verified-behavior)): the file on disk under `flutter test` is *also* named with the encoding (`Geist%5Bwght%5D.ttf`), and the re-encoding inside `load()` is precisely what makes a decoded-key retry succeed. The real defect is **double encoding**: an already-encoded manifest key becomes `%255B` and matches nothing.

2. **Ours — no error isolation.** `loadAppFonts` (`lib/src/flutter/font_loader.dart:86-93`) loops over every registration and awaits `fontLoader.load()` with no guard. One unloadable asset — in a transitive dependency the consumer doesn't control — throws out of `loadAppFonts`, which is awaited in `flutter_test_config.dart`'s `testExecutable`. A throw there fails the **entire test file at load time**, so tests that never render that font die too.

### Impact

In achievement_companion this took out all 10 marketing golden files at once (`hero_golden_test.dart`, `platinum_golden_test.dart`, `showcase_golden_test.dart`, `store_capsules_golden_test.dart`, fixtures, …) — none of which use Geist directly; they only share a `flutter_test_config.dart`. Blast radius is the whole suite, and the error text points at the consumer's test file rather than at the offending dependency, which makes it read like a project bug.

Variable fonts with bracketed filenames are the upstream naming convention (`Inter[opsz,wght].ttf`, `Roboto[wdth,wght].ttf`), so more packages will hit this as they migrate.

### Verified behavior

Measured 2026-08-05 on Flutter 3.44.8 with a purpose-built repro: a package `dep_pkg` declaring `fonts/Dep[wght].ttf`, consumed by an app `bracket_probe` that also declares its own `fonts/Root[wght].ttf` (both files are copies of SDK Roboto).

`FontManifest.json` as generated:

```json
[{"family":"RootFont","fonts":[{"asset":"fonts/Root%5Bwght%5D.ttf"}]},
 {"family":"packages/dep_pkg/DepFont","fonts":[{"asset":"packages/dep_pkg/fonts/Dep%5Bwght%5D.ttf"}]}]
```

| Attempt | Result |
| --- | --- |
| `rootBundle.load('fonts/Root%5Bwght%5D.ttf')` (the manifest key) | **fails** — `Unable to load asset` |
| `rootBundle.load('fonts/Root[wght].ttf')` (decoded key) | **works** — 171676 bytes |
| same pair for the `packages/dep_pkg/…` asset | identical outcome |

The file on disk under `flutter test` is **also** percent-encoded — `build/unit_test_assets/fonts/Root%5Bwght%5D.ttf` exists, `…/Root[wght].ttf` does not. So `Uri.encodeFull` inside `load()` is not the enemy; it is what turns the decoded key back into the on-disk name. Feeding the manifest key straight through double-encodes it to `%255B`.

End-to-end through `loadAppFonts()` after the 1.1.2 fix, text width of `'iiiiiiii'` at `fontSize: 20`:

| Family | Width | Meaning |
| --- | --- | --- |
| (none → Ahem) | 160.0 | placeholder squares |
| `RootFont` | 38.83 | project-level bracketed font renders |
| `packages/dep_pkg/DepFont` | 38.83 | dependency's bracketed font renders |
| `packages/bracket_probe/RootFont` | 38.83 | the self-test alias renders |

No warnings emitted — the retry path resolves everything.

### Workaround (consumer side, pre-1.1.2)

Pin the dependency to a version that ships static font files (achievement_companion holds `shadcn_ui: 0.53.6` for this reason, documented in its `pubspec.yaml`). On 1.1.2+ the pin can be lifted.

### Fix (shipped in 1.1.2)

1. ~~**Degrade gracefully.**~~ **Done in 1.1.2** — `loadFontRegistrations` (`lib/src/flutter/font_loader.dart`) performs the planned registrations one by one, catching per family, warning once per unique asset list (a family and its `packages/<root>/` alias share assets, so one broken file produced two warnings in the naive version), and returning only the families that loaded. The `register` callback is injected, which is what makes the failure path unit-testable — `rootBundle` is not reachable from a test otherwise. Original sketch:

   ```dart
   for (final reg in registrations) {
     try {
       final fontLoader = FontLoader(reg.family);
       for (final asset in reg.assets) {
         fontLoader.addFont(rootBundle.load(asset));
       }
       await fontLoader.load();
       loadedFamilies.add(reg.family);   // only on success
     } on Object catch (e) {
       debugPrint(
         'golden_matrix: could not load font family "${reg.family}" '
         '(${reg.assets.join(", ")}): $e. Goldens using it will fall back to '
         'another font. If the asset name contains "[" or "]", see KNOWN_ISSUES.md.',
       );
     }
   }
   ```

   Note `loadedFamilies.add` must move *after* a successful `load()` — otherwise a failed `Roboto`/`MaterialIcons` registration suppresses the SDK fallbacks that follow.

2. **Retry with the percent-decoded key.** **Done in 1.1.2** — `loadFontAsset` (`lib/src/flutter/font_loader.dart`) tries the manifest key first and, on failure, retries `Uri.decodeFull(asset)`; `load()`'s own `Uri.encodeFull` then reproduces the on-disk name exactly. Cheap, needs no knowledge of the project layout, and leaves the working path untouched. A key that is not valid percent-encoding (a literal `%` in the filename) surfaces the original asset error rather than an `ArgumentError` from the decoder.

   Rejected alternative: bypass `AssetBundle` and read the file with `File(...).readAsBytes()` (the pattern `_loadRobotoFromSdk` uses), resolving `packages/<pkg>/<path>` through `.dart_tool/package_config.json`, or reading `build/unit_test_assets/<key>` directly. Both work in principle but depend on `flutter_tools` layout details that are not a public contract — unnecessary now that the decoded key resolves through the normal bundle.

3. **Document it.** Done in 1.1.2 — `docs/font-namespacing.md` gained a "Variable fonts with brackets in the filename" section; `docs/advanced.md` links to it from the font-loading section.

### Upstream

Still worth a `flutter/flutter` issue: **the asset key in `FontManifest.json` is percent-encoded, but every consumer of that key passes it to `AssetBundle.load`, which encodes it a second time** — so a font declared as `fonts/Test[wght].ttf` is unreachable through the key the framework itself published. Either the manifest should carry the raw path or `load()` should not re-encode.

Minimal repro (built and confirmed on 3.44.8): a package declaring `fonts/Test[wght].ttf` in `pubspec.yaml`, plus a test that reads the manifest and calls `rootBundle.load(assetKeyFromManifest)` — fails, while `rootBundle.load(Uri.decodeFull(assetKeyFromManifest))` succeeds.

Open question before filing: whether release builds behave the same. Only the test harness (`build/unit_test_assets/…`) was measured here; the engine-side asset lookup in a real app may decode differently, which would make this test-only. Worth checking, since `Text(style: TextStyle(fontFamily: …))` in a real app never touches the manifest key — the engine resolves the family — so a release-mode repro needs an explicit `rootBundle.load` of the font asset.
