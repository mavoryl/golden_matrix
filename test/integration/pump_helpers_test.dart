import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

void main() {
  group('PumpHelpers integration', () {
    testWidgets('configureView sets correct physical size', (tester) async {
      const device = MatrixDevice.phoneLarge; // 414x896, 3.0x

      PumpHelpers.configureView(tester, device);

      expect(tester.view.physicalSize, const Size(414 * 3.0, 896 * 3.0));
      expect(tester.view.devicePixelRatio, 3.0);

      PumpHelpers.resetView(tester);
    });

    testWidgets('configureView works for tablet', (tester) async {
      const device = MatrixDevice.tablet; // 768x1024, 2.0x

      PumpHelpers.configureView(tester, device);

      expect(tester.view.physicalSize, const Size(768 * 2.0, 1024 * 2.0));
      expect(tester.view.devicePixelRatio, 2.0);

      PumpHelpers.resetView(tester);
    });

    testWidgets('resetView restores defaults after configuration', (tester) async {
      final defaultSize = tester.view.physicalSize;
      final defaultDpr = tester.view.devicePixelRatio;

      PumpHelpers.configureView(tester, MatrixDevice.phoneLarge);

      // Should be different from default
      expect(tester.view.physicalSize, isNot(equals(defaultSize)));

      PumpHelpers.resetView(tester);

      // Should be back to default
      expect(tester.view.physicalSize, defaultSize);
      expect(tester.view.devicePixelRatio, defaultDpr);
    });

    testWidgets('multiple configure-reset cycles work correctly', (tester) async {
      final defaultSize = tester.view.physicalSize;

      for (final device in [
        MatrixDevice.phoneSmall,
        MatrixDevice.phoneLarge,
        MatrixDevice.tablet,
        MatrixDevice.androidSmall,
      ]) {
        PumpHelpers.configureView(tester, device);
        expect(tester.view.physicalSize, device.logicalSize * device.pixelRatio);
        expect(tester.view.devicePixelRatio, device.pixelRatio);
        PumpHelpers.resetView(tester);
      }

      expect(tester.view.physicalSize, defaultSize);
    });

    testWidgets('view state does not leak between testWidgets - part 1', (tester) async {
      PumpHelpers.configureView(tester, MatrixDevice.tablet);
      expect(tester.view.devicePixelRatio, 2.0);
      PumpHelpers.resetView(tester);
    });

    testWidgets('view state does not leak between testWidgets - part 2', (tester) async {
      // If part 1 leaked state, this would fail
      final defaultDpr = tester.view.devicePixelRatio;
      expect(defaultDpr, isNot(equals(2.0)), reason: 'View state leaked from previous test');
    });
  });
}
