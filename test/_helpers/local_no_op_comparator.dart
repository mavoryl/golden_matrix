import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// A [LocalFileComparator] whose `basedir` points at a real (usually temp)
/// directory — so code that derives paths from `goldenFileComparator.basedir`
/// (e.g. the default report directory: `<basedir>/goldens`) resolves a
/// deterministic, inspectable location — but which accepts any bytes and
/// writes no PNGs.
///
/// Unlike [NoOpGoldenComparator] (which extends the bare
/// `GoldenFileComparator` and therefore fails an `is LocalFileComparator`
/// check), this one keeps the local-comparator type so the basedir-based
/// default resolution kicks in.
///
/// Construct from the *test file* URI inside the directory you want as
/// basedir, e.g. `LocalNoOpGoldenComparator(Uri.file('$tmp/widget_test.dart'))`
/// → basedir `$tmp/`.
class LocalNoOpGoldenComparator extends LocalFileComparator {
  LocalNoOpGoldenComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async => true;

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {}
}
