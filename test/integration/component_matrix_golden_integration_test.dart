import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

import '../_helpers/no_op_comparator.dart';

void main() {
  // -- End-to-end: drive componentMatrixGolden against NoOpGoldenComparator,
  //    verify report files land in the configured directory.

  GoldenFileComparator? saved;
  setUpAll(() {
    saved = goldenFileComparator;
    goldenFileComparator = NoOpGoldenComparator();
  });
  tearDownAll(() {
    if (saved != null) goldenFileComparator = saved!;
  });

  final defaultDir = Directory.systemTemp.createTempSync('cmg_default_');
  final omittedDir = Directory.systemTemp.createTempSync('cmg_omitted_');
  final mdOnlyDir = Directory.systemTemp.createTempSync('cmg_md_');
  final junitDir = Directory.systemTemp.createTempSync('cmg_junit_');

  tearDownAll(() {
    for (final d in [defaultDir, omittedDir, mdOnlyDir, junitDir]) {
      if (d.existsSync()) d.deleteSync(recursive: true);
    }
  });

  bool fileExists(Directory dir, String name) => File('${dir.path}/$name').existsSync();

  Widget tinyBox() =>
      const SizedBox(width: 40, height: 40, child: ColoredBox(color: Color(0xFFFF0000)));

  // 1. defaultReportFormats — json + html + md all written.
  componentMatrixGolden(
    'cmg_default',
    scenarios: [MatrixScenario('s', builder: tinyBox)],
    axes: const MatrixAxes(),
    reportDir: defaultDir.path,
    reportFormats: defaultReportFormats,
    detectStaleGoldens: false,
    printSummary: false,
  );
  test('componentMatrixGolden defaultReportFormats writes all 3 files', () {
    expect(fileExists(defaultDir, 'componentmatrixgolden__cmg_default_report.json'), isTrue);
    expect(fileExists(defaultDir, 'componentmatrixgolden__cmg_default_report.html'), isTrue);
    expect(fileExists(defaultDir, 'componentmatrixgolden__cmg_default_report.md'), isTrue);
  });

  // 1a. reportFormats omitted — opt-in since 1.3.0, so nothing is written.
  componentMatrixGolden(
    'cmg_omitted',
    scenarios: [MatrixScenario('s', builder: tinyBox)],
    axes: const MatrixAxes(),
    reportDir: omittedDir.path,
    detectStaleGoldens: false,
    printSummary: false,
  );
  test('componentMatrixGolden without reportFormats writes nothing', () {
    for (final ext in ['json', 'html', 'md', 'xml']) {
      expect(
        fileExists(omittedDir, 'componentmatrixgolden__cmg_omitted_report.$ext'),
        isFalse,
        reason: 'reports must be opt-in; found a .$ext report',
      );
    }
  });

  // 1b. Same setup with printSummary enabled — exercises the formatSummary
  //     debugPrint branch and the stale-detection short-circuit.
  final summaryDir = Directory.systemTemp.createTempSync('cmg_summary_');
  componentMatrixGolden(
    'cmg_summary',
    scenarios: [MatrixScenario('s', builder: tinyBox)],
    axes: const MatrixAxes(),
    reportDir: summaryDir.path,
    reportFormats: const {MatrixReportFormat.json},
    // detectStaleGoldens stays default true — under NoOpGoldenComparator
    // the stale detector short-circuits (early return), exercising that
    // branch.
    // printSummary stays default true — exercises formatSummary.
  );
  test('componentMatrixGolden printSummary + stale plumbing run without error', () {
    expect(fileExists(summaryDir, 'componentmatrixgolden__cmg_summary_report.json'), isTrue);
    summaryDir.deleteSync(recursive: true);
  });

  // 2. Single format — only .md is written.
  componentMatrixGolden(
    'cmg_md',
    scenarios: [MatrixScenario('s', builder: tinyBox)],
    axes: const MatrixAxes(),
    reportFormats: const {MatrixReportFormat.markdown},
    reportDir: mdOnlyDir.path,
    detectStaleGoldens: false,
    printSummary: false,
  );
  test('componentMatrixGolden reportFormats: {markdown} writes only .md', () {
    expect(fileExists(mdOnlyDir, 'componentmatrixgolden__cmg_md_report.md'), isTrue);
    expect(fileExists(mdOnlyDir, 'componentmatrixgolden__cmg_md_report.json'), isFalse);
    expect(fileExists(mdOnlyDir, 'componentmatrixgolden__cmg_md_report.html'), isFalse);
  });

  // 3. JUnit — .xml is written.
  componentMatrixGolden(
    'cmg_junit',
    scenarios: [MatrixScenario('s', builder: tinyBox)],
    axes: const MatrixAxes(),
    reportFormats: const {MatrixReportFormat.junit},
    reportDir: junitDir.path,
    detectStaleGoldens: false,
    printSummary: false,
  );
  test('componentMatrixGolden reportFormats: {junit} writes .xml', () {
    expect(fileExists(junitDir, 'componentmatrixgolden__cmg_junit_report.xml'), isTrue);
  });

  // 5. Multi-axis matrix — exercises themes × locales × directions plumbing.
  final matrixDir = Directory.systemTemp.createTempSync('cmg_matrix_');
  componentMatrixGolden(
    'cmg_matrix',
    scenarios: [MatrixScenario('s', builder: tinyBox)],
    axes: const MatrixAxes(
      themes: [MatrixTheme.light, MatrixTheme.dark],
      locales: [Locale('en'), Locale('de')],
      directions: [TextDirection.ltr, TextDirection.rtl],
    ),
    reportDir: matrixDir.path,
    reportFormats: const {MatrixReportFormat.markdown},
    detectStaleGoldens: false,
    printSummary: false,
  );
  test('componentMatrixGolden multi-axis writes one report with 8 combinations', () {
    final md = File(
      '${matrixDir.path}/componentmatrixgolden__cmg_matrix_report.md',
    ).readAsStringSync();
    // 2 themes × 2 locales × 2 directions = 8 combinations
    expect(md, contains('8'));
    matrixDir.deleteSync(recursive: true);
  });

  // 6. Padding parameter accepted, custom value doesn't crash.
  final padDir = Directory.systemTemp.createTempSync('cmg_pad_');
  componentMatrixGolden(
    'cmg_pad',
    scenarios: [MatrixScenario('s', builder: tinyBox)],
    axes: const MatrixAxes(),
    padding: const EdgeInsets.all(16),
    reportDir: padDir.path,
    reportFormats: const {MatrixReportFormat.markdown},
    detectStaleGoldens: false,
    printSummary: false,
  );
  test('componentMatrixGolden padding param drives the runner without crashing', () {
    expect(fileExists(padDir, 'componentmatrixgolden__cmg_pad_report.md'), isTrue);
    padDir.deleteSync(recursive: true);
  });

  // 6a. Device axis is documented as ignored in component mode: it must not
  //     multiply tests, because componentGoldenPath drops the device segment
  //     and every extra device would write and compare the same PNG.
  final devicesDir = Directory.systemTemp.createTempSync('cmg_devices_');
  componentMatrixGolden(
    'cmg_devices',
    scenarios: [MatrixScenario('s', builder: tinyBox)],
    axes: const MatrixAxes(
      devices: [MatrixDevice.phoneSmall, MatrixDevice.tablet, MatrixDevice.androidMedium],
    ),
    reportDir: devicesDir.path,
    reportFormats: const {MatrixReportFormat.json},
    detectStaleGoldens: false,
    printSummary: false,
  );
  test('componentMatrixGolden collapses a multi-device axis to one combination', () {
    final json = jsonDecode(
      File('${devicesDir.path}/componentmatrixgolden__cmg_devices_report.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    expect(json['total'], 1);
    devicesDir.deleteSync(recursive: true);
  });

  // 6b. MatrixPreset.componentFull carries two devices, so it triggers the
  //     collision by construction: 16 combinations over 8 distinct paths.
  final presetDir = Directory.systemTemp.createTempSync('cmg_preset_');
  componentMatrixGolden(
    'cmg_preset',
    scenarios: [MatrixScenario('s', builder: tinyBox)],
    preset: MatrixPreset.componentFull,
    reportDir: presetDir.path,
    reportFormats: const {MatrixReportFormat.json},
    detectStaleGoldens: false,
    printSummary: false,
  );
  test('componentMatrixGolden gives every componentFull combination its own golden', () {
    final json = jsonDecode(
      File('${presetDir.path}/componentmatrixgolden__cmg_preset_report.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    final results = (json['results'] as List).cast<Map<String, dynamic>>();
    final paths = results.map((r) => r['goldenPath'] as String).toSet();

    // 2 themes × 2 locales × 2 scales, device axis collapsed.
    expect(json['total'], 8);
    expect(paths.length, results.length);
    presetDir.deleteSync(recursive: true);
  });

  // 6c. Collapsing the device axis means a rule matching on a device that is
  //     not the first one now filters everything out. Registering zero tests in
  //     silence looks like a passing run, so it has to be said out loud.
  // The warning is emitted while the group is being declared, so the capture
  // has to wrap the declaration itself — componentMatrixGolden cannot be called
  // from inside a test().
  final emptyMatrixOutput = <String>[];
  final savedDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) emptyMatrixOutput.add(message);
  };
  componentMatrixGolden(
    'cmg_empty',
    scenarios: [MatrixScenario('s', builder: tinyBox)],
    axes: const MatrixAxes(devices: [MatrixDevice.tablet, MatrixDevice.phoneSmall]),
    rules: [MatrixRule.exclude((c) => c.device == MatrixDevice.tablet)],
    detectStaleGoldens: false,
    printSummary: false,
  );
  debugPrint = savedDebugPrint;

  test('componentMatrixGolden warns when rules leave no combinations', () {
    expect(
      emptyMatrixOutput.join('\n'),
      allOf(
        contains('golden_matrix'),
        contains('cmg_empty'),
        contains('no combinations'),
        contains('collapses the devices axis'),
      ),
    );
  });

  // 7. Skip parameter — combination recorded as skipped, no rendering.
  final skipDir = Directory.systemTemp.createTempSync('cmg_skip_');
  componentMatrixGolden(
    'cmg_skip',
    scenarios: [MatrixScenario('s', builder: tinyBox)],
    axes: const MatrixAxes(),
    skip: true,
    reportDir: skipDir.path,
    reportFormats: const {MatrixReportFormat.json},
    detectStaleGoldens: false,
    printSummary: false,
  );
  test('componentMatrixGolden skip: true records combinations as skipped', () {
    final json = File(
      '${skipDir.path}/componentmatrixgolden__cmg_skip_report.json',
    ).readAsStringSync();
    // Both per-result status and the top-level skipped count must reflect
    // the skipped state. Match without assuming whitespace in the JSON
    // output.
    expect(json, contains('"skipped"'));
    expect(RegExp(r'"skipped":\s*1').hasMatch(json), isTrue);
    skipDir.deleteSync(recursive: true);
  });

  // Tolerance param is exercised by the static type check; running it
  // end-to-end would require a real LocalFileComparator (the tolerance
  // setUp asserts on the comparator type), which we deliberately replace
  // with a no-op in this test file. Tolerance branches are covered by
  // matrix_test_runner_test.dart instead.

  // 9. Setup callback — runs after pump, can drive the tester.
  var setupRan = 0;
  final setupDir = Directory.systemTemp.createTempSync('cmg_setup_');
  componentMatrixGolden(
    'cmg_setup',
    scenarios: [MatrixScenario('s', builder: tinyBox)],
    axes: const MatrixAxes(),
    setup: (tester, combination) async {
      setupRan++;
      await tester.pump();
    },
    reportDir: setupDir.path,
    reportFormats: const {MatrixReportFormat.markdown},
    detectStaleGoldens: false,
    printSummary: false,
  );
  test('componentMatrixGolden setup callback runs once per combination', () {
    expect(setupRan, 1);
    setupDir.deleteSync(recursive: true);
  });

  // 10. captureAfter — uses pump(duration) instead of pumpAndSettle.
  final captureDir = Directory.systemTemp.createTempSync('cmg_capture_');
  componentMatrixGolden(
    'cmg_capture',
    scenarios: [MatrixScenario('s', builder: tinyBox)],
    axes: const MatrixAxes(),
    captureAfter: const Duration(milliseconds: 100),
    reportDir: captureDir.path,
    reportFormats: const {MatrixReportFormat.markdown},
    detectStaleGoldens: false,
    printSummary: false,
  );
  test('componentMatrixGolden captureAfter param plumbed through', () {
    expect(fileExists(captureDir, 'componentmatrixgolden__cmg_capture_report.md'), isTrue);
    captureDir.deleteSync(recursive: true);
  });

  // 11. Tolerance out of range — throws ArgumentError synchronously when
  //     the test body actually runs. We can't easily test this end-to-end
  //     via componentMatrixGolden (the assertion fires inside setUp), so
  //     this is left as a documentation-by-existence check.

  // -- Wrap-tree behavioural unit tests (pump the tree directly, no PNG capture).

  group('componentMatrixGolden wrap shape', () {
    // These tests exercise the same wrap shape `componentMatrixGolden`
    // builds internally (MaterialApp + builder-injected Material(transparency)
    // + Align(widthFactor:1, heightFactor:1) + RepaintBoundary + Padding).
    // We verify behavioural invariants of the wrap rather than render
    // PNGs (those are covered by the example/golden_component demo).

    const boundaryKey = ValueKey('test_boundary');

    Widget buildTree({
      required Widget child,
      EdgeInsets padding = EdgeInsets.zero,
      double textScale = 1.0,
      ThemeData? theme,
      TextDirection direction = TextDirection.ltr,
    }) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme ?? ThemeData.light(),
        builder: (context, c) => Directionality(
          textDirection: direction,
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Material(type: MaterialType.transparency, child: c),
          ),
        ),
        home: Align(
          alignment: Alignment.topLeft,
          widthFactor: 1.0,
          heightFactor: 1.0,
          child: RepaintBoundary(
            key: boundaryKey,
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
    }

    testWidgets('boundary sizes to child intrinsic dimensions', (tester) async {
      const widgetSize = Size(120, 60);

      await tester.pumpWidget(
        buildTree(
          child: SizedBox(
            width: widgetSize.width,
            height: widgetSize.height,
            child: Container(color: Colors.red),
          ),
        ),
      );

      expect(tester.getSize(find.byKey(boundaryKey)), widgetSize);
    });

    testWidgets('padding expands the captured box by 2 × padding', (tester) async {
      const widgetSize = Size(100, 50);
      const padding = EdgeInsets.all(8);

      await tester.pumpWidget(
        buildTree(
          padding: padding,
          child: SizedBox(
            width: widgetSize.width,
            height: widgetSize.height,
            child: Container(color: Colors.blue),
          ),
        ),
      );

      expect(tester.getSize(find.byKey(boundaryKey)), const Size(116, 66));
    });

    testWidgets('different text scales change Text-based widget size', (tester) async {
      Future<Size> pumpAtScale(double scale) async {
        await tester.pumpWidget(
          buildTree(
            textScale: scale,
            child: const Text('Hello', style: TextStyle(fontSize: 14)),
          ),
        );
        return tester.getSize(find.byKey(boundaryKey));
      }

      final small = await pumpAtScale(1.0);
      final large = await pumpAtScale(2.0);

      expect(large.width, greaterThan(small.width));
      expect(large.height, greaterThan(small.height));
    });

    testWidgets('themed widget paints theme-derived colors', (tester) async {
      Widget themed(ThemeData theme) => buildTree(
            theme: theme,
            child: Container(width: 40, height: 40, color: theme.colorScheme.primary),
          );

      await tester.pumpWidget(themed(ThemeData.light()));
      final lightColor = (find.byType(Container).evaluate().single.widget as Container).color;

      await tester.pumpWidget(themed(ThemeData.dark()));
      final darkColor = (find.byType(Container).evaluate().single.widget as Container).color;

      expect(lightColor, isNot(equals(darkColor)));
    });

    testWidgets('Material context is present (no yellow-underline warnings)', (tester) async {
      // Material widget injected via MaterialApp.builder gives Text a
      // proper DefaultTextStyle — without it Flutter paints yellow
      // underlines on Text widgets in debug builds.
      await tester.pumpWidget(buildTree(child: const Text('Hello')));

      final material = tester.widget<Material>(find.byType(Material));
      expect(material.type, MaterialType.transparency);
    });
  });
}
