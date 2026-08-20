import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

import '../_helpers/no_op_comparator.dart';

/// Two runs whose names slug to the same thing write the same report files.
/// Nothing used to notice: whichever teardown ran last overwrote the other's
/// report, and the missing one looked like a run that had never happened.
void main() {
  // See duplicate_path_preflight_test.dart — the binding must own debugPrint
  // before anything captures it, or restoring trips the foundation-vars check.
  TestWidgetsFlutterBinding.ensureInitialized();

  GoldenFileComparator? saved;
  setUpAll(() {
    saved = goldenFileComparator;
    goldenFileComparator = NoOpGoldenComparator();
  });
  tearDownAll(() {
    if (saved != null) goldenFileComparator = saved!;
  });

  Widget tinyBox() =>
      const SizedBox(width: 8, height: 8, child: ColoredBox(color: Color(0xFF00FF00)));

  // The warning is emitted while the groups are declared, so the capture wraps
  // the declarations themselves.
  final warnings = <String>[];
  final original = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) warnings.add(message);
  };
  matrixGolden(
    'Report/Name',
    scenarios: [MatrixScenario('s', builder: tinyBox)],
    printSummary: false,
  );
  matrixGolden(
    'Report Name',
    scenarios: [MatrixScenario('s', builder: tinyBox)],
    printSummary: false,
  );
  debugPrint = original;

  test('a second run claiming the same report file names is called out', () {
    expect(
      warnings.join('\n'),
      allOf(
        contains('golden_matrix'),
        contains('matrixgolden__report_name_report.*'),
        contains('matrixGolden: Report/Name'),
        contains('matrixGolden: Report Name'),
      ),
    );
  });
}
