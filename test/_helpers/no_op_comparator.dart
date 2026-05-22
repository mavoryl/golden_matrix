import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// No-op golden comparator — accepts any bytes, writes nothing. Lets
/// integration tests drive `matrixGolden` / `screenMatrixGolden`
/// end-to-end without baseline PNGs on disk.
///
/// Install via `setUpAll`:
/// ```dart
/// GoldenFileComparator? saved;
/// setUpAll(() {
///   saved = goldenFileComparator;
///   goldenFileComparator = NoOpGoldenComparator();
/// });
/// tearDownAll(() { if (saved != null) goldenFileComparator = saved!; });
/// ```
class NoOpGoldenComparator extends GoldenFileComparator {
  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async => true;
  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {}
}
