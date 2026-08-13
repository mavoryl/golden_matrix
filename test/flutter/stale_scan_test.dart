import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/src/flutter/stale_scan.dart';

void main() {
  late Directory tempDir;
  late GoldenFileComparator savedComparator;
  late DebugPrintCallback savedPrint;
  late List<String> printed;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('stale_scan_');
    savedComparator = goldenFileComparator;
    goldenFileComparator = LocalFileComparator(Uri.file('${tempDir.path}/widget_test.dart'));

    printed = [];
    savedPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) printed.add(message);
    };
  });

  tearDown(() {
    debugPrint = savedPrint;
    goldenFileComparator = savedComparator;
    // Restore permissions first, otherwise the recursive delete fails.
    final locked = Directory('${tempDir.path}/goldens/locked');
    if (locked.existsSync()) Process.runSync('chmod', ['755', locked.path]);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('scanStaleGoldens', () {
    test('returns stale files the run did not produce', () async {
      final dir = Directory('${tempDir.path}/goldens/mywidget')..createSync(recursive: true);
      File('${dir.path}/light_en_ltr_1x_phonesmall.png').writeAsBytesSync([1]);
      File('${dir.path}/dark_en_ltr_1x_phonesmall.png').writeAsBytesSync([1]);

      final stale = await scanStaleGoldens(
        testSlug: 'mywidget',
        expectedPaths: {'goldens/mywidget/light_en_ltr_1x_phonesmall.png'},
      );

      expect(stale, ['goldens/mywidget/dark_en_ltr_1x_phonesmall.png']);
      expect(printed, isEmpty);
    });

    test('an empty expected set never declares everything stale', () async {
      // A matrix whose rules filtered every combination out produces no
      // expected paths. Treating that as "all goldens are orphans" would invite
      // deleting a whole directory over a filtering mistake.
      final dir = Directory('${tempDir.path}/goldens/mywidget')..createSync(recursive: true);
      File('${dir.path}/light_en_ltr_1x_phonesmall.png').writeAsBytesSync([1]);

      final stale = await scanStaleGoldens(testSlug: 'mywidget', expectedPaths: const {});

      expect(stale, isEmpty);
      expect(printed.join('\n'), contains('golden_matrix'));
    });

    test('a missing golden directory is not a failure and stays quiet', () async {
      final stale = await scanStaleGoldens(
        testSlug: 'never_run',
        expectedPaths: const {'goldens/never_run/light_en_ltr_1x_phonesmall.png'},
      );

      expect(stale, isEmpty);
      expect(printed, isEmpty);
    });

    test(
      'an unreadable golden directory is reported, not silently empty',
      () async {
        // `catch (_) => const []` made "scan failed" indistinguishable from
        // "nothing is stale": a permission error silently disabled stale
        // detection for the whole run with no trace in the output.
        final locked = Directory('${tempDir.path}/goldens/locked')..createSync(recursive: true);
        File('${locked.path}/light_en_ltr_1x_phonesmall.png').writeAsBytesSync([1]);
        final chmod = Process.runSync('chmod', ['000', locked.path]);
        expect(chmod.exitCode, 0, reason: 'chmod must succeed for this test to mean anything');

        final stale = await scanStaleGoldens(
          testSlug: 'locked',
          expectedPaths: const {'goldens/locked/light_en_ltr_1x_phonesmall.png'},
        );

        expect(stale, isEmpty);
        expect(
          printed.join('\n'),
          allOf(contains('golden_matrix'), contains('stale'), contains(locked.path)),
        );
      },
      // chmod 000 does not block directory listing for the owner on Windows.
      skip: Platform.isWindows,
    );
  });
}
