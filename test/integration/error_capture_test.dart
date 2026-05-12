import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

void main() {
  group('ErrorCapture pattern policy', () {
    test('captures overflow patterns as warnings', () {
      final capture = ErrorCapture()..start();
      try {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: FlutterError('A RenderFlex overflowed by 42 pixels on the right.'),
          ),
        );
        FlutterError.reportError(
          FlutterErrorDetails(exception: FlutterError('RenderFlex overflowed')),
        );
      } finally {
        capture.stop();
      }
      expect(capture.warnings.length, 2);
      expect(capture.warnings.first, contains('overflowed'));
    });

    test('does NOT capture "RenderBox was not laid out" (forwarded as failure)', () {
      // Install a sink to count forwarded errors.
      var forwardedCount = 0;
      final originalHandler = FlutterError.onError;
      FlutterError.onError = (details) => forwardedCount++;
      try {
        final capture = ErrorCapture()..start();
        try {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: FlutterError('RenderBox was not laid out: RenderConstrainedBox#abcde'),
            ),
          );
        } finally {
          capture.stop();
        }
        expect(
          capture.warnings,
          isEmpty,
          reason: '"RenderBox was not laid out" must not be downgraded',
        );
        expect(forwardedCount, 1, reason: 'Layout-contract failures must be forwarded');
      } finally {
        FlutterError.onError = originalHandler;
      }
    });

    test('forwards unknown errors to original handler', () {
      var forwardedCount = 0;
      final originalHandler = FlutterError.onError;
      FlutterError.onError = (details) => forwardedCount++;
      try {
        final capture = ErrorCapture()..start();
        try {
          FlutterError.reportError(
            FlutterErrorDetails(exception: Exception('totally unrelated error')),
          );
        } finally {
          capture.stop();
        }
        expect(capture.warnings, isEmpty);
        expect(forwardedCount, 1);
      } finally {
        FlutterError.onError = originalHandler;
      }
    });
  });
}
