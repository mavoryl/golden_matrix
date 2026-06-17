import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

import '../_helpers/local_no_op_comparator.dart';

/// When `reportDir` is omitted, reports must land in `<basedir>/goldens` —
/// the directory next to the golden PNGs, derived from the active
/// `LocalFileComparator.basedir`. This is the regression guard for tests
/// living in non-standard directories (e.g. `test/golden_component/`), which
/// previously dumped reports into a stray top-level `goldens/` because the
/// old `_findGoldensDir` heuristic only knew `test/`, `test/golden/`, and
/// `test/goldens/`.
void main() {
  GoldenFileComparator? saved;

  // Created before the synchronous group construction (matrixGolden /
  // componentMatrixGolden register their groups eagerly).
  final screenBase = Directory.systemTemp.createTempSync('rdef_screen_');
  final componentBase = Directory.systemTemp.createTempSync('rdef_component_');

  setUpAll(() {
    saved = goldenFileComparator;
  });

  tearDownAll(() {
    if (saved != null) goldenFileComparator = saved!;
    for (final d in [screenBase, componentBase]) {
      if (d.existsSync()) d.deleteSync(recursive: true);
    }
  });

  // Each group needs its comparator pointed at its own basedir. matrixGolden
  // installs its own setUp/tearDown, so set the comparator inside this
  // group's setUp before the runner's pump executes.
  bool exists(Directory base, String name) => File('${base.path}/goldens/$name').existsSync();

  group('screen/component matrixGolden', () {
    setUp(() {
      goldenFileComparator = LocalNoOpGoldenComparator(
        Uri.file('${screenBase.path}/widget_test.dart'),
      );
    });

    matrixGolden(
      'rdef',
      scenarios: [MatrixScenario('default', builder: () => const SizedBox.shrink())],
      axes: const MatrixAxes(),
      // reportDir omitted on purpose — exercises default resolution.
      detectStaleGoldens: false,
      printSummary: false,
    );

    test('omitted reportDir writes reports under <basedir>/goldens', () {
      expect(exists(screenBase, 'matrixgolden__rdef_report.json'), isTrue);
      expect(exists(screenBase, 'matrixgolden__rdef_report.html'), isTrue);
      expect(exists(screenBase, 'matrixgolden__rdef_report.md'), isTrue);
    });
  });

  group('componentMatrixGolden', () {
    setUp(() {
      goldenFileComparator = LocalNoOpGoldenComparator(
        Uri.file('${componentBase.path}/widget_test.dart'),
      );
    });

    componentMatrixGolden(
      'cdef',
      scenarios: [
        MatrixScenario(
          's',
          builder: () =>
              const SizedBox(width: 20, height: 20, child: ColoredBox(color: Color(0xFF00FF00))),
        ),
      ],
      axes: const MatrixAxes(),
      // reportDir omitted on purpose.
      detectStaleGoldens: false,
      printSummary: false,
    );

    test('omitted reportDir writes component reports under <basedir>/goldens', () {
      expect(exists(componentBase, 'componentmatrixgolden__cdef_report.json'), isTrue);
      expect(exists(componentBase, 'componentmatrixgolden__cdef_report.html'), isTrue);
      expect(exists(componentBase, 'componentmatrixgolden__cdef_report.md'), isTrue);
    });
  });
}
