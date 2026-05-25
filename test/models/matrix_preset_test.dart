import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

void main() {
  group('MatrixPreset', () {
    test('componentSmoke has light and dark themes', () {
      expect(MatrixPreset.componentSmoke.axes.themes.length, 2);
      expect(MatrixPreset.componentSmoke.sampling, MatrixSampling.smoke);
    });

    test('componentFull has full sampling', () {
      expect(MatrixPreset.componentFull.sampling, MatrixSampling.full);
      expect(MatrixPreset.componentFull.axes.themes.length, 2);
      expect(MatrixPreset.componentFull.axes.locales.length, 2);
      expect(MatrixPreset.componentFull.axes.textScales.length, 2);
      expect(MatrixPreset.componentFull.axes.devices.length, 2);
    });

    test('screenSmoke has smoke sampling and 2 devices', () {
      expect(MatrixPreset.screenSmoke.sampling, MatrixSampling.smoke);
      expect(MatrixPreset.screenSmoke.axes.devices.length, 2);
      expect(MatrixPreset.screenSmoke.axes.locales.length, 2);
    });

    test('custom preset preserves values', () {
      const custom = MatrixPreset(
        axes: MatrixAxes(locales: [Locale('en'), Locale('ru'), Locale('ar')]),
        sampling: MatrixSampling.priorityBased,
      );

      expect(custom.axes.locales.length, 3);
      expect(custom.sampling, MatrixSampling.priorityBased);
      expect(custom.rules, isEmpty);
    });
  });
}
