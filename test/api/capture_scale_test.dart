import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

import '../_helpers/capturing_comparator.dart';

/// The capture scale decides the **resolution of the PNG on disk**, which is
/// invisible to every other assertion in this suite: content renders the same
/// at 1× and 3×, so only the raster dimensions can catch a regression.
///
/// `MatrixDevice.pixelRatio` deliberately does *not* affect it — it configures
/// layout and MediaQuery. Screen-level captures scale via `captureScale`
/// (default 1.0, opt-in); component-level captures scale via
/// `componentMatrixGolden`'s own `pixelRatio` — also 1.0 by default since
/// 1.3.0, so both levels write logical-size goldens unless asked otherwise.
void main() {
  final capture = CapturingGoldenComparator();
  GoldenFileComparator? saved;
  setUpAll(() {
    saved = goldenFileComparator;
    goldenFileComparator = capture;
  });
  tearDownAll(() {
    if (saved != null) goldenFileComparator = saved!;
  });

  // A device whose own pixelRatio is deliberately > 1 so the tests prove that
  // capture scale is driven by captureScale alone, not by the device.
  const device = MatrixDevice(name: 'tiny', logicalSize: Size(60, 40), pixelRatio: 3.0);
  const axes = MatrixAxes(devices: [device]);

  Widget filled() => const ColoredBox(color: Color(0xFF00FF00));

  // -- Screen level: matrixGolden / screenMatrixGolden --

  matrixGolden(
    'cap',
    scenarios: [MatrixScenario('default_scale', builder: filled)],
    axes: axes,
    detectStaleGoldens: false,
    printSummary: false,
  );
  test('matrixGolden captures at the logical size by default, ignoring device pixelRatio', () {
    expect(capture.sizeOf('default_scale'), (width: 60, height: 40));
  });

  matrixGolden(
    'cap',
    scenarios: [MatrixScenario('scaled_2x', builder: filled)],
    axes: axes,
    captureScale: 2.0,
    detectStaleGoldens: false,
    printSummary: false,
  );
  test('matrixGolden captureScale: 2.0 doubles the raster', () {
    expect(capture.sizeOf('scaled_2x'), (width: 120, height: 80));
  });

  screenMatrixGolden(
    'cap_screen',
    states: [MatrixScenario('screen_3x', builder: filled)],
    axes: axes,
    captureScale: 3.0,
    appBuilder: (combination) => MaterialApp(home: filled()),
    detectStaleGoldens: false,
    printSummary: false,
  );
  test('screenMatrixGolden captureScale: 3.0 triples the raster', () {
    expect(capture.sizeOf('screen_3x'), (width: 180, height: 120));
  });

  matrixGolden(
    'cap',
    scenarios: [MatrixScenario('fractional', builder: filled)],
    axes: axes,
    captureScale: 1.5,
    detectStaleGoldens: false,
    printSummary: false,
  );
  test('a fractional captureScale is honoured', () {
    expect(capture.sizeOf('fractional'), (width: 90, height: 60));
  });

  // -- Component level: componentMatrixGolden's own pixelRatio --

  Widget box() =>
      const SizedBox(width: 20, height: 10, child: ColoredBox(color: Color(0xFFFF0000)));

  componentMatrixGolden(
    'cap_component',
    scenarios: [MatrixScenario('component_default', builder: box)],
    axes: const MatrixAxes(),
    padding: EdgeInsets.zero,
    detectStaleGoldens: false,
    printSummary: false,
  );
  test('componentMatrixGolden captures at the logical size by default (pixelRatio 1.0)', () {
    expect(capture.sizeOf('component_default'), (width: 20, height: 10));
  });

  componentMatrixGolden(
    'cap_component',
    scenarios: [MatrixScenario('component_2x', builder: box)],
    axes: const MatrixAxes(),
    padding: EdgeInsets.zero,
    pixelRatio: 2.0,
    detectStaleGoldens: false,
    printSummary: false,
  );
  test('componentMatrixGolden pixelRatio: 2.0 doubles the raster', () {
    expect(capture.sizeOf('component_2x'), (width: 40, height: 20));
  });

  componentMatrixGolden(
    'cap_component',
    scenarios: [MatrixScenario('component_padded', builder: box)],
    axes: const MatrixAxes(),
    padding: const EdgeInsets.all(5),
    pixelRatio: 2.0,
    detectStaleGoldens: false,
    printSummary: false,
  );
  test('component padding is included before scaling', () {
    expect(capture.sizeOf('component_padded'), (width: 60, height: 40));
  });

  // -- Validation --

  test('matrixGolden rejects a non-positive captureScale', () {
    expect(
      () => matrixGolden(
        'cap_invalid',
        scenarios: [MatrixScenario('s', builder: filled)],
        captureScale: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => matrixGolden(
        'cap_invalid',
        scenarios: [MatrixScenario('s', builder: filled)],
        captureScale: -1,
      ),
      throwsArgumentError,
    );
  });

  test('componentMatrixGolden rejects a non-positive pixelRatio', () {
    expect(
      () => componentMatrixGolden(
        'cap_invalid',
        scenarios: [MatrixScenario('s', builder: box)],
        pixelRatio: 0,
      ),
      throwsArgumentError,
    );
  });
}
