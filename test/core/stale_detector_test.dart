import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/src/core/stale_detector.dart';

/// Helper: write [bytes] to `goldensRoot/<relPath>`, creating directories.
File _write(Directory goldensRoot, String relPath, [List<int> bytes = const [0]]) {
  final p = '${goldensRoot.path}/${relPath.replaceAll('/', Platform.pathSeparator)}';
  final f = File(p);
  f.parent.createSync(recursive: true);
  f.writeAsBytesSync(bytes);
  return f;
}

void main() {
  late Directory tmp;
  late Directory goldensRoot;
  late Directory testSubdir;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('stale_detector_test_');
    goldensRoot = Directory('${tmp.path}/goldens')..createSync();
    testSubdir = Directory('${goldensRoot.path}/mywidget')..createSync();
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('findStaleGoldens', () {
    test('empty directory returns empty list', () async {
      final result = await findStaleGoldens(
        expectedPaths: {'goldens/mywidget/default/light.png'},
        testSubdir: testSubdir,
        goldensRoot: goldensRoot,
      );
      expect(result, isEmpty);
    });

    test('nonexistent directory returns empty list, does not throw', () async {
      final ghost = Directory('${tmp.path}/does-not-exist');
      final result = await findStaleGoldens(
        expectedPaths: {'goldens/ghost/x.png'},
        testSubdir: ghost,
        goldensRoot: goldensRoot,
      );
      expect(result, isEmpty);
    });

    test('all present files match expected → empty list', () async {
      _write(goldensRoot, 'mywidget/default/light.png');
      _write(goldensRoot, 'mywidget/default/dark.png');
      final result = await findStaleGoldens(
        expectedPaths: {'goldens/mywidget/default/light.png', 'goldens/mywidget/default/dark.png'},
        testSubdir: testSubdir,
        goldensRoot: goldensRoot,
      );
      expect(result, isEmpty);
    });

    test('single orphan PNG is returned', () async {
      _write(goldensRoot, 'mywidget/default/light.png');
      _write(goldensRoot, 'mywidget/old_loading/light.png'); // orphan
      final result = await findStaleGoldens(
        expectedPaths: {'goldens/mywidget/default/light.png'},
        testSubdir: testSubdir,
        goldensRoot: goldensRoot,
      );
      expect(result, ['goldens/mywidget/old_loading/light.png']);
    });

    test('multiple orphans returned sorted', () async {
      _write(goldensRoot, 'mywidget/default/light.png'); // expected
      _write(goldensRoot, 'mywidget/zzz/dark.png');
      _write(goldensRoot, 'mywidget/aaa/light.png');
      _write(goldensRoot, 'mywidget/mmm/dark.png');
      final result = await findStaleGoldens(
        expectedPaths: {'goldens/mywidget/default/light.png'},
        testSubdir: testSubdir,
        goldensRoot: goldensRoot,
      );
      expect(result, [
        'goldens/mywidget/aaa/light.png',
        'goldens/mywidget/mmm/dark.png',
        'goldens/mywidget/zzz/dark.png',
      ]);
    });

    test('non-PNG files are ignored', () async {
      _write(goldensRoot, 'mywidget/default/light.png'); // expected
      _write(goldensRoot, 'mywidget/notes.txt');
      _write(goldensRoot, 'mywidget/old.jpeg');
      _write(goldensRoot, 'mywidget/data.json');
      final result = await findStaleGoldens(
        expectedPaths: {'goldens/mywidget/default/light.png'},
        testSubdir: testSubdir,
        goldensRoot: goldensRoot,
      );
      expect(result, isEmpty);
    });

    test('failures/ subdirectory PNGs are entirely ignored', () async {
      _write(goldensRoot, 'mywidget/default/light.png'); // expected
      _write(goldensRoot, 'mywidget/failures/light_testImage.png');
      _write(goldensRoot, 'mywidget/failures/light_masterImage.png');
      _write(goldensRoot, 'mywidget/failures/light_isolatedDiff.png');
      _write(goldensRoot, 'mywidget/failures/light_maskedDiff.png');
      final result = await findStaleGoldens(
        expectedPaths: {'goldens/mywidget/default/light.png'},
        testSubdir: testSubdir,
        goldensRoot: goldensRoot,
      );
      expect(result, isEmpty);
    });

    test('failures/ nested deep inside a scenario is also ignored', () async {
      _write(goldensRoot, 'mywidget/scenario_a/failures/dark.png');
      _write(goldensRoot, 'mywidget/scenario_b/failures/light.png');
      final result = await findStaleGoldens(
        expectedPaths: {},
        testSubdir: testSubdir,
        goldensRoot: goldensRoot,
      );
      expect(result, isEmpty);
    });

    test('mixed: matched + orphans + failure files → only orphans', () async {
      _write(goldensRoot, 'mywidget/default/light.png'); // expected
      _write(goldensRoot, 'mywidget/default/dark.png'); // expected
      _write(goldensRoot, 'mywidget/old_state/light.png'); // orphan
      _write(goldensRoot, 'mywidget/dropped_locale/ar.png'); // orphan
      _write(goldensRoot, 'mywidget/another_orphan/x.png'); // orphan
      _write(goldensRoot, 'mywidget/failures/dark_testImage.png'); // ignored
      final result = await findStaleGoldens(
        expectedPaths: {'goldens/mywidget/default/light.png', 'goldens/mywidget/default/dark.png'},
        testSubdir: testSubdir,
        goldensRoot: goldensRoot,
      );
      expect(result, [
        'goldens/mywidget/another_orphan/x.png',
        'goldens/mywidget/dropped_locale/ar.png',
        'goldens/mywidget/old_state/light.png',
      ]);
    });
  });
}
