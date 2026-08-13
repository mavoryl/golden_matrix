import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [LocalFileComparator] wrapper that allows a percentage of pixels to differ.
///
/// The base `LocalFileComparator(Uri testFile)` constructor expects a test
/// file URI and derives `basedir` via `dirname(testFile)`. Passing
/// `delegate.basedir` directly would shift the basedir one directory up
/// (golden lookups would silently miss). We append a placeholder segment
/// so `dirname` strips it and leaves the original basedir intact.
class TolerantGoldenComparator extends LocalFileComparator {
  /// Wraps [delegate], passing anything within [tolerance] (0.0..1.0 of the
  /// compared pixels) as a match.
  TolerantGoldenComparator(LocalFileComparator delegate, this.tolerance)
      : super(delegate.basedir.resolve('_golden_matrix_tolerance_anchor.dart'));

  /// Fraction of differing pixels tolerated before a comparison fails.
  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    if (!result.passed && result.diffPercent <= tolerance) {
      return true;
    }

    if (!result.passed) {
      final error = await generateFailureOutput(result, golden, basedir);
      throw FlutterError(error);
    }

    return result.passed;
  }
}

/// Wraps [current] in a [TolerantGoldenComparator].
///
/// Throws [StateError] when [current] is not a [LocalFileComparator]: the
/// wrapper needs the delegate's `basedir` to find goldens and to write failure
/// output, and no other comparator exposes one.
TolerantGoldenComparator wrapForTolerance(GoldenFileComparator current, double tolerance) {
  if (current is! LocalFileComparator) {
    throw StateError(
      'golden_matrix: tolerance requires goldenFileComparator to be a '
      'LocalFileComparator, but got ${current.runtimeType}. '
      'Custom comparators are not supported with the tolerance parameter.',
    );
  }
  return TolerantGoldenComparator(current, tolerance);
}

/// Installs [TolerantGoldenComparator] for the enclosing group and restores the
/// previous comparator afterwards. A null [tolerance] is a no-op.
///
/// Must be called from inside a `group()` body: it registers `setUp`/`tearDown`
/// so the swap is scoped to that group's tests and cannot leak into whatever
/// else the test file declares.
void installToleranceComparator(double? tolerance) {
  if (tolerance == null) return;

  GoldenFileComparator? originalComparator;

  setUp(() {
    originalComparator = goldenFileComparator;
    goldenFileComparator = wrapForTolerance(goldenFileComparator, tolerance);
  });

  tearDown(() {
    if (originalComparator != null) {
      goldenFileComparator = originalComparator!;
    }
  });
}
