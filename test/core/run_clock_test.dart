import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/src/core/run_clock.dart';

void main() {
  // The runners used to open a `Stopwatch()..start()` where they were
  // *declared*, which in a test file is before a single test has run — and
  // before every group declared after them. The reported duration therefore
  // included the execution of unrelated groups, and `MatrixResult.timestamp`
  // was stamped in `tearDownAll` while its dartdoc promised "when the run
  // started". Both numbers now come from a clock that starts when the run does.
  group('MatrixRunClock', () {
    test('a clock nobody started reports no start and no elapsed time', () {
      final clock = MatrixRunClock(now: () => DateTime(2026));

      expect(clock.startedAt, isNull);
      expect(clock.isRunning, isFalse);
      expect(clock.elapsed, Duration.zero);
    });

    test('elapsed counts from start(), not from construction', () {
      var now = DateTime(2026, 1, 1, 12);
      final clock = MatrixRunClock(now: () => now);

      // Time passes between declaring the run and running its first test.
      now = now.add(const Duration(minutes: 5));
      clock.start();
      now = now.add(const Duration(seconds: 3));

      expect(clock.startedAt, DateTime(2026, 1, 1, 12, 5));
      expect(clock.elapsed, const Duration(seconds: 3));
    });

    test('a running clock keeps ticking, a stopped one freezes', () {
      var now = DateTime(2026);
      final clock = MatrixRunClock(now: () => now)..start();

      now = now.add(const Duration(seconds: 1));
      expect(clock.isRunning, isTrue);
      expect(clock.elapsed, const Duration(seconds: 1));

      clock.stop();
      now = now.add(const Duration(hours: 9));

      expect(clock.isRunning, isFalse);
      expect(clock.elapsed, const Duration(seconds: 1));
    });

    test('start() and stop() are idempotent', () {
      // `setUpAll` runs once per group, but a nested group or a re-entrant
      // teardown must not be able to rewind the run's start.
      var now = DateTime(2026);
      final clock = MatrixRunClock(now: () => now)..start();

      now = now.add(const Duration(seconds: 2));
      clock.start();
      expect(clock.startedAt, DateTime(2026), reason: 'the first start wins');

      clock.stop();
      clock.stop();
      expect(clock.elapsed, const Duration(seconds: 2));
    });

    test('defaults to the real clock', () {
      final before = DateTime.now();
      final clock = MatrixRunClock()..start();

      expect(clock.startedAt!.isBefore(before.subtract(const Duration(seconds: 1))), isFalse);
      expect(clock.elapsed, greaterThanOrEqualTo(Duration.zero));
    });
  });
}
