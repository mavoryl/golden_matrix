import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/src/flutter/error_capture.dart';
import 'package:golden_matrix/src/models/matrix_combination.dart';
import 'package:golden_matrix/src/models/matrix_result.dart';

/// Builds the widget tree for one combination.
typedef GoldenBuildStep = Widget Function();

/// Pumps the built tree and settles it.
typedef GoldenPumpStep = Future<void> Function(Widget widget);

/// Drives the widget into the state to capture, then settles again.
typedef GoldenSetupStep = Future<void> Function();

/// Compares the rendered surface against its golden file.
typedef GoldenCompareStep = Future<void> Function();

/// Runs one combination through its whole lifecycle and records **exactly one**
/// [MatrixCombinationResult] for it when [record] is set.
///
/// Both `matrixGolden`/`screenMatrixGolden` and `componentMatrixGolden` route
/// their combinations through here, so the two pipelines cannot drift on result
/// bookkeeping again.
///
/// Guarantees:
///
/// - One result per call, never zero and never two — including when [build],
///   [pump] or [setup] throws. Missing those results made reports undercount
///   `total`/`failed`, dropped JUnit `testcase` entries, and let the stale
///   detector flag a live golden as orphaned because its path never made it
///   into the expected set.
/// - The failing step is recorded as a [MatrixFailurePhase], so reports can say
///   what actually broke instead of calling every failure a pixel mismatch.
/// - The original stack trace survives: failures are rethrown with
///   [Error.throwWithStackTrace] instead of a bare `throw`.
/// - Pixel mismatches reported out-of-band through `FlutterError.reportError`
///   are still caught via `tester.binding.takeException()`.
///
/// The steps are separate callbacks rather than one closure precisely so the
/// phase is known without guessing from the error message.
///
/// [onFinally] runs after the capture is stopped — view resets belong there.
Future<void> runGoldenLifecycle({
  required WidgetTester tester,
  required MatrixCombination combination,
  required String goldenPath,
  required bool record,
  required List<MatrixCombinationResult> results,
  required GoldenBuildStep build,
  required GoldenPumpStep pump,
  required GoldenCompareStep compare,
  GoldenSetupStep? setup,
  void Function()? onFinally,
}) async {
  final capture = ErrorCapture()..start();
  var recorded = false;

  void recordOnce(
    MatrixResultStatus status, {
    String? errorMessage,
    MatrixFailurePhase? phase,
  }) {
    if (recorded) return;
    recorded = true;
    results.add(
      MatrixCombinationResult(
        combination: combination,
        status: status,
        goldenPath: goldenPath,
        errorMessage: errorMessage,
        warnings: List.unmodifiable(capture.warnings),
        failurePhase: phase,
      ),
    );
  }

  /// Runs one step, attributing any failure to [phase].
  ///
  /// Framework errors are claimed here too. `pumpWidget` and `pumpAndSettle` do
  /// not throw on a render error: [ErrorCapture] forwards it to the binding's
  /// handler, which stashes it until something calls `takeException`. Left to
  /// the comparison step below, an unbounded-constraints error would be
  /// recorded as a comparison failure and reported as a golden mismatch.
  Future<T> inPhase<T>(MatrixFailurePhase phase, FutureOr<T> Function() step) async {
    try {
      final result = await step();
      final Object? pending = tester.binding.takeException();
      if (pending != null) {
        if (record) {
          capture.stop();
          recordOnce(
            MatrixResultStatus.failed,
            errorMessage: pending.toString(),
            phase: phase,
          );
        }
        Error.throwWithStackTrace(pending, StackTrace.current);
      }
      return result;
    } catch (e, st) {
      if (record) {
        capture.stop();
        recordOnce(MatrixResultStatus.failed, errorMessage: e.toString(), phase: phase);
      }
      Error.throwWithStackTrace(e, st);
    }
  }

  try {
    final widget = await inPhase(MatrixFailurePhase.build, build);
    await inPhase(MatrixFailurePhase.pump, () => pump(widget));
    if (setup != null) {
      await inPhase(MatrixFailurePhase.setup, setup);
    }

    capture.stop();

    if (!record) {
      await compare();
      return;
    }

    Object? error;
    StackTrace? stack;
    try {
      await compare();
    } catch (e, st) {
      error = e;
      stack = st;
    }

    // Pixel-mismatch failures from the golden comparator are routed through
    // `runAsync` and reported via `FlutterError.reportError` rather than
    // propagated through the matcher's await chain. The binding stashes them
    // and `takeException()` pulls them out (and clears the slot). Without this
    // check, `await expectLater(...)` returns cleanly and we would record
    // `status: passed` even though flutter_test will later fail the test.
    // See: TestWidgetsFlutterBinding._reportExceptionNoticed.
    error ??= tester.binding.takeException();

    if (error != null) {
      recordOnce(
        MatrixResultStatus.failed,
        errorMessage: error.toString(),
        phase: MatrixFailurePhase.comparison,
      );
      Error.throwWithStackTrace(error, stack ?? StackTrace.current);
    }

    recordOnce(MatrixResultStatus.passed);
  } catch (e, st) {
    // Reached by the rethrows above, which are already recorded, and by
    // anything thrown outside a phase — recorded without a phase rather than
    // mislabelled.
    if (record) {
      capture.stop();
      recordOnce(MatrixResultStatus.failed, errorMessage: e.toString());
    }
    Error.throwWithStackTrace(e, st);
  } finally {
    capture.stop();
    onFinally?.call();
  }
}

/// Records a combination that never ran because the caller passed `skip: true`.
///
/// Lives next to [runGoldenLifecycle] so every result in a report — passed,
/// failed or skipped — is appended from one place.
void recordSkipped(
  List<MatrixCombinationResult> results,
  MatrixCombination combination,
  String goldenPath,
) {
  results.add(
    MatrixCombinationResult(
      combination: combination,
      status: MatrixResultStatus.skipped,
      goldenPath: goldenPath,
    ),
  );
}
