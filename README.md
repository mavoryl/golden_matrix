# golden_matrix

[![pub package](https://img.shields.io/pub/v/golden_matrix.svg)](https://pub.dev/packages/golden_matrix)
[![test](https://github.com/mavoryl/golden_matrix/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/mavoryl/golden_matrix/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/mavoryl/golden_matrix/branch/main/graph/badge.svg)](https://codecov.io/gh/mavoryl/golden_matrix)

Matrix-based visual regression testing for Flutter. Declare themes, locales,
devices, text scales — get all combinations, sampled if you want, with
HTML + JUnit reports for CI.

**[📖 Docs](https://mavoryl.github.io/golden_matrix/)** ·
[Quick start](https://mavoryl.github.io/golden_matrix/#quick-start) ·
[CI integration](https://mavoryl.github.io/golden_matrix/ci/) ·
[Migrating from golden_toolkit](https://mavoryl.github.io/golden_matrix/migration/)

## Install

```yaml
# pubspec.yaml
dev_dependencies:
  golden_matrix: ^0.19.2
```

```dart
// test/flutter_test_config.dart — load real fonts for text rendering
import 'dart:async';
import 'package:golden_matrix/golden_matrix.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadAppFonts();
  return testMain();
}
```

## 30-second example

```dart
import 'package:flutter/widgets.dart';
import 'package:golden_matrix/golden_matrix.dart';

void main() {
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
  // 2 scenarios × 2 themes × 2 locales × 2 scales × 2 devices = 32 golden files
}
```

```bash
flutter test --update-goldens  # generate baselines
flutter test                   # run regression tests
```

## What's in the box

- **Declarative matrix** — themes × locales × devices × text scales × directions, all combinations automatically
- **Three entry points** — `matrixGolden` (components), `screenMatrixGolden` (full screens), `componentMatrixGolden` (intrinsic-size primitives)
- **Sampling** — `full`, `smoke`, `pairwise`, `priorityBased` to keep CI fast
- **HTML / JSON / Markdown / JUnit XML reports** — with inline pixel-diff thumbnails on failure
- **Stale + overflow detection** — orphan goldens and `RenderFlex overflow` surface automatically
- **RTL auto-inference** for Arabic / Hebrew / Farsi
- **20+ device presets** — modern iPhones, Android, foldables, full iPad lineup, plus custom devices
- **DI-friendly** — `wrapApp` / `wrapChild` hooks for Riverpod / Bloc / Provider
- **Dry-run preview** — inspect counts, paths, and collisions without rendering
- **Zero external dependencies** — only the Flutter SDK

**[Read the full docs →](https://mavoryl.github.io/golden_matrix/)**

## Requirements

- Flutter SDK >= 3.16.0
- Dart SDK >= 3.2.0

## License

MIT
