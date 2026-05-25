import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/src/flutter/font_loader.dart';

void main() {
  group('derivedFontFamily', () {
    test('returns empty string when no family key', () {
      expect(derivedFontFamily(<String, dynamic>{}), '');
    });

    test('returns family verbatim for overridable system fonts', () {
      // _overridableFonts list inside font_loader.dart
      for (final name in [
        'Roboto',
        '.SF UI Display',
        '.SF UI Text',
        '.SF Pro Text',
        '.SF Pro Display',
      ]) {
        expect(derivedFontFamily(<String, dynamic>{'family': name, 'fonts': <dynamic>[]}), name);
      }
    });

    test('strips package prefix from family name when it maps to an overridable system font', () {
      // e.g. some pubspecs declare "packages/cupertino_icons/Roboto"
      expect(
        derivedFontFamily(<String, dynamic>{
          'family': 'packages/cupertino_icons/Roboto',
          'fonts': <dynamic>[],
        }),
        'Roboto',
      );
    });

    test('keeps prefixed family verbatim when last segment is not overridable', () {
      // Non-system font that happens to be packaged
      expect(
        derivedFontFamily(<String, dynamic>{
          'family': 'packages/my_pkg/CustomFont',
          'fonts': <dynamic>[],
        }),
        'packages/my_pkg/CustomFont',
      );
    });

    test('namespaces unprefixed family when any asset path starts with packages/', () {
      // e.g. ui_kit's "SF Pro Display" coming from packages/ui_kit/assets/...
      expect(
        derivedFontFamily({
          'family': 'BrandSans',
          'fonts': [
            {'asset': 'packages/ui_kit/assets/fonts/BrandSans-Regular.ttf'},
          ],
        }),
        'packages/ui_kit/BrandSans',
      );
    });

    test('returns family unchanged when no asset is package-prefixed', () {
      expect(
        derivedFontFamily({
          'family': 'AppFont',
          'fonts': [
            {'asset': 'assets/fonts/AppFont-Regular.ttf'},
          ],
        }),
        'AppFont',
      );
    });

    test('handles fonts entries with null asset', () {
      expect(
        derivedFontFamily({
          'family': 'AppFont',
          'fonts': [<String, dynamic>{}],
        }),
        'AppFont',
      );
    });
  });

  group('isIconFamily', () {
    test('returns true for well-known icon font families', () {
      for (final name in [
        'MaterialIcons',
        'CupertinoIcons',
        'FontAwesomeIcons',
        'MaterialSymbolsRounded',
        'MaterialSymbolsSharp',
        'MaterialSymbolsOutlined',
      ]) {
        expect(isIconFamily(name), isTrue, reason: 'should match $name');
      }
    });

    test('matches case-insensitively', () {
      expect(isIconFamily('materialicons'), isTrue);
      expect(isIconFamily('MATERIALICONS'), isTrue);
      expect(isIconFamily('material_symbols_outlined'), isTrue);
    });

    test('matches packaged icon families after the prefix', () {
      // Whatever ends up in family name string — substring match still works.
      expect(isIconFamily('packages/cupertino_icons/CupertinoIcons'), isTrue);
    });

    test('returns false for text-only font families', () {
      for (final name in [
        'Roboto',
        'Inter',
        '.SF Pro Text',
        '.SF UI Display',
        'Open Sans',
        'BrandSans',
        'AppFont',
      ]) {
        expect(isIconFamily(name), isFalse, reason: 'should NOT match $name');
      }
    });

    test('returns false for empty string', () {
      expect(isIconFamily(''), isFalse);
    });

    test('documented limitation: misses icon fonts without "icons"/"symbols"', () {
      // Real icon fonts that don't follow the convention.
      // This test pins the current behavior so a future change is intentional.
      expect(isIconFamily('Phosphor'), isFalse);
      expect(isIconFamily('FontAwesomeBrands'), isFalse);
      expect(isIconFamily('Lucide'), isFalse);
    });
  });

  group('loadAppFonts parameter wiring (compile-time)', () {
    // These checks verify the public API signature didn't drift.
    // Actual font-loading behavior is exercised by integration tests
    // via `test/integration/flutter_test_config.dart`.
    test('accepts textFonts named param', () {
      const Future<void> Function({bool textFonts, bool iconFonts}) ref = loadAppFonts;
      expect(ref, isNotNull);
    });
  });
}
