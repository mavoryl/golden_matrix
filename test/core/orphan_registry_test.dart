import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

void main() {
  setUp(() {
    MatrixGoldenRegistry.reset();
  });

  group('MatrixGoldenRegistry', () {
    test('recordTouched adds slugs', () {
      MatrixGoldenRegistry.recordTouched('foo');
      MatrixGoldenRegistry.recordTouched('bar');
      expect(MatrixGoldenRegistry.touched, {'foo', 'bar'});
    });

    test('recordTouched deduplicates', () {
      MatrixGoldenRegistry.recordTouched('foo');
      MatrixGoldenRegistry.recordTouched('foo');
      expect(MatrixGoldenRegistry.touched, {'foo'});
    });

    test('reset clears all slugs', () {
      MatrixGoldenRegistry.recordTouched('foo');
      MatrixGoldenRegistry.reset();
      expect(MatrixGoldenRegistry.touched, isEmpty);
    });

    test('touched is unmodifiable', () {
      MatrixGoldenRegistry.recordTouched('foo');
      expect(() => MatrixGoldenRegistry.touched.add('bar'), throwsUnsupportedError);
    });
  });

  group('reportOrphanGoldenSubdirs', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('orphan_test_');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('non-existent root → empty list, no throw', () async {
      final ghost = Directory('${tmp.path}/does_not_exist');
      final orphans = await reportOrphanGoldenSubdirs(goldensRoot: ghost.path);
      expect(orphans, isEmpty);
    });

    test('empty root → empty list', () async {
      final orphans = await reportOrphanGoldenSubdirs(goldensRoot: tmp.path);
      expect(orphans, isEmpty);
    });

    test('all dirs registered → empty list', () async {
      Directory('${tmp.path}/widgeta').createSync();
      Directory('${tmp.path}/widgetb').createSync();
      MatrixGoldenRegistry.recordTouched('widgeta');
      MatrixGoldenRegistry.recordTouched('widgetb');
      final orphans = await reportOrphanGoldenSubdirs(goldensRoot: tmp.path);
      expect(orphans, isEmpty);
    });

    test('extra dir not in registry → reported as orphan', () async {
      Directory('${tmp.path}/widgeta').createSync();
      Directory('${tmp.path}/orphan_widget').createSync();
      MatrixGoldenRegistry.recordTouched('widgeta');
      final orphans = await reportOrphanGoldenSubdirs(goldensRoot: tmp.path);
      expect(orphans, ['orphan_widget']);
    });

    test('multiple orphans sorted alphabetically', () async {
      for (final n in ['zzz', 'aaa', 'mmm']) {
        Directory('${tmp.path}/$n').createSync();
      }
      final orphans = await reportOrphanGoldenSubdirs(goldensRoot: tmp.path);
      expect(orphans, ['aaa', 'mmm', 'zzz']);
    });

    test("Flutter's failures/ dir is never reported", () async {
      Directory('${tmp.path}/failures').createSync();
      Directory('${tmp.path}/widgeta').createSync();
      final orphans = await reportOrphanGoldenSubdirs(goldensRoot: tmp.path);
      expect(orphans, ['widgeta']);
      expect(orphans, isNot(contains('failures')));
    });

    test('files at the root level are ignored (only top-level dirs counted)', () async {
      File('${tmp.path}/some_report.json').writeAsStringSync('{}');
      File('${tmp.path}/some_report.html').writeAsStringSync('<html></html>');
      final orphans = await reportOrphanGoldenSubdirs(goldensRoot: tmp.path);
      expect(orphans, isEmpty);
    });

    test('fail:true with orphans throws StateError', () async {
      Directory('${tmp.path}/junk').createSync();
      expect(
        () => reportOrphanGoldenSubdirs(goldensRoot: tmp.path, fail: true),
        throwsA(isA<StateError>()),
      );
    });

    test('fail:true with no orphans does not throw', () async {
      Directory('${tmp.path}/foo').createSync();
      MatrixGoldenRegistry.recordTouched('foo');
      final orphans = await reportOrphanGoldenSubdirs(goldensRoot: tmp.path, fail: true);
      expect(orphans, isEmpty);
    });
  });
}
