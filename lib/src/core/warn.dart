import 'package:flutter/foundation.dart';

/// Prints a package-attributed warning to the test console.
///
/// One place, because there were three: the stale scanner, the run plan and the
/// report writer each spelled the `golden_matrix: ` prefix themselves, and a
/// prefix that is written three times is a prefix that eventually differs.
void warnGoldenMatrix(String message) => debugPrint('golden_matrix: $message');
