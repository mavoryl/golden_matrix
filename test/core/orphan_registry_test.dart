// Tests for the deprecated orphan-detection API. The deprecation is
// intentional (see CHANGELOG 0.18.1); these tests still exist to lock
// behavior until removal in a later release.
// ignore_for_file: deprecated_member_use_from_same_package
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
      // Register enough touched slugs to clear the parallel-isolate
      // heuristic (orphans must not greatly exceed touched).
      for (final s in ['s1', 's2', 's3', 's4']) {
        MatrixGoldenRegistry.recordTouched(s);
      }
      final orphans = await reportOrphanGoldenSubdirs(goldensRoot: tmp.path);
      expect(orphans, ['aaa', 'mmm', 'zzz']);
    });

    test("Flutter's failures/ dir is never reported", () async {
      Directory('${tmp.path}/failures').createSync();
      Directory('${tmp.path}/widgeta').createSync();
      MatrixGoldenRegistry.recordTouched('sentinel');
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
      MatrixGoldenRegistry.recordTouched('sentinel');
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

    test('empty registry + candidates → skip, return [] (0.18.1 safety)', () async {
      // Parallel `flutter test` runs each test file in its own isolate.
      // The registry is per-isolate, so other tests in sibling isolates
      // never appear in this one. Without this safety the orphan checker
      // would flag every dir as orphan whenever flutter_test_config.dart
      // calls it under default parallel execution.
      for (final n in ['widgeta', 'widgetb', 'widgetc']) {
        Directory('${tmp.path}/$n').createSync();
      }
      // Registry intentionally left empty.
      final orphans = await reportOrphanGoldenSubdirs(goldensRoot: tmp.path);
      expect(orphans, isEmpty);
    });

    test('1 touched but many subdirs → skip (parallel-isolate signature)', () async {
      // Real-world case: 30 test files run in parallel isolates; each
      // sees only its own touched slug while 30 sibling subdirs exist
      // on disk. The heuristic catches this and refuses to report.
      for (final n in ['alert', 'badge', 'button', 'card', 'dialog']) {
        Directory('${tmp.path}/$n').createSync();
      }
      MatrixGoldenRegistry.recordTouched('alert');
      final orphans = await reportOrphanGoldenSubdirs(goldensRoot: tmp.path);
      expect(orphans, isEmpty);
    });

    test('empty registry + empty root → just [] (no skip needed)', () async {
      // Edge case: no candidates AND no registry — function returns [].
      // This path is taken by clean projects with no goldens yet.
      final orphans = await reportOrphanGoldenSubdirs(goldensRoot: tmp.path);
      expect(orphans, isEmpty);
    });

    test('printed orphan paths do not contain double separators', () async {
      Directory('${tmp.path}/extra').createSync();
      MatrixGoldenRegistry.recordTouched('sentinel');
      final orphans = await reportOrphanGoldenSubdirs(goldensRoot: '${tmp.path}/');
      expect(orphans, ['extra']);
      // The function logs '  - <root>/<name>'; the joining must collapse
      // a trailing separator on root rather than produce '//'.
      // (Indirect check: we use tmp.path with a trailing slash above to
      // exercise the bug — function should not throw and should still
      // return the orphan correctly.)
    });
  });
}
