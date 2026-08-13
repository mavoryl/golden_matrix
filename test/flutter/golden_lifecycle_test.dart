import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';
import 'package:golden_matrix/src/flutter/golden_lifecycle.dart';

MatrixCombination _combo() => MatrixCombination(
      scenario: MatrixScenario('s', builder: () => const SizedBox.shrink()),
      theme: MatrixTheme.light,
      locale: const Locale('en'),
      textScale: 1.0,
      device: MatrixDevice.phoneSmall,
      direction: TextDirection.ltr,
    );

/// Named so its frame is identifiable in a stack trace.
Never throwFromRender() => throw StateError('builder blew up');

/// Same, for the comparison step.
Never throwFromCompare() => throw StateError('pixel mismatch');

void main() {
  const path = 'goldens/s/light_en_ltr_1x.png';

  Future<Object?> run(
    WidgetTester tester, {
    required List<MatrixCombinationResult> results,
    Widget Function()? build,
    Future<void> Function(Widget widget)? pump,
    Future<void> Function()? setup,
    Future<void> Function()? compare,
    bool record = true,
    void Function(StackTrace)? onStack,
  }) async {
    try {
      await runGoldenLifecycle(
        tester: tester,
        combination: _combo(),
        goldenPath: path,
        record: record,
        results: results,
        build: build ?? () => const SizedBox.shrink(),
        pump: pump ?? (_) async {},
        setup: setup,
        compare: compare ?? () async {},
      );
      return null;
    } catch (e, st) {
      onStack?.call(st);
      return e;
    }
  }

  group('runGoldenLifecycle records exactly one result', () {
    testWidgets('a passing combination is recorded once', (tester) async {
      final results = <MatrixCombinationResult>[];

      expect(await run(tester, results: results), isNull);

      expect(results.length, 1);
      expect(results.single.status, MatrixResultStatus.passed);
      expect(results.single.goldenPath, path);
    });

    testWidgets('a throwing render step is recorded as failed', (tester) async {
      // The widget builder, pumpWidget, pumpAndSettle and setup all live in the
      // render step. A throw there used to escape through `finally` with no
      // result recorded at all: reports undercounted total/failed, JUnit lost
      // the testcase, and the stale detector flagged the live golden as orphaned
      // because its path never reached the expected set.
      final results = <MatrixCombinationResult>[];

      final error = await run(tester, results: results, pump: (_) async => throwFromRender());

      expect(error, isStateError);
      expect(results.length, 1);
      expect(results.single.status, MatrixResultStatus.failed);
      expect(results.single.goldenPath, path);
      expect(results.single.errorMessage, contains('builder blew up'));
    });

    testWidgets('a throwing comparison is recorded as failed exactly once', (tester) async {
      final results = <MatrixCombinationResult>[];

      final error = await run(tester, results: results, compare: () async => throwFromCompare());

      expect(error, isStateError);
      expect(results.length, 1);
      expect(results.single.status, MatrixResultStatus.failed);
      expect(results.single.errorMessage, contains('pixel mismatch'));
    });

    testWidgets('the original stack trace survives the rethrow', (tester) async {
      final results = <MatrixCombinationResult>[];
      StackTrace? seen;

      await run(
        tester,
        results: results,
        compare: () async => throwFromCompare(),
        onStack: (st) => seen = st,
      );

      // `throw capturedError` used to reset the trace to the rethrow site,
      // hiding where the failure actually came from.
      expect(seen.toString(), contains('throwFromCompare'));
    });

    testWidgets('a build failure is classified as the build phase', (tester) async {
      final results = <MatrixCombinationResult>[];

      await run(tester, results: results, build: () => throw StateError('builder blew up'));

      expect(results.single.failurePhase, MatrixFailurePhase.build);
    });

    testWidgets('a pump failure is classified as the pump phase', (tester) async {
      final results = <MatrixCombinationResult>[];

      await run(tester, results: results, pump: (_) async => throwFromRender());

      expect(results.single.failurePhase, MatrixFailurePhase.pump);
    });

    testWidgets('a setup failure is classified as the setup phase', (tester) async {
      final results = <MatrixCombinationResult>[];

      await run(tester, results: results, setup: () async => throwFromRender());

      expect(results.single.failurePhase, MatrixFailurePhase.setup);
    });

    testWidgets('a comparison failure is classified as the comparison phase', (tester) async {
      final results = <MatrixCombinationResult>[];

      await run(tester, results: results, compare: () async => throwFromCompare());

      expect(results.single.failurePhase, MatrixFailurePhase.comparison);
    });

    testWidgets('a framework layout error during pump is a pump failure', (tester) async {
      // Framework errors do not propagate out of pumpWidget: ErrorCapture
      // forwards them to the binding's handler, which stashes them for
      // takeException. Without claiming them per phase, a layout error looked
      // like a comparison failure and JUnit called it a GoldenMismatch — the
      // exact mislabelling finding 18 set out to remove.
      final results = <MatrixCombinationResult>[];

      final error = await run(
        tester,
        results: results,
        build: () => const Directionality(
          textDirection: TextDirection.ltr,
          child: UnconstrainedBox(
            child: Column(children: [Expanded(child: SizedBox())]),
          ),
        ),
        pump: (widget) => tester.pumpWidget(widget),
      );

      expect(error, isNotNull);
      expect(results.single.status, MatrixResultStatus.failed);
      expect(results.single.failurePhase, MatrixFailurePhase.pump);
    });

    testWidgets('a passing combination has no phase', (tester) async {
      final results = <MatrixCombinationResult>[];

      await run(tester, results: results);

      expect(results.single.failurePhase, isNull);
    });

    testWidgets('nothing is recorded when record is false', (tester) async {
      final results = <MatrixCombinationResult>[];

      final error = await run(
        tester,
        results: results,
        record: false,
        pump: (_) async => throwFromRender(),
      );

      expect(error, isStateError);
      expect(results, isEmpty);
    });
  });
}
