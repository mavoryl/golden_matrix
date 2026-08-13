import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/src/flutter/tolerant_comparator.dart';

import '../_helpers/no_op_comparator.dart';

/// The tolerant comparator used to exist twice — once in the screen runner,
/// once in the component one — and neither copy was ever exercised directly:
/// every test that touched tolerance stopped at argument validation. Now that
/// there is one class, it gets compared against real PNG bytes.
Future<Uint8List> _png({
  int width = 10,
  int height = 10,
  Color base = const Color(0xFF00FF00),
  int differingPixels = 0,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = base,
  );
  for (var i = 0; i < differingPixels; i++) {
    canvas.drawRect(
      Rect.fromLTWH(i.toDouble(), 0, 1, 1),
      Paint()..color = const Color(0xFFFF0000),
    );
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late LocalFileComparator delegate;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('tolerant_cmp_');
    // LocalFileComparator derives basedir from dirname(testFile), so the file
    // name itself is a placeholder that never has to exist.
    delegate = LocalFileComparator(Uri.file('${dir.path}/anchor_test.dart'));
    File('${dir.path}/golden.png').writeAsBytesSync(await _png());
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  final golden = Uri.parse('golden.png');

  group('TolerantGoldenComparator', () {
    test('identical bytes pass, tolerance or not', () async {
      final comparator = TolerantGoldenComparator(delegate, 0.0);

      expect(await comparator.compare(await _png(), golden), isTrue);
    });

    test('a diff inside the tolerance passes', () async {
      // 1 of 100 pixels differs = 1%; the delegate would fail this outright.
      final comparator = TolerantGoldenComparator(delegate, 0.05);

      expect(await comparator.compare(await _png(differingPixels: 1), golden), isTrue);
    });

    test('a diff above the tolerance still throws', () async {
      final comparator = TolerantGoldenComparator(delegate, 0.005);

      await expectLater(
        comparator.compare(await _png(differingPixels: 1), golden),
        throwsA(isA<FlutterError>()),
      );
    });

    test('the tolerance is not a licence to ignore a real regression', () async {
      // Half the image repainted: no sane tolerance covers it.
      final comparator = TolerantGoldenComparator(delegate, 0.4);

      await expectLater(
        comparator.compare(await _png(base: const Color(0xFF0000FF)), golden),
        throwsA(isA<FlutterError>()),
      );
    });
  });

  group('wrapForTolerance', () {
    test('wraps a LocalFileComparator', () {
      final wrapped = wrapForTolerance(delegate, 0.01);

      expect(wrapped.tolerance, 0.01);
      expect(wrapped.basedir, delegate.basedir);
    });

    test('refuses a comparator with no basedir to work from', () {
      expect(
        () => wrapForTolerance(NoOpGoldenComparator(), 0.01),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('LocalFileComparator'), contains('NoOpGoldenComparator')),
          ),
        ),
      );
    });
  });

  group('installToleranceComparator swaps for the group only', () {
    late GoldenFileComparator outer;

    setUpAll(() {
      outer = goldenFileComparator;
      goldenFileComparator = LocalFileComparator(
        Uri.file('${Directory.systemTemp.path}/install_anchor_test.dart'),
      );
    });

    tearDownAll(() => goldenFileComparator = outer);

    group('with a tolerance', () {
      installToleranceComparator(0.01);

      test('the active comparator is tolerant', () {
        expect(goldenFileComparator, isA<TolerantGoldenComparator>());
      });
    });

    group('without one', () {
      installToleranceComparator(null);

      test('nothing is swapped', () {
        expect(goldenFileComparator, isNot(isA<TolerantGoldenComparator>()));
      });
    });

    test('the swap did not leak out of its group', () {
      expect(goldenFileComparator, isNot(isA<TolerantGoldenComparator>()));
    });
  });
}
