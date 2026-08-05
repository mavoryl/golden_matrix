# Font namespacing in self-tests

!!! success "Handled automatically since 1.1.1"
    `loadAppFonts()` now reads your package name from `pubspec.yaml` and also
    registers each bundled **text** family under its `packages/<pkg>/<family>`
    alias — so a package that references its own fonts with the prefix renders
    correctly in its own test suite with **no extra setup**. Just call
    `loadAppFonts()`. The rest of this page explains the underlying mismatch and
    the manual workaround needed on older versions.

`loadAppFonts()` reads the family names Flutter wrote into `FontManifest.json` — but a **package that references its own fonts with the `packages/<name>/` prefix** asks for a family name that the manifest does not contain when the package tests itself. This page explains why that mismatch happens, how to recognize it, and how to fix it.

## The symptom

You call `loadAppFonts()` in `flutter_test_config.dart`, yet your goldens still render text as Ahem squares (or in the wrong typeface) — only inside the **package's own** test suite. The same widgets render correctly when the package is consumed by an app. Icons may also be missing.

The tell: text geometry is wrong even though `loadAppFonts()` ran without error and the font files are clearly bundled.

## Why it happens

Flutter namespaces a package's fonts with a `packages/<package_name>/` prefix **only when that package is a dependency of another app**. A package referencing its own bundled font must therefore hardcode the prefixed family name so it resolves in consumer apps:

```dart
// lib/src/tokens.dart — referenced by the package's widgets AND its public API
static const String fontDisplay = 'packages/ui_kit/BrandSans';
```

But when the package runs **its own** `flutter test`, it is the root project, not a dependency. The generated manifest lists the fonts with their **bare** family names and **un-prefixed** asset paths:

```json
// build/unit_test_assets/FontManifest.json (package testing itself)
[
  { "family": "BrandSans",
    "fonts": [ { "asset": "fonts/BrandSans-Medium.ttf", "weight": 500 } ] }
]
```

`loadAppFonts()` registers exactly what the manifest says — the family `BrandSans`. Its `derivedFontFamily()` helper only re-applies the `packages/<pkg>/` prefix when the **asset path** starts with `packages/...`. Here the asset path is `fonts/BrandSans-Medium.ttf`, so no prefix is added.

The result is a name mismatch:

| Side | Family name |
| --- | --- |
| `loadAppFonts()` registers | `BrandSans` |
| Widget / theme requests | `packages/ui_kit/BrandSans` |

Flutter finds no match for the requested name and falls back to the font's fallback chain — Ahem (or Roboto) in a test — so glyphs and metrics are wrong.

!!! note "This is specific to a package testing itself"
    Inside a **consumer app's** test suite the manifest asset paths *are*
    `packages/ui_kit/fonts/...`, so `derivedFontFamily()` produces
    `packages/ui_kit/BrandSans` and everything matches. The break only occurs
    when the package that *owns* the prefixed font name is the root project
    under test.

## How to confirm it

1. Inspect the generated manifest and the family name your widgets request:

    ```bash
    find build .dart_tool -name FontManifest.json -exec cat {} \;
    grep -rn "packages/<your_package>/" lib/
    ```

    If the manifest shows a bare family (`"family": "BrandSans"`) while your
    code requests `packages/<pkg>/BrandSans`, that is the mismatch.

2. The names won't line up: manifest family ≠ requested family.

## The fix

**On 1.1.1+ there is nothing to do — just call `loadAppFonts()`.** It reads the
root package name from `pubspec.yaml` and registers every bundled text family
under *both* its bare name and its `packages/<pkg>/<family>` alias, so whichever
name your widgets request resolves. Icon families (`MaterialIcons`, etc.) are not
aliased; pass `loadAppFonts(iconFonts: false)` if you want the text fix without
also loading Material icons.

```dart
// test/flutter_test_config.dart — 1.1.1+
import 'dart:async';
import 'package:golden_matrix/golden_matrix.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadAppFonts();
  return testMain();
}
```

### Manual workaround (older versions)

If you're pinned to an older `golden_matrix`, register the fonts under the
**same prefixed names your widgets request** by loading the files directly
instead of relying on the manifest-derived names, in `flutter_test_config.dart`:

```dart
// test/flutter_test_config.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Load the package's own fonts under their `packages/<pkg>/` family names —
/// the names the widgets/theme actually request — by reading the TTFs from
/// disk. `loadAppFonts()` cannot do this in a self-test because the manifest
/// lists the families un-prefixed.
Future<void> _loadOwnFonts() async {
  const families = <String, List<String>>{
    'packages/ui_kit/BrandSans': [
      'fonts/BrandSans-Medium.ttf',
      'fonts/BrandSans-SemiBold.ttf',
      'fonts/BrandSans-Bold.ttf',
    ],
    'packages/ui_kit/BrandSerif': ['fonts/BrandSerif-Regular.ttf'],
    'packages/ui_kit/BrandMono': ['fonts/BrandMono-Regular.ttf'],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      final bytes = File(path).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await _loadOwnFonts();
  return testMain();
}
```

!!! tip "Keep `loadAppFonts()` for icons and Roboto"
    The custom loader only covers your prefixed text families. `loadAppFonts()`
    additionally pulls **MaterialIcons** and **Roboto** from the Flutter SDK
    cache, so Material icons render as real glyphs instead of empty boxes.
    Call both — they register disjoint families and don't conflict:

    ```dart
    Future<void> testExecutable(FutureOr<void> Function() testMain) async {
      await loadAppFonts();   // MaterialIcons + Roboto from the SDK
      await _loadOwnFonts();  // packages/<pkg>/... text families
      return testMain();
    }
    ```

### Alternatives

- **Drop the prefix in the package's own code.** If your widgets referenced the
  bare family (`'BrandSans'`), `loadAppFonts()` would match in the self-test —
  but then the fonts would *not* resolve in consumer apps, where the prefix is
  required. Not recommended for a published UI package.
- **Move goldens into an `example/` app** that depends on the package. There the
  manifest is correctly prefixed and `loadAppFonts()` alone works — at the cost
  of testing through an extra app target.

## A font asset that cannot be loaded at all

!!! success "No longer fatal since 1.1.2"
    Up to 1.1.1 a single unloadable font asset threw out of `loadAppFonts()`.
    Because it is awaited in `flutter_test_config.dart`, that failed the **whole
    test file at load time** — every golden in it, including the ones that never
    touch the font. Since 1.1.2 the family is skipped, a warning is printed, and
    the rest of the suite runs.

The common trigger is a **variable font whose filename contains square
brackets** — the upstream naming convention (`Geist[wght].ttf`,
`Inter[opsz,wght].ttf`, `Roboto[wdth,wght].ttf`). `[` and `]` are URI
gen-delims, so the key that reaches `FontManifest.json` is percent-encoded
(`Geist%5Bwght%5D.ttf`) while the file on disk keeps its literal name, and the
`AssetBundle` lookup misses:

```
Unable to load asset: "packages/shadcn_ui/fonts/Geist%5Bwght%5D.ttf".
The asset does not exist or has empty data.
```

On 1.1.2+ you get this instead, and the suite keeps going:

```
golden_matrix: skipped font family "Geist" (packages/shadcn_ui/fonts/Geist[wght].ttf):
Unable to load asset: ... Goldens that use it fall back to another font.
```

What to do about the missing typeface itself:

- **Accept the fallback.** If the font is a transitive dependency you don't
  render with, the warning is all you need.
- **Load the file yourself**, bypassing `AssetBundle` — the same
  `File(...).readAsBytes()` + `FontLoader.addFont` pattern as the
  [manual loader above](#manual-workaround-older-versions), pointed at the real
  path on disk. This works
  because the encoding problem lives in the asset-key lookup, not in the file.
- **Pin the dependency** to a version that ships static font weights.

!!! note "The encoding half is not golden_matrix's"
    The percent-encoded key comes out of `flutter_tools`; a retry with
    `Uri.decodeFull()` does not help, since `PlatformAssetBundle.load()`
    re-encodes it. Tracked in `KNOWN_ISSUES.md` in the repository.

## See also

- [Advanced](advanced.md) — the `## Font loading` section and `loadAppFonts()` options
- [Migration guide](migration.md)
- [CI integration](ci.md)
- [Home](index.md)
