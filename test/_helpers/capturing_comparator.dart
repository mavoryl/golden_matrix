import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// A golden comparator that accepts every image but records the **pixel
/// dimensions** of the PNG it was handed, keyed by golden path.
///
/// Lets tests assert on the resolution golden_matrix actually captured —
/// the only way to catch a regression in the capture scale, since the
/// rendered content is identical at every scale.
///
/// Install via `setUpAll`, same as [NoOpGoldenComparator]:
/// ```dart
/// final capture = CapturingGoldenComparator();
/// setUpAll(() { saved = goldenFileComparator; goldenFileComparator = capture; });
/// tearDownAll(() { if (saved != null) goldenFileComparator = saved!; });
/// ```
class CapturingGoldenComparator extends GoldenFileComparator {
  /// Every golden this comparator saw, path → PNG pixel size.
  final captured = <String, ({int width, int height})>{};

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    captured[golden.path] = pngSize(imageBytes);
    return true;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {
    captured[golden.path] = pngSize(imageBytes);
  }

  /// The size of the single captured golden whose path contains [pathPart].
  ///
  /// Throws when nothing or more than one golden matches, so a test can never
  /// silently assert against the wrong file.
  ({int width, int height}) sizeOf(String pathPart) {
    final matches = captured.entries.where((e) => e.key.contains(pathPart)).toList();
    if (matches.length != 1) {
      throw StateError(
        'expected exactly one captured golden containing "$pathPart", '
        'found ${matches.length} among: ${captured.keys.join(", ")}',
      );
    }
    return matches.single.value;
  }
}

/// Reads width/height out of a PNG's IHDR chunk (bytes 16..24).
({int width, int height}) pngSize(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  return (width: data.getUint32(16), height: data.getUint32(20));
}
