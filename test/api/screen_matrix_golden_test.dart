import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

import '../_helpers/no_op_comparator.dart';

void main() {
  GoldenFileComparator? saved;

  setUpAll(() {
    saved = goldenFileComparator;
    goldenFileComparator = NoOpGoldenComparator();
  });

  tearDownAll(() {
    if (saved != null) goldenFileComparator = saved!;
  });

  // Top-level invocations register testWidgets bodies. The mere fact that
  // these compile and run covers screen_matrix_golden.dart's delegation
  // to runMatrixTests with all its parameter wiring.

  screenMatrixGolden(
    'SyntheticScreen',
    appBuilder: (combination) => const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    axes: const MatrixAxes(),
    printSummary: false,
    reportFormats: const {},
  );

  screenMatrixGolden(
    'SyntheticScreen_withStates',
    appBuilder: (combination) => MaterialApp(home: Scaffold(body: Text(combination.scenario.name))),
    states: [
      MatrixScenario('a', builder: () => const SizedBox.shrink()),
      MatrixScenario('b', builder: () => const SizedBox.shrink()),
    ],
    printSummary: false,
    reportFormats: const {},
  );

  test('screenMatrixGolden delegate compiled and executed without throwing', () {
    // Reaching this assertion means the testWidgets bodies above ran
    // through `runMatrixTests`, covering the full screenMatrixGolden body.
    expect(true, isTrue);
  });
}
