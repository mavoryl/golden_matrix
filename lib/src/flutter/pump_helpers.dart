import 'package:flutter_test/flutter_test.dart';

import 'package:golden_matrix/src/models/matrix_device.dart';

/// Helpers for configuring the test view and pumping widgets.
class PumpHelpers {
  /// Configures the test view to match the given device.
  ///
  /// Sets physical size (logical × pixelRatio) and device pixel ratio
  /// on [tester.view].
  static void configureView(WidgetTester tester, MatrixDevice device) {
    tester.view.physicalSize = device.logicalSize * device.pixelRatio;
    tester.view.devicePixelRatio = device.pixelRatio;
  }

  /// Resets the test view to default values.
  static void resetView(WidgetTester tester) {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }
}
