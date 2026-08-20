import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';
import 'package:golden_matrix/src/core/run_clock.dart';
import 'package:golden_matrix/src/flutter/report_pipeline.dart';

import '../_helpers/no_op_comparator.dart';

/// A [LocalFileComparator] that accepts anything but keeps a real `basedir`,
/// so stale detection has a directory to scan.
class _PassingLocalComparator extends LocalFileComparator {
  _PassingLocalComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async => true;
}

MatrixCombinationResult _passed(String goldenPath) => MatrixCombinationResult(
      combination: MatrixCombination(
        scenario: MatrixScenario('s', builder: () => const SizedBox.shrink()),
        theme: MatrixTheme.light,
        locale: const Locale('en'),
        textScale: 1.0,
        device: MatrixDevice.phoneSmall,
        direction: TextDirection.ltr,
      ),
      status: MatrixResultStatus.passed,
      goldenPath: goldenPath,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late GoldenFileComparator saved;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('report_pipeline_');
    saved = goldenFileComparator;
  });

  tearDown(() {
    goldenFileComparator = saved;
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  /// Lays out `<basedir>/goldens/<slug>/…` with one file the run produced and
  /// one it did not, and points the comparator at it.
  void stageGoldens(String slug, {required String live, required String orphan}) {
    goldenFileComparator = _PassingLocalComparator(Uri.file('${dir.path}/anchor_test.dart'));
    final subdir = Directory('${dir.path}/goldens/$slug')..createSync(recursive: true);
    File('${subdir.path}/$live').writeAsBytesSync(const [0]);
    File('${subdir.path}/$orphan').writeAsBytesSync(const [0]);
  }

  group('finishRun writes what was asked for and nothing else', () {
    test('an empty format set writes no files at all', () async {
      await finishRun(
        reportName: 'matrixGolden: Quiet',
        testSlug: 'quiet',
        results: [_passed('goldens/quiet/s/light.png')],
        clock: MatrixRunClock()..start(),
        reportDir: dir.path,
        printSummary: false,
        formats: const {},
        detectStaleGoldens: false,
      );

      expect(dir.listSync(), isEmpty);
    });

    test('each requested format lands as its own file', () async {
      await finishRun(
        reportName: 'matrixGolden: Loud',
        testSlug: 'loud',
        results: [_passed('goldens/loud/s/light.png')],
        clock: MatrixRunClock()..start(),
        reportDir: dir.path,
        printSummary: false,
        formats: const {
          MatrixReportFormat.json,
          MatrixReportFormat.html,
          MatrixReportFormat.markdown,
          MatrixReportFormat.junit,
        },
        detectStaleGoldens: false,
      );

      final names = dir.listSync().map((e) => e.path.split(Platform.pathSeparator).last).toSet();
      expect(names, {
        'matrixgolden__loud_report.json',
        'matrixgolden__loud_report.html',
        'matrixgolden__loud_report.md',
        'matrixgolden__loud_report.xml',
      });
    });
  });

  group('finishRun and stale goldens', () {
    test('an orphan file reaches the report', () async {
      stageGoldens('stale_json', live: 'light.png', orphan: 'orphan.png');

      await finishRun(
        reportName: 'matrixGolden: stale_json',
        testSlug: 'stale_json',
        results: [_passed('goldens/stale_json/light.png')],
        clock: MatrixRunClock()..start(),
        reportDir: dir.path,
        printSummary: false,
        formats: const {MatrixReportFormat.json},
        detectStaleGoldens: true,
      );

      final json = File('${dir.path}/matrixgolden__stale_json_report.json').readAsStringSync();
      expect(json, contains('orphan.png'));
      expect(json, isNot(contains('"staleGoldens": []')));
    });

    test('with reports disabled the orphan is echoed to the console instead', () async {
      // Turning reports off is a common preference; it must not also turn off
      // the only signal that a golden has been left behind.
      stageGoldens('stale_echo', live: 'light.png', orphan: 'orphan.png');

      final lines = <String>[];
      final original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => lines.add(message ?? '');
      try {
        await finishRun(
          reportName: 'matrixGolden: stale_echo',
          testSlug: 'stale_echo',
          results: [_passed('goldens/stale_echo/light.png')],
          clock: MatrixRunClock()..start(),
          reportDir: dir.path,
          printSummary: false,
          formats: const {},
          detectStaleGoldens: true,
        );
      } finally {
        debugPrint = original;
      }

      expect(lines.join('\n'), contains('1 stale golden file(s)'));
      expect(lines.join('\n'), contains('orphan.png'));
      expect(dir.listSync().whereType<File>(), isEmpty, reason: 'no report was requested');
    });

    test('printSummary prints the summary', () async {
      final lines = <String>[];
      final original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => lines.add(message ?? '');
      try {
        await finishRun(
          reportName: 'matrixGolden: Summary',
          testSlug: 'summary',
          results: [_passed('goldens/summary/s/light.png')],
          clock: MatrixRunClock()..start(),
          reportDir: dir.path,
          printSummary: true,
          formats: const {},
          detectStaleGoldens: false,
        );
      } finally {
        debugPrint = original;
      }

      expect(lines.single, contains('1 total | 1 passed'));
    });
  });

  group('finishRun reports the clock honestly', () {
    // `timestamp` was `DateTime.now()` evaluated inside the teardown while its
    // dartdoc said "when the run started", and `duration` came from a stopwatch
    // opened at declaration time. Both now read one clock the run itself started.
    Future<Map<String, dynamic>> reportFor(MatrixRunClock clock) async {
      await finishRun(
        reportName: 'matrixGolden: Clock',
        testSlug: 'clock',
        results: [_passed('goldens/clock/s/light.png')],
        clock: clock,
        reportDir: dir.path,
        printSummary: false,
        formats: const {MatrixReportFormat.json},
        detectStaleGoldens: false,
      );
      return jsonDecode(File('${dir.path}/matrixgolden__clock_report.json').readAsStringSync())
          as Map<String, dynamic>;
    }

    test('timestamp is the start of the run and duration is its length', () async {
      var now = DateTime.utc(2026, 8, 20, 9);
      final clock = MatrixRunClock(now: () => now);
      now = now.add(const Duration(minutes: 7)); // other groups in the file
      clock.start();
      now = now.add(const Duration(milliseconds: 1500));

      final json = await reportFor(clock);

      expect(json['timestamp'], '2026-08-20T09:07:00.000Z');
      expect(json['durationMs'], 1500);
    });

    test('finishRun stops the clock, so a slow teardown does not inflate it', () async {
      var now = DateTime.utc(2026);
      final clock = MatrixRunClock(now: () => now)..start();
      now = now.add(const Duration(seconds: 2));

      final json = await reportFor(clock);
      now = now.add(const Duration(hours: 1));

      expect(json['durationMs'], 2000);
      expect(clock.isRunning, isFalse);
      expect(clock.elapsed, const Duration(seconds: 2));
    });

    test('a run whose clock never started falls back to the finish time', () async {
      // Every test skipped means `setUpAll` never fired. There is no start to
      // report, so the report is stamped now rather than with a fabricated one.
      final before = DateTime.now().subtract(const Duration(seconds: 5));
      final json = await reportFor(MatrixRunClock());

      expect(json['durationMs'], 0);
      expect(DateTime.parse(json['timestamp'] as String).isAfter(before), isTrue);
    });
  });

  group('resolveDefaultReportDir', () {
    test('lands next to the goldens of a local comparator', () {
      goldenFileComparator = _PassingLocalComparator(Uri.file('${dir.path}/anchor_test.dart'));

      expect(
        resolveDefaultReportDir(),
        '${dir.path}${Platform.pathSeparator}goldens',
      );
    });

    test('returns null for a comparator with no basedir', () {
      goldenFileComparator = NoOpGoldenComparator();

      expect(resolveDefaultReportDir(), isNull);
    });
  });
}
