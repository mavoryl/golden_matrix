import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

import '../_helpers/no_op_comparator.dart';

void main() {
  GoldenFileComparator? saved;

  setUpAll(() {
    saved = goldenFileComparator;
    goldenFileComparator = NoOpGoldenComparator();
    // Note: do NOT reset MatrixGoldenRegistry here — matrixGolden
    // registers its slug during group()-collection (when main() runs),
    // which happens BEFORE setUpAll. A reset here would erase the very
    // entry we're trying to assert.
  });

  tearDownAll(() {
    if (saved != null) goldenFileComparator = saved!;
  });

  matrixGolden(
    'Some Widget Name',
    scenarios: [MatrixScenario('default', builder: () => const SizedBox.shrink())],
    axes: const MatrixAxes(),
    reportFormats: const {},
    detectStaleGoldens: false,
    printSummary: false,
  );

  // The group above runs synchronously and registers its slug at
  // `group()` body entry — before any testWidgets fires. We can already
  // assert on touched at top-level test() time.
  test('matrixGolden auto-registers its slug', () {
    expect(MatrixGoldenRegistry.touched, contains('some_widget_name'));
  });

  group('reportOrphanGoldenSubdirs over real disk', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('orphan_e2e_');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('matrixGolden-touched subdir on disk is NOT orphan, '
        'an extra one IS', () async {
      // Slug from the matrixGolden above is 'some_widget_name'.
      Directory('${tmp.path}/some_widget_name').createSync();
      Directory('${tmp.path}/imaginary_widget').createSync();

      final orphans = await reportOrphanGoldenSubdirs(goldensRoot: tmp.path);

      expect(orphans, ['imaginary_widget']);
      expect(orphans, isNot(contains('some_widget_name')));
    });

    test('fail:true with real orphan throws', () async {
      Directory('${tmp.path}/orphan_dir').createSync();
      expect(
        () => reportOrphanGoldenSubdirs(goldensRoot: tmp.path, fail: true),
        throwsA(isA<StateError>()),
      );
    });
  });
}
