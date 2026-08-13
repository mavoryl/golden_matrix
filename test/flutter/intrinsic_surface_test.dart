import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';
import 'package:golden_matrix/src/flutter/capture_strategy.dart';

/// `pixelRatio` is documented as capture *density* — how many physical pixels
/// each logical pixel becomes in the PNG. It used to quietly also shrink the
/// space the widget had to lay itself out in: `tester.view.physicalSize` is in
/// physical pixels, so a fixed 800×800 meant 400×400 logical at ratio 2.0 and
/// ~267×267 at 3.0. A component wider than that was silently squeezed, and the
/// golden recorded the squeezed version.
MatrixCombination _combo(Widget Function() builder) => MatrixCombination(
      scenario: MatrixScenario('wide', builder: builder),
      theme: MatrixTheme.light,
      locale: const Locale('en'),
      textScale: 1.0,
      device: MatrixDevice.phoneSmall,
      direction: TextDirection.ltr,
    );

void main() {
  Widget wide() => const SizedBox(width: 500, height: 20);

  Future<Size> layoutAt(WidgetTester tester, double pixelRatio) async {
    final strategy = IntrinsicCaptureStrategy(
      pixelRatio: pixelRatio,
      padding: EdgeInsets.zero,
      extraLocalizationsDelegates: const [],
      freezeAnimations: false,
    );
    strategy.configureView(tester, _combo(wide));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(strategy.build(_combo(wide)));
    await tester.pumpAndSettle();
    return tester.getSize(find.byKey(strategy.boundaryKey));
  }

  group('the intrinsic layout surface is independent of pixelRatio', () {
    testWidgets('a 500pt widget lays out at 500pt at ratio 1.0', (tester) async {
      expect((await layoutAt(tester, 1.0)).width, 500);
    });

    testWidgets('and still at 500pt at ratio 2.0', (tester) async {
      expect((await layoutAt(tester, 2.0)).width, 500);
    });

    testWidgets('and at ratio 3.0, where the old surface left only ~267pt', (tester) async {
      expect((await layoutAt(tester, 3.0)).width, 500);
    });

    testWidgets('the logical surface stays 800pt at every ratio', (tester) async {
      for (final ratio in [1.0, 2.0, 3.0]) {
        final strategy = IntrinsicCaptureStrategy(
          pixelRatio: ratio,
          padding: EdgeInsets.zero,
          extraLocalizationsDelegates: const [],
          freezeAnimations: false,
        );
        strategy.configureView(tester, _combo(wide));

        expect(
          tester.view.physicalSize.width / tester.view.devicePixelRatio,
          IntrinsicCaptureStrategy.surface.width,
          reason: 'ratio $ratio changed the logical space the widget gets',
        );
      }

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    });
  });
}
