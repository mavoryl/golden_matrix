import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

/// A widget that increments a counter on every frame via a [Ticker].
/// Used to observe `freezeAnimations` actually halts ticking.
class _TickingWidget extends StatefulWidget {
  const _TickingWidget(this.ticks);
  final ValueNotifier<int> ticks;
  @override
  State<_TickingWidget> createState() => _TickingWidgetState();
}

class _TickingWidgetState extends State<_TickingWidget> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => widget.ticks.value++)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _CounterButton extends StatefulWidget {
  const _CounterButton();
  @override
  State<_CounterButton> createState() => _CounterButtonState();
}

class _CounterButtonState extends State<_CounterButton> {
  int count = 0;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: TextButton(
            key: const ValueKey('counter-btn'),
            onPressed: () => setState(() => count++),
            child: Text('count=$count'),
          ),
        ),
      ),
    );
  }
}

/// No-op golden comparator — accepts any bytes, writes nothing. Lets us
/// exercise the full `matrixGolden` pipeline (including `matchesGoldenFile`)
/// without needing baseline PNGs on disk.
class _NoOpGoldenComparator extends GoldenFileComparator {
  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async => true;
  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {}
}

void main() {
  // -- TickerMode freezes Ticker callbacks --

  group('TickerMode freezes tickers (sanity check)', () {
    testWidgets('enabled=true → tickers advance; enabled=false → frozen', (tester) async {
      final ticks = ValueNotifier(0);

      await tester.pumpWidget(TickerMode(enabled: true, child: _TickingWidget(ticks)));
      await tester.pump(const Duration(milliseconds: 100));
      final whenEnabled = ticks.value;
      expect(whenEnabled, greaterThan(0));

      // Rebuild with TickerMode disabled.
      await tester.pumpWidget(TickerMode(enabled: false, child: _TickingWidget(ticks)));
      final frozenStart = ticks.value;
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        ticks.value,
        frozenStart,
        reason: 'Tickers must not advance under TickerMode(enabled: false)',
      );
    });
  });

  // -- matrixGolden plumbing via no-op comparator --

  GoldenFileComparator? savedComparator;

  setUpAll(() {
    savedComparator = goldenFileComparator;
    goldenFileComparator = _NoOpGoldenComparator();
  });

  tearDownAll(() {
    if (savedComparator != null) {
      goldenFileComparator = savedComparator!;
    }
  });

  // --- setup callback ---

  final setupCalls = <String>[];
  matrixGolden(
    'setup invoked once per combination',
    scenarios: [MatrixScenario('default', builder: () => const _CounterButton())],
    axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
    reportFormats: const {},
    printSummary: false,
    fileNameBuilder: (c) => 'goldens/_postpump/setup_${c.theme.name}.png',
    setup: (tester, c) async {
      setupCalls.add('${c.scenario.name}|${c.theme.name}');
      await tester.tap(find.byKey(const ValueKey('counter-btn')));
      await tester.pumpAndSettle();
      expect(find.text('count=1'), findsOneWidget);
    },
  );

  test('setup ran for every combination and tap took effect', () {
    expect(setupCalls, containsAll(['default|light', 'default|dark']));
    expect(setupCalls.length, 2);
  });

  // --- freezeAnimations ---

  final ticksObserved = <String, int>{};
  matrixGolden(
    'freezeAnimations halts tickers in scenario tree',
    scenarios: [
      MatrixScenario(
        'freeze',
        builder: () => MaterialApp(home: _TickingWidget(_GlobalTicks.notifier)),
      ),
    ],
    axes: const MatrixAxes(),
    freezeAnimations: true,
    reportFormats: const {},
    printSummary: false,
    fileNameBuilder: (c) => 'goldens/_postpump/freeze.png',
    setup: (tester, c) async {
      _GlobalTicks.notifier.value = 0;
      await tester.pump(const Duration(milliseconds: 500));
      ticksObserved['${c.scenario.name}|${c.theme.name}'] = _GlobalTicks.notifier.value;
    },
  );

  test('no tick fired during 500ms pump while frozen', () {
    expect(ticksObserved, isNotEmpty);
    for (final entry in ticksObserved.entries) {
      expect(entry.value, 0, reason: '${entry.key} ticked while frozen');
    }
  });

  // --- captureAfter (pipeline plumbing) ---

  var captureAfterRanFor = '';
  matrixGolden(
    'captureAfter is plumbed through',
    scenarios: [MatrixScenario('static', builder: () => const _CounterButton())],
    axes: const MatrixAxes(),
    captureAfter: const Duration(milliseconds: 150),
    reportFormats: const {},
    printSummary: false,
    fileNameBuilder: (c) => 'goldens/_postpump/capture_after.png',
    setup: (tester, c) async {
      captureAfterRanFor = c.scenario.name;
    },
  );

  test('captureAfter pipeline ran for the combination without throwing', () {
    // Behavioral guarantee: `tester.pump(duration)` advances the test clock
    // — that's a flutter_test framework invariant, no need to re-verify.
    // We only need to confirm our wiring routed captureAfter through to
    // _executeGoldenTest without throwing.
    expect(captureAfterRanFor, 'static');
  });

  // --- all three combined ---

  final combinedCalls = <String>[];
  matrixGolden(
    'setup + freezeAnimations + captureAfter compose',
    scenarios: [MatrixScenario('default', builder: () => const _CounterButton())],
    axes: const MatrixAxes(),
    freezeAnimations: true,
    captureAfter: const Duration(milliseconds: 100),
    reportFormats: const {},
    printSummary: false,
    fileNameBuilder: (c) => 'goldens/_postpump/combined.png',
    setup: (tester, c) async {
      combinedCalls.add(c.scenario.name);
      await tester.tap(find.byKey(const ValueKey('counter-btn')));
      await tester.pumpAndSettle();
    },
  );

  test('all three parameters together: pipeline ran, setup applied', () {
    expect(combinedCalls, ['default']);
  });
}

class _GlobalTicks {
  static final notifier = ValueNotifier(0);
}
