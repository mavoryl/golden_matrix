// Models
// API
export 'src/api/matrix_golden.dart';
export 'src/api/matrix_test_runner.dart' show MatrixSetupCallback;
export 'src/api/preview_matrix_golden.dart';
export 'src/api/screen_matrix_golden.dart';
// Core
export 'src/core/ci_detection.dart' show isCiEnvironment;
export 'src/core/matrix_generator.dart';
export 'src/core/matrix_report_writer.dart';
export 'src/core/naming_strategy.dart';
// ignore: deprecated_member_use_from_same_package
export 'src/core/orphan_registry.dart' show MatrixGoldenRegistry, reportOrphanGoldenSubdirs;
export 'src/core/pairwise_generator.dart';
export 'src/core/report_format.dart' show MatrixReportFormat, defaultReportFormats;
// Flutter
export 'src/flutter/error_capture.dart';
export 'src/flutter/font_loader.dart';
export 'src/flutter/matrix_widget_wrapper.dart';
export 'src/flutter/pump_helpers.dart';
export 'src/models/matrix_axes.dart';
export 'src/models/matrix_combination.dart';
export 'src/models/matrix_device.dart';
export 'src/models/matrix_preset.dart';
export 'src/models/matrix_preview.dart';
export 'src/models/matrix_result.dart';
export 'src/models/matrix_rule.dart';
export 'src/models/matrix_sampling.dart';
export 'src/models/matrix_scenario.dart';
export 'src/models/matrix_theme.dart';
