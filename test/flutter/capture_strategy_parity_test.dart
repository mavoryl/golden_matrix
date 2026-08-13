import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';
import 'package:golden_matrix/src/flutter/capture_strategy.dart';

import '../_helpers/no_op_comparator.dart';

/// The two capture modes used to be two copies of one pipeline, and the copies
/// drifted: different view resets, different device handling, different result
/// bookkeeping. They now share `executeCapture` and differ only in the four
/// `CaptureStrategy` hooks — these tests pin that down by running the same
/// combination through both and comparing everything that is supposed to match.
MatrixCombination _combo({Widget Function()? builder}) => MatrixCombination(
      scenario: MatrixScenario(
        's',
        builder: builder ?? () => const SizedBox(width: 20, height: 10),
      ),
      theme: MatrixTheme.light,
      locale: const Locale('en'),
      textScale: 1.0,
      device: MatrixDevice.phoneSmall,
      direction: TextDirection.ltr,
    );

CaptureStrategy _viewport({bool freeze = false, double scale = 1.0}) => ViewportCaptureStrategy(
      widgetBuilder: (c) => MaterialApp(home: Scaffold(body: c.scenario.builder())),
      freezeAnimations: freeze,
      captureScale: scale,
    );

CaptureStrategy _intrinsic({bool freeze = false, double ratio = 1.0}) => IntrinsicCaptureStrategy(
      pixelRatio: ratio,
      padding: EdgeInsets.zero,
      extraLocalizationsDelegates: const [],
      freezeAnimations: freeze,
    );

void main() {
  const goldenPath = 'goldens/parity/s/light_en_ltr_1x.png';

  GoldenFileComparator? saved;
  setUpAll(() {
    saved = goldenFileComparator;
    goldenFileComparator = NoOpGoldenComparator();
  });
  tearDownAll(() {
    if (saved != null) goldenFileComparator = saved!;
  });

  final strategies = <String, CaptureStrategy Function()>{
    'viewport': _viewport,
    'intrinsic': _intrinsic,
  };

  strategies.forEach((label, make) {
    group('$label capture', () {
      testWidgets('records exactly one passing result', (tester) async {
        final results = <MatrixCombinationResult>[];

        await executeCapture(
          tester: tester,
          combination: _combo(),
          goldenPath: goldenPath,
          strategy: make(),
          record: true,
          results: results,
        );

        expect(results.length, 1);
        expect(results.single.status, MatrixResultStatus.passed);
        expect(results.single.goldenPath, goldenPath);
        expect(results.single.failurePhase, isNull);
      });

      testWidgets('records nothing when record is false', (tester) async {
        final results = <MatrixCombinationResult>[];

        await executeCapture(
          tester: tester,
          combination: _combo(),
          goldenPath: goldenPath,
          strategy: make(),
          record: false,
          results: results,
        );

        expect(results, isEmpty);
      });

      testWidgets('a throwing scenario builder is a build-phase failure', (tester) async {
        final results = <MatrixCombinationResult>[];

        await expectLater(
          executeCapture(
            tester: tester,
            combination: _combo(builder: () => throw StateError('scenario blew up')),
            goldenPath: goldenPath,
            strategy: make(),
            record: true,
            results: results,
          ),
          throwsStateError,
        );

        expect(results.single.status, MatrixResultStatus.failed);
        expect(results.single.errorMessage, contains('scenario blew up'));
      });

      testWidgets('setup runs once and can drive the tester', (tester) async {
        final results = <MatrixCombinationResult>[];
        var calls = 0;

        await executeCapture(
          tester: tester,
          combination: _combo(),
          goldenPath: goldenPath,
          strategy: make(),
          record: true,
          results: results,
          setup: (t, c) async {
            calls++;
            expect(c.scenario.name, 's');
          },
        );

        expect(calls, 1);
        expect(results.single.status, MatrixResultStatus.passed);
      });

      testWidgets('captureAfter replaces the settle without hanging', (tester) async {
        // pumpAndSettle would never return on an endless animation, which is
        // the whole reason captureAfter exists. Both strategies must honour it.
        final results = <MatrixCombinationResult>[];

        await executeCapture(
          tester: tester,
          combination: _combo(
            builder: () => const _ForeverSpinner(),
          ),
          goldenPath: goldenPath,
          strategy: make(),
          record: true,
          results: results,
          captureAfter: const Duration(milliseconds: 50),
        );

        expect(results.single.status, MatrixResultStatus.passed);
      });
    });
  });

  group('the strategies differ exactly where they should', () {
    test('each rasterizes its own boundary', () {
      expect(_viewport().boundaryKey, isNot(_intrinsic().boundaryKey));
    });

    test('capture scale comes from captureScale and pixelRatio respectively', () {
      expect(_viewport(scale: 3.0).captureScale, 3.0);
      expect(_intrinsic(ratio: 3.0).captureScale, 3.0);
    });

    testWidgets('viewport sizes the view from the device, intrinsic does not', (tester) async {
      _viewport().configureView(tester, _combo());
      final fromDevice = tester.view.physicalSize;
      expect(fromDevice, MatrixDevice.phoneSmall.logicalSize * MatrixDevice.phoneSmall.pixelRatio);

      _intrinsic().configureView(tester, _combo());
      expect(tester.view.physicalSize, isNot(fromDevice));
      expect(tester.view.devicePixelRatio, 1.0);

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    });

    Size? defaultSize;

    testWidgets('viewport restores the view before leaving the body', (tester) async {
      defaultSize = tester.view.physicalSize;
      final strategy = _viewport();

      strategy.configureView(tester, _combo());
      expect(tester.view.physicalSize, isNot(defaultSize));

      strategy.resetView(tester);
      expect(tester.view.physicalSize, defaultSize);
    });

    testWidgets('intrinsic defers its restore to teardown', (tester) async {
      final strategy = _intrinsic();

      strategy.configureView(tester, _combo());
      strategy.resetView(tester);

      expect(
        tester.view.physicalSize,
        isNot(defaultSize),
        reason: 'addTearDown runs after the body, not inside it',
      );
    });

    testWidgets('the deferred restore did happen', (tester) async {
      // If it had not, this test would inherit the 800×800 surface the
      // previous one installed.
      expect(tester.view.physicalSize, defaultSize);
    });
  });

  group('reports agree across modes', () {
    testWidgets('the same failure is classified the same way', (tester) async {
      final byStrategy = <String, MatrixFailurePhase?>{};

      for (final entry in strategies.entries) {
        final results = <MatrixCombinationResult>[];
        await expectLater(
          executeCapture(
            tester: tester,
            combination: _combo(builder: () => throw StateError('boom')),
            goldenPath: goldenPath,
            strategy: entry.value(),
            record: true,
            results: results,
          ),
          throwsStateError,
        );
        byStrategy[entry.key] = results.single.failurePhase;
      }

      expect(byStrategy['viewport'], byStrategy['intrinsic']);
      expect(byStrategy['viewport'], isNotNull);
    });
  });
}

/// An animation that never settles — `pumpAndSettle` would spin forever.
class _ForeverSpinner extends StatefulWidget {
  const _ForeverSpinner();

  @override
  State<_ForeverSpinner> createState() => _ForeverSpinnerState();
}

class _ForeverSpinnerState extends State<_ForeverSpinner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
        turns: _controller,
        child: const SizedBox(width: 20, height: 20, child: ColoredBox(color: Color(0xFF123456))),
      );
}
