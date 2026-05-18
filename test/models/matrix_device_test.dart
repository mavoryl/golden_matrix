import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

void main() {
  group('MatrixDevice presets', () {
    test('modern iPhone presets have realistic geometry', () {
      expect(MatrixDevice.iphone15Pro.logicalSize, const Size(393, 852));
      expect(MatrixDevice.iphone15Pro.pixelRatio, 3.0);
      expect(MatrixDevice.iphone16ProMax.logicalSize.width, 440);
    });

    test('modern Android presets have realistic geometry', () {
      expect(MatrixDevice.pixel8.logicalSize, const Size(412, 915));
      expect(MatrixDevice.pixel8Pro.logicalSize.width, 448);
      expect(MatrixDevice.galaxyS24.logicalSize, const Size(384, 832));
    });

    test('foldable Z Fold portrait vs unfolded width differs', () {
      expect(
        MatrixDevice.galaxyZFoldUnfolded.logicalSize.width,
        greaterThan(MatrixDevice.galaxyZFoldFolded.logicalSize.width),
      );
    });

    test('iPad presets are tablet-sized', () {
      expect(MatrixDevice.ipadMini.logicalSize, const Size(744, 1133));
      expect(MatrixDevice.ipadAir.logicalSize, const Size(820, 1180));
      expect(MatrixDevice.ipadPro11.logicalSize, const Size(834, 1194));
      expect(MatrixDevice.ipadPro13.logicalSize, const Size(1024, 1366));
    });

    test('iPad landscape swaps width and height', () {
      expect(
        MatrixDevice.ipadPro11Landscape.logicalSize,
        Size(MatrixDevice.ipadPro11.logicalSize.height, MatrixDevice.ipadPro11.logicalSize.width),
      );
      expect(
        MatrixDevice.ipadPro13Landscape.logicalSize,
        Size(MatrixDevice.ipadPro13.logicalSize.height, MatrixDevice.ipadPro13.logicalSize.width),
      );
    });

    test('preset names are unique', () {
      final all = [
        MatrixDevice.phoneSmall,
        MatrixDevice.phoneMedium,
        MatrixDevice.phoneLarge,
        MatrixDevice.androidSmall,
        MatrixDevice.androidMedium,
        MatrixDevice.tablet,
        MatrixDevice.tabletLandscape,
        MatrixDevice.iphone15Pro,
        MatrixDevice.iphone16ProMax,
        MatrixDevice.pixel8,
        MatrixDevice.pixel8Pro,
        MatrixDevice.galaxyS24,
        MatrixDevice.galaxyZFoldFolded,
        MatrixDevice.galaxyZFoldUnfolded,
        MatrixDevice.ipadMini,
        MatrixDevice.ipadAir,
        MatrixDevice.ipadPro11,
        MatrixDevice.ipadPro11Landscape,
        MatrixDevice.ipadPro13,
        MatrixDevice.ipadPro13Landscape,
      ];
      final names = all.map((d) => d.name).toSet();
      expect(names.length, all.length);
    });
  });

  group('MatrixDevice.copyWith', () {
    test('no args returns equal device', () {
      final c = MatrixDevice.ipadPro11.copyWith();
      expect(c, MatrixDevice.ipadPro11);
      expect(c.logicalSize, MatrixDevice.ipadPro11.logicalSize);
    });

    test('overrides only specified fields', () {
      final c = MatrixDevice.ipadPro11.copyWith(
        name: 'ipadPro11Custom',
        logicalSize: const Size(1194, 834),
      );
      expect(c.name, 'ipadPro11Custom');
      expect(c.logicalSize, const Size(1194, 834));
      expect(c.pixelRatio, MatrixDevice.ipadPro11.pixelRatio);
      expect(c.safeArea, MatrixDevice.ipadPro11.safeArea);
    });

    test('can override pixelRatio and safeArea independently', () {
      final c = MatrixDevice.pixel8.copyWith(pixelRatio: 3.0, safeArea: EdgeInsets.zero);
      expect(c.pixelRatio, 3.0);
      expect(c.safeArea, EdgeInsets.zero);
      expect(c.logicalSize, MatrixDevice.pixel8.logicalSize);
    });
  });
}
