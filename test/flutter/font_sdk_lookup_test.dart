import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

void main() {
  group('splitSearchPath', () {
    test('splits on the platform separator and drops empty entries', () {
      // Windows uses ';' and POSIX ':'; an empty entry means "current
      // directory" on POSIX and probing it for a Flutter SDK is noise.
      expect(splitSearchPath('/usr/bin:/opt/flutter/bin', separator: ':'), [
        '/usr/bin',
        '/opt/flutter/bin',
      ]);
      expect(splitSearchPath(r'C:\bin;C:\src\flutter\bin', separator: ';'), [
        r'C:\bin',
        r'C:\src\flutter\bin',
      ]);
      expect(splitSearchPath('/a::/b', separator: ':'), ['/a', '/b']);
    });

    test('a missing or empty PATH yields nothing', () {
      expect(splitSearchPath(null, separator: ':'), isEmpty);
      expect(splitSearchPath('', separator: ':'), isEmpty);
    });

    test('defaults to this platform separator', () {
      expect(
        splitSearchPath('a${Platform.isWindows ? ';' : ':'}b'),
        ['a', 'b'],
      );
    });
  });

  group('flutterExecutableNames', () {
    test('Windows launches through a batch file', () {
      // `which flutter` never existed on Windows, and neither does a
      // extension-less `flutter` binary — the launcher is `flutter.bat`.
      expect(flutterExecutableNames(windows: true), contains('flutter.bat'));
    });

    test('POSIX looks for the bare name', () {
      expect(flutterExecutableNames(windows: false), ['flutter']);
    });
  });

  group('flutterRootFromExecutable', () {
    test('the SDK root is the parent of bin/', () {
      final sep = Platform.pathSeparator;
      expect(
        flutterRootFromExecutable(['', 'opt', 'flutter', 'bin', 'flutter'].join(sep)),
        ['', 'opt', 'flutter'].join(sep),
      );
    });

    test('a Windows-shaped path resolves the same way', () {
      // The old code did `resolved.split('/bin/flutter').first`, which on
      // Windows never matched: the separators are backslashes and the launcher
      // is `flutter.bat`. It silently returned the whole path as the "root",
      // and every SDK font lookup below it missed.
      expect(
        flutterRootFromExecutable(r'C:\src\flutter\bin\flutter.bat', separator: r'\'),
        r'C:\src\flutter',
      );
    });

    test('an executable not inside a bin/ directory is not an SDK', () {
      expect(flutterRootFromExecutable('/usr/local/flutter', separator: '/'), isNull);
      expect(flutterRootFromExecutable('/opt/lib/flutter', separator: '/'), isNull);
    });

    test('a bare name has no root to speak of', () {
      expect(flutterRootFromExecutable('flutter', separator: '/'), isNull);
      expect(flutterRootFromExecutable('', separator: '/'), isNull);
    });
  });

  group('planFontRegistrations survives a manifest it did not expect', () {
    List<String> capture(void Function() body) {
      final lines = <String>[];
      final original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => lines.add(message ?? '');
      try {
        body();
      } finally {
        debugPrint = original;
      }
      return lines;
    }

    test('a malformed entry is skipped, not fatal for the whole file', () {
      // The casts used to run outside any per-family isolation, so one
      // unexpected FontManifest.json entry threw out of `flutter_test_config.dart`
      // and took down every test in the file — exactly the failure mode
      // loadFontRegistrations was written to prevent.
      late List<({List<String> assets, String family})> plan;
      final warnings = capture(() {
        plan = planFontRegistrations(
          [
            'not a map',
            {
              'family': 'Good',
              'fonts': [
                {'asset': 'fonts/Good.ttf'},
              ],
            },
            {'family': 'NoFontsKey'},
            {'family': 'BadFonts', 'fonts': 'not a list'},
            {
              'family': 'AlsoGood',
              'fonts': [
                {'asset': 'fonts/Also.ttf'},
              ],
            },
          ],
          textFonts: true,
          iconFonts: true,
        );
      });

      expect(plan.map((r) => r.family), containsAll(['Good', 'AlsoGood']));
      expect(plan.map((r) => r.family), isNot(contains('BadFonts')));
      expect(warnings.join('\n'), contains('golden_matrix'));
      expect(warnings.length, greaterThanOrEqualTo(2), reason: 'each bad entry says so');
    });

    test('an entry with no usable assets still registers its family', () {
      // A family with an empty `fonts` list is odd but not malformed, and
      // silently dropping it would hide a pubspec mistake.
      final plan = planFontRegistrations(
        [
          {'family': 'Empty', 'fonts': <dynamic>[]},
        ],
        textFonts: true,
        iconFonts: true,
      );

      expect(plan.single.family, 'Empty');
      expect(plan.single.assets, isEmpty);
    });

    test('a manifest that is not a list at all is reported, not thrown', () {
      late List<({List<String> assets, String family})> plan;
      final warnings = capture(() {
        plan = planFontRegistrations({'family': 'Object'}, textFonts: true, iconFonts: true);
      });

      expect(plan, isEmpty);
      expect(warnings.single, contains('FontManifest.json'));
    });
  });

  group('fontBytes', () {
    test('wraps exactly the bytes it was given, not their whole buffer', () {
      // `ByteData.view(bytes.buffer)` ignores the list's offset and length, so
      // a Uint8List that is a *view* into a larger buffer was handed to
      // `FontLoader` as the entire buffer — a font file with garbage glued to
      // both ends. `readAsBytes` happens to return offset-0 lists today, which
      // is why nothing caught fire; the cast was still wrong.
      final buffer = Uint8List.fromList(List<int>.generate(16, (i) => i));
      final slice = Uint8List.sublistView(buffer, 4, 12);

      final data = fontBytes(slice);

      expect(data.lengthInBytes, 8);
      expect(data.getUint8(0), 4);
      expect(data.getUint8(7), 11);
    });

    test('a standalone list round-trips unchanged', () {
      final bytes = Uint8List.fromList(const [1, 2, 3]);

      expect(fontBytes(bytes).lengthInBytes, 3);
      expect(fontBytes(bytes).getUint8(0), 1);
    });
  });
}
