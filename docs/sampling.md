# Sampling

Sampling strategies let `golden_matrix` shrink a full axis matrix to a smaller, deterministic subset — trading exhaustive coverage for fast CI without changing your test declaration.

A full matrix grows combinatorially: scenarios × themes × locales × text scales × devices. Two scenarios across two themes, two locales, two scales, and two devices is already 32 golden files. Sampling caps that explosion while keeping the same `matrixGolden` / `screenMatrixGolden` call — you only add a `sampling:` argument.

All sampling is **deterministic**: the same axes and strategy always select the same combinations, so baselines stay stable across runs and machines.

## Strategies

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

### `full` — default Cartesian product

Every combination of every axis value. This is the default when no `sampling:` is passed. Use it for the canonical, exhaustive baseline you trust on the main branch.

### `smoke` — base combo + one delta per axis

Takes the base combination, then varies exactly one axis at a time. Collapses a 32-combo matrix to roughly 5. Fastest path to "does it render at all" coverage.

### `pairwise` — all parameter pairs

Covers every pair of parameter values across axes with the minimal number of test cases. Catches most cross-axis interaction bugs (e.g. dark theme × RTL locale) without the full product — for example 270 combinations collapse to about 30.

### `priorityBased` — high-value first, capped

Orders combinations by value and keeps the top `maxCombinations`. Use when you have a hard budget on how many goldens CI may render and want the most important ones first.

!!! note
    `maxCombinations` only applies to `priorityBased` — it sets the cap on how many combinations survive sampling.

## When to reach for each

| Goal | Strategy |
| --- | --- |
| Canonical, exhaustive baseline | `full` |
| Fast smoke check on every push | `smoke` |
| Catch cross-axis interaction bugs cheaply | `pairwise` |
| Hard cap on golden count | `priorityBased` + `maxCombinations` |

!!! tip
    A common split: `full` on the main branch / nightly, `smoke` or `pairwise` on PR builds. Same declaration, different `sampling:` per branch — see [CI integration](ci.md).

## Presets

Presets bundle axes and a sampling strategy so common setups are one argument:

```dart
matrixGolden('Widget', scenarios: [...], preset: MatrixPreset.componentSmoke);
matrixGolden('Widget', scenarios: [...], preset: MatrixPreset.componentFull);
screenMatrixGolden('Screen', appBuilder: ..., preset: MatrixPreset.screenSmoke);
```

- `MatrixPreset.componentSmoke` — quick component coverage.
- `MatrixPreset.componentFull` — full component coverage.
- `MatrixPreset.screenSmoke` — quick screen-level coverage for `screenMatrixGolden`.

## Estimate before you commit

Before adding a new axis or switching strategies, use the dry-run preview to see exactly how many combinations a strategy yields — including the sampled list and golden paths — without rendering anything. See [Advanced](advanced.md).

## Related

- [Devices](devices.md)
- [Reports](reports.md)
- [CI integration](ci.md)
- [Advanced](advanced.md)
- [Migration guide](migration.md)
- [Home](index.md)
