import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/src/flutter/font_loader.dart';

void main() {
  group('namespacedAlias', () {
    test('prefixes a bare text family with the root package', () {
      expect(namespacedAlias('BrandSans', 'ui_kit', isIcon: false), 'packages/ui_kit/BrandSans');
    });

    test('returns null for icon families', () {
      expect(namespacedAlias('MaterialIcons', 'ui_kit', isIcon: true), isNull);
    });

    test('returns null for already-prefixed families', () {
      expect(namespacedAlias('packages/other/Foo', 'ui_kit', isIcon: false), isNull);
    });

    test('returns null for overridable system fonts', () {
      expect(namespacedAlias('Roboto', 'ui_kit', isIcon: false), isNull);
    });

    test('returns null when family is empty or root package is null/empty', () {
      expect(namespacedAlias('', 'ui_kit', isIcon: false), isNull);
      expect(namespacedAlias('BrandSans', null, isIcon: false), isNull);
      expect(namespacedAlias('BrandSans', '', isIcon: false), isNull);
    });
  });

  group('planFontRegistrations', () {
    Map<String, dynamic> entry(String family, List<String> assets) => {
          'family': family,
          'fonts': assets.map((a) => {'asset': a}).toList(),
        };

    List<String> familiesOf(
      Iterable<dynamic> manifest, {
      bool textFonts = true,
      bool iconFonts = true,
      String? rootPackage,
    }) =>
        planFontRegistrations(
          manifest,
          textFonts: textFonts,
          iconFonts: iconFonts,
          rootPackage: rootPackage,
        ).map((r) => r.family).toList();

    test('bare text family gets both the bare name and the packages/<root> alias', () {
      final manifest = [
        entry('BrandSans', ['fonts/BrandSans-Medium.ttf']),
      ];
      final plan = planFontRegistrations(
        manifest,
        textFonts: true,
        iconFonts: true,
        rootPackage: 'ui_kit',
      );
      expect(plan.map((r) => r.family), ['BrandSans', 'packages/ui_kit/BrandSans']);
      expect(plan.first.assets, ['fonts/BrandSans-Medium.ttf']);
      expect(plan.last.assets, ['fonts/BrandSans-Medium.ttf']);
    });

    test('no alias without a root package', () {
      final manifest = [
        entry('BrandSans', ['fonts/BrandSans-Medium.ttf']),
      ];
      // rootPackage omitted → defaults to null.
      expect(familiesOf(manifest), ['BrandSans']);
    });

    test('icon families are not aliased', () {
      final manifest = [
        entry('MaterialIcons', ['fonts/MaterialIcons-Regular.otf']),
      ];
      expect(familiesOf(manifest, rootPackage: 'ui_kit'), ['MaterialIcons']);
    });

    test('textFonts:false drops text families, iconFonts:false drops icons', () {
      final manifest = [
        entry('BrandSans', ['fonts/BrandSans.ttf']),
        entry('MaterialIcons', ['fonts/MaterialIcons.otf']),
      ];
      expect(
        familiesOf(manifest, iconFonts: false, rootPackage: 'ui_kit'),
        ['BrandSans', 'packages/ui_kit/BrandSans'],
      );
      expect(familiesOf(manifest, textFonts: false, rootPackage: 'ui_kit'), ['MaterialIcons']);
    });

    test('already-prefixed dependency family is kept once, not re-aliased', () {
      final manifest = [
        entry('packages/ui_kit/BrandSans', ['packages/ui_kit/fonts/BrandSans.ttf']),
      ];
      expect(familiesOf(manifest, rootPackage: 'ui_kit'), ['packages/ui_kit/BrandSans']);
    });

    test('skips entries with an empty family and de-duplicates', () {
      final manifest = [
        <String, dynamic>{'fonts': <dynamic>[]}, // no family → empty → skipped
        entry('BrandSans', ['fonts/BrandSans.ttf']),
        entry('BrandSans', ['fonts/BrandSans.ttf']), // dup family
      ];
      expect(
        familiesOf(manifest, rootPackage: 'ui_kit'),
        ['BrandSans', 'packages/ui_kit/BrandSans'],
      );
    });
  });

  group('rootPackageName', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('rootpkg_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    String write(String contents) {
      final f = File('${tmp.path}/pubspec.yaml')..writeAsStringSync(contents);
      return f.path;
    }

    test('reads the name key', () {
      final path = write('name: ui_kit\nversion: 1.0.0\n');
      expect(rootPackageName(pubspecPath: path), 'ui_kit');
    });

    test('handles a quoted name and ignores later keys', () {
      final path = write('description: "name: not_this"\nname: "my_pkg"\n');
      expect(rootPackageName(pubspecPath: path), 'my_pkg');
    });

    test('returns null when the file is missing', () {
      expect(rootPackageName(pubspecPath: '${tmp.path}/nope.yaml'), isNull);
    });

    test('returns null when there is no name key', () {
      final path = write('version: 1.0.0\n');
      expect(rootPackageName(pubspecPath: path), isNull);
    });
  });

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

  group('loadFontAsset', () {
    final bytes = ByteData(4);

    test('loads the manifest key as-is when it resolves', () async {
      final tried = <String>[];

      final data = await loadFontAsset(
        'fonts/BrandSans.ttf',
        load: (key) async {
          tried.add(key);
          return bytes;
        },
      );

      expect(data, same(bytes));
      expect(tried, ['fonts/BrandSans.ttf'], reason: 'no retry on the happy path');
    });

    test('retries with the percent-decoded key when the encoded one fails', () async {
      final tried = <String>[];

      final data = await loadFontAsset(
        'packages/shadcn_ui/fonts/Geist%5Bwght%5D.ttf',
        load: (key) async {
          tried.add(key);
          if (key.contains('%5B')) throw Exception('Unable to load asset: "$key"');
          return bytes;
        },
      );

      expect(data, same(bytes));
      expect(tried, [
        'packages/shadcn_ui/fonts/Geist%5Bwght%5D.ttf',
        'packages/shadcn_ui/fonts/Geist[wght].ttf',
      ]);
    });

    test('rethrows without retrying when the key has nothing to decode', () async {
      final tried = <String>[];

      await expectLater(
        loadFontAsset(
          'fonts/Missing.ttf',
          load: (key) async {
            tried.add(key);
            throw Exception('Unable to load asset: "$key"');
          },
        ),
        throwsA(isA<Exception>()),
      );
      expect(tried, ['fonts/Missing.ttf']);
    });

    test('propagates the failure when the decoded key fails too', () async {
      final tried = <String>[];

      await expectLater(
        loadFontAsset(
          'fonts/Geist%5Bwght%5D.ttf',
          load: (key) async {
            tried.add(key);
            throw Exception('Unable to load asset: "$key"');
          },
        ),
        throwsA(isA<Exception>()),
      );
      expect(tried, ['fonts/Geist%5Bwght%5D.ttf', 'fonts/Geist[wght].ttf']);
    });

    test('rethrows the original error when the key is not valid percent-encoding', () async {
      // Uri.decodeFull throws on a stray '%' — the retry must not mask the
      // real asset error with a FormatException.
      final tried = <String>[];

      await expectLater(
        loadFontAsset(
          'fonts/100%.ttf',
          load: (key) async {
            tried.add(key);
            throw Exception('Unable to load asset: "$key"');
          },
        ),
        throwsA(
          isA<Exception>().having((e) => e.toString(), 'message', contains('Unable to load asset')),
        ),
      );
      expect(tried, ['fonts/100%.ttf']);
    });
  });

  group('loadFontRegistrations', () {
    ({String family, List<String> assets}) reg(String family, List<String> assets) =>
        (family: family, assets: assets);

    test('returns every family when all registrations succeed', () async {
      final registered = <String>[];
      final warnings = <String>[];

      final loaded = await loadFontRegistrations(
        [
          reg('BrandSans', ['fonts/BrandSans.ttf']),
          reg('MaterialIcons', ['fonts/MaterialIcons.otf']),
        ],
        register: (family, assets) async => registered.add(family),
        onWarning: warnings.add,
      );

      expect(loaded, {'BrandSans', 'MaterialIcons'});
      expect(registered, ['BrandSans', 'MaterialIcons']);
      expect(warnings, isEmpty);
    });

    test('keeps going after a failing family and excludes it from the result', () async {
      final registered = <String>[];

      final loaded = await loadFontRegistrations(
        [
          reg('Geist', ['packages/shadcn_ui/fonts/Geist[wght].ttf']),
          reg('BrandSans', ['fonts/BrandSans.ttf']),
        ],
        register: (family, assets) async {
          if (family == 'Geist') throw Exception('Unable to load asset');
          registered.add(family);
        },
        onWarning: (_) {},
      );

      expect(loaded, {'BrandSans'});
      expect(registered, ['BrandSans'], reason: 'later families must still be registered');
    });

    test('a failed family is not reported as loaded, so SDK fallbacks still apply', () async {
      final loaded = await loadFontRegistrations(
        [
          reg('Roboto', ['fonts/Roboto-Regular.ttf']),
        ],
        register: (family, assets) async => throw Exception('boom'),
        onWarning: (_) {},
      );

      expect(loaded.contains('Roboto'), isFalse);
    });

    test('warns with the family, the assets and the bracket hint', () async {
      final warnings = <String>[];

      await loadFontRegistrations(
        [
          reg('Geist', ['packages/shadcn_ui/fonts/Geist[wght].ttf']),
        ],
        register: (family, assets) async => throw Exception('Unable to load asset'),
        onWarning: warnings.add,
      );

      expect(warnings, hasLength(1));
      expect(warnings.single, contains('golden_matrix'));
      expect(warnings.single, contains('Geist'));
      expect(warnings.single, contains('packages/shadcn_ui/fonts/Geist[wght].ttf'));
      expect(warnings.single, contains('Unable to load asset'));
      expect(warnings.single, contains('font-namespacing'));
    });

    test('warns once when the same assets fail under a family and its alias', () async {
      final warnings = <String>[];

      final loaded = await loadFontRegistrations(
        [
          reg('Geist', ['packages/shadcn_ui/fonts/Geist[wght].ttf']),
          reg('packages/ui_kit/Geist', ['packages/shadcn_ui/fonts/Geist[wght].ttf']),
        ],
        register: (family, assets) async => throw Exception('Unable to load asset'),
        onWarning: warnings.add,
      );

      expect(loaded, isEmpty);
      expect(warnings, hasLength(1), reason: 'one broken file → one warning');
    });

    test('defaults onWarning to debugPrint without throwing', () async {
      final lines = <String?>[];
      final original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => lines.add(message);
      addTearDown(() => debugPrint = original);

      final loaded = await loadFontRegistrations(
        [
          reg('Geist', ['fonts/Geist[wght].ttf']),
        ],
        register: (family, assets) async => throw Exception('nope'),
      );

      expect(loaded, isEmpty);
      expect(lines.single, contains('Geist'));
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
