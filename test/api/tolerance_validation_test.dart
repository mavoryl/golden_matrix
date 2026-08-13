import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

void main() {
  Widget box() => const SizedBox(width: 10, height: 10);

  // NaN slips through a `tolerance < 0.0 || tolerance > 1.0` guard because every
  // comparison with NaN is false. It then poisons the comparison itself:
  // `diffPercent <= NaN` is false for any diff, so every golden fails with no
  // hint as to why.
  group('tolerance rejects non-finite values', () {
    test('matrixGolden rejects NaN', () {
      expect(
        () => matrixGolden(
          'tol_nan',
          scenarios: [MatrixScenario('s', builder: box)],
          tolerance: double.nan,
        ),
        throwsArgumentError,
      );
    });

    test('matrixGolden rejects infinity', () {
      expect(
        () => matrixGolden(
          'tol_inf',
          scenarios: [MatrixScenario('s', builder: box)],
          tolerance: double.infinity,
        ),
        throwsArgumentError,
      );
    });

    test('matrixGolden still rejects out-of-range values', () {
      expect(
        () => matrixGolden(
          'tol_range',
          scenarios: [MatrixScenario('s', builder: box)],
          tolerance: 1.5,
        ),
        throwsArgumentError,
      );
    });

    test('componentMatrixGolden rejects NaN', () {
      expect(
        () => componentMatrixGolden(
          'tol_nan_component',
          scenarios: [MatrixScenario('s', builder: box)],
          tolerance: double.nan,
        ),
        throwsArgumentError,
      );
    });

    test('screenMatrixGolden rejects NaN', () {
      expect(
        () => screenMatrixGolden(
          'tol_nan_screen',
          appBuilder: (_) => const MaterialApp(home: SizedBox()),
          tolerance: double.nan,
        ),
        throwsArgumentError,
      );
    });
  });
}
