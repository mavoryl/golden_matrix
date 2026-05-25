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
}
