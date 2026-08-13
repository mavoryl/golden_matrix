import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

import '../_helpers/no_op_comparator.dart';

/// Two combinations pointing at one golden file used to be a silent hazard:
/// only `previewMatrixGolden` could see it, and nobody runs a preview by
/// accident. The runners registered both tests, the second overwrote the
/// first's PNG, and the first combination was never really compared —
/// a green run that verified less than it claimed.
///
/// Both runners now share `MatrixRunPlan`, so both say it out loud.
void main() {
  // The binding replaces debugPrint with its own throttle-free override when it
  // first initializes. Doing that here, before anything captures debugPrint,
  // means the value we save and restore is the one flutter_test expects to find
  // at test time — otherwise restoring trips "a foundation debug variable was
  // changed by the test".
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

  // The warning is emitted while the group is being declared, so the capture
  // has to wrap the declaration itself — the runners cannot be called from
  // inside a test().
  List<String> captureDeclaration(void Function() declare) {
    final lines = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) lines.add(message);
    };
    declare();
    debugPrint = original;
    return lines;
  }

  final screenWarnings = captureDeclaration(() {
    matrixGolden(
      'dup_screen',
      scenarios: [MatrixScenario('s', builder: tinyBox)],
      axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
      // A builder that ignores the theme: both combinations claim one file.
      fileNameBuilder: (c) => 'goldens/dup_screen/${c.scenario.slug}.png',
      printSummary: false,
    );
  });

  test('matrixGolden warns when two combinations claim one golden', () {
    expect(
      screenWarnings.join('\n'),
      allOf(
        contains('golden_matrix'),
        contains('dup_screen'),
        contains('1 golden path(s)'),
        contains('goldens/dup_screen/s.png'),
      ),
    );
  });

  final componentWarnings = captureDeclaration(() {
    componentMatrixGolden(
      'dup_component',
      scenarios: [MatrixScenario('s', builder: tinyBox)],
      axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
      fileNameBuilder: (c) => 'goldens/dup_component/${c.scenario.slug}.png',
      printSummary: false,
    );
  });

  test('componentMatrixGolden warns about the same collision', () {
    expect(
      componentWarnings.join('\n'),
      allOf(contains('dup_component'), contains('1 golden path(s)')),
    );
  });

  final cleanWarnings = captureDeclaration(() {
    matrixGolden(
      'dup_none',
      scenarios: [MatrixScenario('s', builder: tinyBox)],
      axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
      detectStaleGoldens: false,
      printSummary: false,
    );
  });

  test('a run with distinct paths declares itself in silence', () {
    expect(cleanWarnings, isEmpty);
  });

  test('previewMatrixGolden can price a component run', () {
    // Before the shared plan, preview only ever built viewport paths, so a
    // component collision — two devices, no device segment — was invisible.
    final preview = previewMatrixGolden(
      name: 'dup_preview',
      scenarios: [MatrixScenario('s', builder: tinyBox)],
      axes: const MatrixAxes(devices: [MatrixDevice.tablet, MatrixDevice.phoneSmall]),
      component: true,
    );

    expect(preview.goldenPaths.single, 'goldens/dup_preview/s/light_en_ltr_1x.png');
    expect(preview.afterSamplingCount, 1, reason: 'the devices axis is collapsed');
    expect(preview.rawCount, 1);
  });
}
