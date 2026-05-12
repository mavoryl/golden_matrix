import 'package:flutter/foundation.dart';

/// Captures Flutter layout errors and warnings during widget rendering.
///
/// Used internally by the test runner to detect RenderFlex overflows,
/// layout failures, and other framework errors during golden tests.
///
/// ## Recognized patterns
///
/// Only overflow-style messages are captured as warnings (i.e. downgraded
/// from test failures). All other layout errors — including "RenderBox was
/// not laid out", layout assertion violations, and unknown framework
/// errors — are forwarded to the original [FlutterError.onError] so the
/// test framework can fail the test. Overflow is treated specially because
/// it represents visible-but-clipped UI that may still be a legitimate
/// rendering for golden review.
///
///   * `RenderFlex overflowed` — Row/Column children exceed available space.
///   * `A RenderFlex overflowed by` — verbose variant emitted by some
///     Flutter versions.
///   * `overflowing by` / `OVERFLOWING` — additional overflow patterns.
///
/// Usage:
/// ```dart
/// final capture = ErrorCapture()..start();
/// try {
///   await tester.pumpWidget(widget);
///   await tester.pumpAndSettle();
/// } finally {
///   capture.stop();
/// }
/// print(capture.warnings); // ['A RenderFlex overflowed by 42 pixels...']
/// ```
class ErrorCapture {
  /// Collected warning messages.
  final List<String> warnings = [];

  FlutterExceptionHandler? _originalHandler;
  bool _active = false;

  /// Overflow patterns captured as non-fatal warnings.
  ///
  /// Only true overflow messages are downgraded. Layout-contract failures
  /// like "RenderBox was not laid out" are NOT in this list and will fail
  /// the test, surfacing genuinely broken render trees.
  static const _warningPatterns = [
    'RenderFlex overflowed',
    'A RenderFlex overflowed by',
    'overflowing by',
    'OVERFLOWING',
  ];

  /// Starts capturing Flutter errors.
  ///
  /// Overrides [FlutterError.onError] with a custom handler that
  /// collects layout warnings. Always call [stop] when done.
  void start() {
    if (_active) return;
    _active = true;
    _originalHandler = FlutterError.onError;
    FlutterError.onError = _handleError;
  }

  /// Stops capturing and restores the original error handler.
  ///
  /// Safe to call multiple times.
  void stop() {
    if (!_active) return;
    _active = false;
    FlutterError.onError = _originalHandler;
    _originalHandler = null;
  }

  void _handleError(FlutterErrorDetails details) {
    final message = details.exceptionAsString();
    final isLayoutWarning = _warningPatterns.any((pattern) => message.contains(pattern));

    if (isLayoutWarning) {
      // Capture the warning but do not forward — the test framework would
      // otherwise mark the test as failed for a recognized layout warning.
      warnings.add(message);
      return;
    }

    // Forward unknown errors so the test framework can surface them.
    _originalHandler?.call(details);
  }
}
