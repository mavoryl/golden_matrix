# Devices

Pick from 20+ built-in `MatrixDevice` presets, tweak one with `copyWith()`, or build a fully custom device — the device axis controls the viewport size and pixel ratio used to render each combination.

## Device Presets

### Generic size classes

| Preset | Logical size | Pixel ratio |
| --- | --- | --- |
| `MatrixDevice.phoneSmall` | 375x667 | 2.0x |
| `MatrixDevice.phoneMedium` | 390x844 | 3.0x |
| `MatrixDevice.phoneLarge` | 414x896 | 3.0x |
| `MatrixDevice.androidSmall` | 360x800 | 4.0x |
| `MatrixDevice.androidMedium` | 412x915 | 2.625x |

### Modern iPhones

| Preset | Logical size | Pixel ratio |
| --- | --- | --- |
| `MatrixDevice.iphone15Pro` | 393x852 | 3.0x |
| `MatrixDevice.iphone16ProMax` | 440x956 | 3.0x |

### Modern Android

| Preset | Logical size | Pixel ratio |
| --- | --- | --- |
| `MatrixDevice.pixel8` | 412x915 | 2.625x |
| `MatrixDevice.pixel8Pro` | 448x998 | 2.625x |
| `MatrixDevice.galaxyS24` | 384x832 | 3.0x |

### Foldables

| Preset | Logical size | Pixel ratio |
| --- | --- | --- |
| `MatrixDevice.galaxyZFoldFolded` | 374x882 | 3.0x |
| `MatrixDevice.galaxyZFoldUnfolded` | 716x882 | 2.625x |

### Tablets / iPad

| Preset | Logical size | Pixel ratio |
| --- | --- | --- |
| `MatrixDevice.tablet` | 768x1024 | 2.0x  (generic iPad portrait) |
| `MatrixDevice.tabletLandscape` | 1024x768 | 2.0x |
| `MatrixDevice.ipadMini` | 744x1133 | 2.0x |
| `MatrixDevice.ipadAir` | 820x1180 | 2.0x |
| `MatrixDevice.ipadPro11` | 834x1194 | 2.0x |
| `MatrixDevice.ipadPro11Landscape` | 1194x834 | 2.0x |
| `MatrixDevice.ipadPro13` | 1024x1366 | 2.0x |
| `MatrixDevice.ipadPro13Landscape` | 1366x1024 | 2.0x |

### Legacy named aliases

| Alias | Maps to |
| --- | --- |
| `MatrixDevice.iphoneSE` | `phoneSmall` |
| `MatrixDevice.iphone15` | `phoneMedium` |
| `MatrixDevice.iphone15ProMax` | `phoneLarge` |
| `MatrixDevice.galaxyS20` | `androidSmall` |
| `MatrixDevice.galaxyA51` | `androidMedium` |
| `MatrixDevice.ipadPortrait` | `tablet` |

## Custom devices

Build one fully from scratch:

```dart
MatrixDevice(name: 'pixel7', logicalSize: Size(412, 915), pixelRatio: 2.75)
```

## Tweaking a preset

Use `copyWith()` to derive a variant — e.g. force a custom name and rotate `ipadPro11` to landscape:

```dart
final landscape = MatrixDevice.ipadPro11.copyWith(
  name: 'ipadPro11Custom',
  logicalSize: const Size(1194, 834),
);
```

## `copyWith` on Models

`MatrixAxes`, `MatrixDevice`, and `MatrixCombination` expose `copyWith()` so you can derive a tweaked instance without re-declaring every field:

```dart
// Extend a preset's axes with one extra device
final axes = MatrixPreset.componentFull.axes.copyWith(
  devices: [...MatrixPreset.componentFull.axes.devices, MatrixDevice.ipadPro13],
);

// Flip a combination's direction or device in a one-off assertion
final rtl = combination.copyWith(direction: TextDirection.rtl);
```

!!! note "Intrinsic-size captures ignore the device axis"
    In `componentMatrixGolden` (see [Home](index.md)) the widget is anchored at its **natural** size, so the `devices` field of `MatrixAxes` is ignored and no device segment appears in the golden path.

## See also

- [Sampling](sampling.md) — control how many combinations across these device axes get rendered
- [Reports](reports.md)
- [CI integration](ci.md)
- [Advanced](advanced.md)
- [Migration guide](migration.md)
- [Home](index.md)
