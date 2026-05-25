import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

void main() {
  group('MatrixAxes', () {
    test('default values', () {
      const axes = MatrixAxes();

      expect(axes.themes.length, 1);
      expect(axes.themes.first.name, 'light');
      expect(axes.locales.length, 1);
      expect(axes.locales.first, const Locale('en'));
      expect(axes.textScales.length, 1);
      expect(axes.textScales.first, 1.0);
      expect(axes.devices.length, 1);
      expect(axes.devices.first.name, 'phoneSmall');
      expect(axes.directions, isEmpty);
    });

    test('custom values are preserved', () {
      const axes = MatrixAxes(
        themes: [MatrixTheme.light, MatrixTheme.dark],
        locales: [Locale('en'), Locale('ru'), Locale('ar')],
        textScales: [1.0, 1.5, 2.0],
        devices: [MatrixDevice.phoneSmall, MatrixDevice.tablet],
        directions: [TextDirection.ltr, TextDirection.rtl],
      );

      expect(axes.themes.length, 2);
      expect(axes.locales.length, 3);
      expect(axes.textScales.length, 3);
      expect(axes.devices.length, 2);
      expect(axes.directions.length, 2);
    });
  });

  group('MatrixAxes.copyWith', () {
    test('no args returns equal-shaped axes', () {
      const original = MatrixAxes(
        themes: [MatrixTheme.light, MatrixTheme.dark],
        locales: [Locale('en'), Locale('ru')],
      );
      final copy = original.copyWith();
      expect(copy.themes, original.themes);
      expect(copy.locales, original.locales);
      expect(copy.textScales, original.textScales);
      expect(copy.devices, original.devices);
      expect(copy.directions, original.directions);
    });

    test('overrides only specified fields', () {
      const original = MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]);
      final copy = original.copyWith(devices: const [MatrixDevice.tablet, MatrixDevice.ipadPro13]);

      expect(copy.themes, original.themes);
      expect(copy.locales, original.locales);
      expect(copy.devices, [MatrixDevice.tablet, MatrixDevice.ipadPro13]);
    });

    test('append-via-copyWith pattern works', () {
      const original = MatrixAxes();
      final extended = original.copyWith(devices: [...original.devices, MatrixDevice.ipadPro13]);
      expect(extended.devices.length, 2);
      expect(extended.devices.last, MatrixDevice.ipadPro13);
    });
  });
}
