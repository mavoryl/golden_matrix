/// When a matrix run started, and how long it has been going.
///
/// The runners used to open a `Stopwatch()..start()` at the point where they
/// were *declared*. In a test file that is before any test has run — and before
/// every group declared below them — so the reported duration silently included
/// the execution of unrelated groups. `MatrixResult.timestamp` had the mirror
/// problem: it was stamped with `DateTime.now()` inside `tearDownAll`, i.e. when
/// the run *ended*, while its dartdoc promised "when the run started".
///
/// A clock that has to be started explicitly makes both numbers answerable:
/// [start] is called from a `setUpAll` inside the run's own group, which the
/// test framework fires immediately before the run's first test.
///
/// Wall-clock throughout — that is the documented meaning of both
/// `MatrixResult.timestamp` and `MatrixResult.duration`. [now] exists so tests
/// can advance time deterministically instead of sleeping.
class MatrixRunClock {
  /// Creates an unstarted clock reading from [now], or the real clock.
  MatrixRunClock({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  DateTime? _startedAt;
  DateTime? _stoppedAt;

  /// When [start] was first called, or `null` while the clock is untouched.
  ///
  /// Stays `null` when a run registers no tests at all, or when every test in
  /// it is skipped — the framework never fires `setUpAll` in either case, and
  /// claiming a start time for a run that never began would be the same lie
  /// this class exists to remove.
  DateTime? get startedAt => _startedAt;

  /// Whether the clock has been started and not yet stopped.
  bool get isRunning => _startedAt != null && _stoppedAt == null;

  /// Time between [start] and [stop], or between [start] and now while
  /// running. [Duration.zero] before the clock is started.
  Duration get elapsed {
    final start = _startedAt;
    if (start == null) return Duration.zero;
    return (_stoppedAt ?? _now()).difference(start);
  }

  /// Marks the start of the run. Later calls are ignored, so the first one wins.
  void start() => _startedAt ??= _now();

  /// Freezes [elapsed]. Later calls are ignored; a clock that never started
  /// stays unstarted.
  void stop() {
    if (_startedAt == null) return;
    _stoppedAt ??= _now();
  }
}
