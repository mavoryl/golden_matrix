import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

void main() {
  Widget placeholder() => const SizedBox();

  group('MatrixCombination', () {
    test('stores all fields correctly', () {
      final scenario = MatrixScenario('loading', builder: placeholder);
      const theme = MatrixTheme.dark;
      const locale = Locale('ru');
      const textScale = 2.0;
      const device = MatrixDevice.phoneLarge;
      const direction = TextDirection.ltr;

      final combo = MatrixCombination(
        scenario: scenario,
        theme: theme,
        locale: locale,
        textScale: textScale,
        device: device,
        direction: direction,
      );

      expect(combo.scenario.name, 'loading');
      expect(combo.theme.name, 'dark');
      expect(combo.locale, const Locale('ru'));
      expect(combo.textScale, 2.0);
      expect(combo.device.name, 'phoneLarge');
      expect(combo.direction, TextDirection.ltr);
    });

    test('toString provides readable output', () {
      final combo = MatrixCombination(
        scenario: MatrixScenario('test', builder: placeholder),
        theme: MatrixTheme.light,
        locale: const Locale('en'),
        textScale: 1.0,
        device: MatrixDevice.phoneSmall,
        direction: TextDirection.ltr,
      );

      final str = combo.toString();
      expect(str, contains('test'));
      expect(str, contains('light'));
      expect(str, contains('en'));
    });

    test('copyWith with no args returns equivalent combination', () {
      final combo = MatrixCombination(
        scenario: MatrixScenario('s', builder: placeholder),
        theme: MatrixTheme.light,
        locale: const Locale('en'),
        textScale: 1.0,
        device: MatrixDevice.phoneSmall,
        direction: TextDirection.ltr,
      );
      final copy = combo.copyWith();
      expect(copy.scenario, combo.scenario);
      expect(copy.theme, combo.theme);
      expect(copy.locale, combo.locale);
      expect(copy.textScale, combo.textScale);
      expect(copy.device, combo.device);
      expect(copy.direction, combo.direction);
    });

    test('copyWith overrides only specified fields', () {
      final combo = MatrixCombination(
        scenario: MatrixScenario('s', builder: placeholder),
        theme: MatrixTheme.light,
        locale: const Locale('en'),
        textScale: 1.0,
        device: MatrixDevice.phoneSmall,
        direction: TextDirection.ltr,
      );
      final flipped = combo.copyWith(direction: TextDirection.rtl, device: MatrixDevice.ipadPro13);
      expect(flipped.direction, TextDirection.rtl);
      expect(flipped.device, MatrixDevice.ipadPro13);
      expect(flipped.scenario, combo.scenario);
      expect(flipped.theme, combo.theme);
      expect(flipped.locale, combo.locale);
      expect(flipped.textScale, combo.textScale);
    });
  });

  group('MatrixScenario', () {
    test('slug is lowercased and sanitized', () {
      final scenario = MatrixScenario('Error State', builder: placeholder);
      expect(scenario.slug, 'error_state');
    });

    test('tags are preserved', () {
      final scenario = MatrixScenario('test', builder: placeholder, tags: ['error', 'network']);
      expect(scenario.tags, ['error', 'network']);
    });

    test('equality by name; identical names → equal hashCode', () {
      final a = MatrixScenario('foo', builder: placeholder);
      final b = MatrixScenario('foo', builder: placeholder);
      final c = MatrixScenario('bar', builder: placeholder);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a, a); // identity branch
    });

    test('toString contains the scenario name', () {
      expect(MatrixScenario('checkout', builder: placeholder).toString(), contains('checkout'));
    });

    test('empty name fails the assertion', () {
      expect(() => MatrixScenario('', builder: placeholder), throwsA(isA<AssertionError>()));
    });
  });

  group('MatrixTheme', () {
    test('light and dark have correct names', () {
      expect(MatrixTheme.light.name, 'light');
      expect(MatrixTheme.dark.name, 'dark');
    });

    test('custom theme stores ThemeData', () {
      final theme = MatrixTheme.custom('brand', ThemeData(primarySwatch: Colors.red));
      expect(theme.name, 'brand');
      expect(theme.themeData, isNotNull);
    });

    test('resolve returns correct ThemeData', () {
      expect(MatrixTheme.light.resolve().brightness, Brightness.light);
      expect(MatrixTheme.dark.resolve().brightness, Brightness.dark);
    });

    test('data is null by default', () {
      expect(MatrixTheme.light.data, isNull);
      expect(MatrixTheme.dark.data, isNull);
      final custom = MatrixTheme.custom('brand', ThemeData.light());
      expect(custom.data, isNull);
    });

    test('data stores arbitrary object', () {
      final config = {'primary': 'red', 'accent': 'blue'};
      final theme = MatrixTheme.custom('brand', ThemeData.light(), data: config);
      expect(theme.data, config);
      expect((theme.data as Map)['primary'], 'red');
    });

    test('slug is sanitized', () {
      final theme = MatrixTheme.custom('My Theme!', ThemeData.light());
      expect(theme.slug, 'my_theme_');
    });

    test('equality by name; identical names → equal hashCode', () {
      final a = MatrixTheme.custom('brand', ThemeData.light());
      final b = MatrixTheme.custom('brand', ThemeData.dark());
      final c = MatrixTheme.custom('other', ThemeData.light());
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(MatrixTheme.light, MatrixTheme.light); // identity branch
    });

    test('toString contains the theme name', () {
      expect(MatrixTheme.custom('brand', ThemeData.light()).toString(), contains('brand'));
    });

    test('isDark via ThemeData brightness', () {
      final custom = MatrixTheme.custom('whatever', ThemeData.dark());
      expect(custom.isDark, isTrue);
      final light = MatrixTheme.custom('whatever', ThemeData.light());
      expect(light.isDark, isFalse);
    });

    test('empty custom name fails the assertion', () {
      expect(() => MatrixTheme.custom('', ThemeData.light()), throwsA(isA<AssertionError>()));
    });
  });

  group('MatrixDevice', () {
    test('presets have correct sizes', () {
      expect(MatrixDevice.phoneSmall.logicalSize, const Size(375, 667));
      expect(MatrixDevice.phoneLarge.logicalSize, const Size(414, 896));
      expect(MatrixDevice.tablet.logicalSize, const Size(768, 1024));
    });

    test('slug is lowercased', () {
      expect(MatrixDevice.phoneSmall.slug, 'phonesmall');
      expect(MatrixDevice.androidMedium.slug, 'androidmedium');
    });

    test('equality by name; identical names → equal hashCode', () {
      const a = MatrixDevice(name: 'custom', logicalSize: Size(100, 200), pixelRatio: 2);
      const b = MatrixDevice(name: 'custom', logicalSize: Size(400, 800), pixelRatio: 3);
      expect(a, b); // name-based equality even if other fields differ
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(MatrixDevice.phoneSmall));
      expect(MatrixDevice.phoneSmall, MatrixDevice.phoneSmall); // identity branch
    });

    test('toString includes name and logical size', () {
      final str = MatrixDevice.phoneSmall.toString();
      expect(str, contains('phoneSmall'));
      expect(str, contains('375'));
      expect(str, contains('667'));
    });

    test('empty name fails the assertion', () {
      expect(
        () => MatrixDevice(name: '', logicalSize: const Size(100, 100)),
        throwsA(isA<AssertionError>()),
      );
    });

    test('non-positive pixelRatio fails the assertion', () {
      expect(
        () => MatrixDevice(name: 'x', logicalSize: const Size(100, 100), pixelRatio: 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => MatrixDevice(name: 'x', logicalSize: const Size(100, 100), pixelRatio: -1),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
