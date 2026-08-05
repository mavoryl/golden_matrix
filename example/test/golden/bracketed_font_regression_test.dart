import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression guard for the 1.1.2 font fix.
///
/// `example/pubspec.yaml` declares `assets/fonts/Bracketed[wght].ttf` — square
/// brackets are the upstream naming convention for variable fonts
/// (`Geist[wght].ttf`, `Inter[opsz,wght].ttf`). `flutter_tools` percent-encodes
/// that key in `FontManifest.json`, and `PlatformAssetBundle.load` encodes
/// whatever key it is handed *again*, so passing the manifest key straight
/// through asks for `%255B` and misses. `loadAppFonts()` retries with the
/// percent-decoded key.
///
/// Before 1.1.2 this file could not even be *loaded*: the exception escaped
/// `loadAppFonts()` in `flutter_test_config.dart`, failing every test in the
/// directory. So both the load-time survival and the rendering below are part
/// of what is being guarded.
///
/// `loadAppFonts()` runs in `flutter_test_config.dart`.
void main() {
  const family = 'BracketedVariable';
  const text = 'iiiiiiii';
  const fontSize = 20.0;
  const ahemWidth = text.length * fontSize; // Ahem draws every glyph as a square.

  testWidgets('a font whose filename contains brackets renders real glyphs', (tester) async {
    Future<double> widthOf(String? fontFamily) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: Text(
              text,
              key: key,
              style: TextStyle(fontFamily: fontFamily, fontSize: fontSize),
            ),
          ),
        ),
      );
      return tester.getSize(find.byKey(key)).width;
    }

    final ahem = await widthOf(null);
    final bracketed = await widthOf(family);

    expect(
      ahem,
      ahemWidth,
      reason: 'baseline: an unloaded family falls back to Ahem, one square per glyph',
    );
    expect(
      bracketed,
      lessThan(ahemWidth * 0.6),
      reason:
          'equal to the Ahem width means "$family" never loaded — '
          'the percent-decoded retry in loadFontAsset() is gone or unwired',
    );
  });

  test('the manifest key for a bracketed asset needs decoding to resolve', () async {
    final manifest = json.decode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;

    final assets = <String>[
      for (final dynamic entry in manifest)
        if ((entry as Map<String, dynamic>)['family'] == family)
          for (final dynamic font in entry['fonts'] as List<dynamic>)
            (font as Map<String, dynamic>)['asset'] as String,
    ];

    expect(assets, hasLength(1), reason: 'the fixture font must be in the manifest');
    final asset = assets.single;
    printOnFailure('FontManifest.json key: $asset');

    Object? rawError;
    try {
      await rootBundle.load(asset);
    } on Object catch (error) {
      rawError = error;
    }

    if (rawError == null) {
      // Upstream fixed the double encoding — the raw key now resolves. Nothing
      // to do: loadFontAsset() tries the raw key first, so the retry simply
      // stops being exercised. Left as an observation rather than a failure.
      printOnFailure('raw manifest key resolved — upstream double-encoding is gone');
      return;
    }

    expect(asset, contains('%5B'), reason: 'the raw key only fails because it is encoded');
    final decoded = await rootBundle.load(Uri.decodeFull(asset));
    expect(
      decoded.lengthInBytes,
      greaterThan(0),
      reason: 'the decoded key is what load() re-encodes into the on-disk name',
    );
  });
}
