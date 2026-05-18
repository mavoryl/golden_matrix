import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/matrix_generator.dart';
import '../core/matrix_report_writer.dart';
import '../core/naming_strategy.dart';
import '../flutter/error_capture.dart';
import '../flutter/pump_helpers.dart';
import '../models/matrix_axes.dart';
import '../models/matrix_combination.dart';
import '../models/matrix_preset.dart';
import '../models/matrix_result.dart';
import '../models/matrix_rule.dart';
import '../models/matrix_sampling.dart';
import '../models/matrix_scenario.dart';

/// Builds a widget tree for a given [MatrixCombination].
typedef MatrixWidgetBuilder = Widget Function(MatrixCombination combination);

/// Key used for the [RepaintBoundary] that wraps the golden capture target.
const _goldenBoundaryKey = ValueKey('__golden_matrix_boundary__');

/// Callback type for `matrixGolden`/`screenMatrixGolden` `setup:` parameter.
///
/// Runs after the widget has been pumped and settled, before the golden
/// file is captured. Use to drive interactions like `tester.tap(...)`,
/// `tester.enterText(...)`, or scrolling — anything needed to bring the
/// widget into the visual state you want to snapshot.
typedef MatrixSetupCallback =
    Future<void> Function(WidgetTester tester, MatrixCombination combination);

/// Internal test runner shared by [matrixGolden] and [screenMatrixGolden].
void runMatrixTests(
  String name, {
  required List<MatrixScenario> scenarios,
  required MatrixWidgetBuilder widgetBuilder,
  MatrixAxes? axes,
  MatrixPreset? preset,
  MatrixSampling? sampling,
  int? maxCombinations,
  List<MatrixRule> rules = const [],
  List<String>? scenarioTags,
  String Function(MatrixCombination)? fileNameBuilder,
  bool report = true,
  String? reportDir,
  bool skip = false,
  double? tolerance,
  bool printSummary = true,
  MatrixSetupCallback? setup,
  bool freezeAnimations = false,
  Duration? captureAfter,
}) {
  final combinations = resolveCombinations(
    scenarios: scenarios,
    axes: axes,
    preset: preset,
    sampling: sampling,
    rules: rules,
    scenarioTags: scenarioTags,
    maxCombinations: maxCombinations,
  );

  final byScenario = groupByScenario(combinations);

  final List<MatrixCombinationResult> results = [];
  final stopwatch = Stopwatch()..start();

  group(name, () {
    _setupTolerance(tolerance);

    for (final entry in byScenario.entries) {
      group(entry.key, () {
        for (final combination in entry.value) {
          final goldenPath = fileNameBuilder != null
              ? fileNameBuilder(combination)
              : NamingStrategy.goldenPath(combination, testName: _stripPrefix(name));

          if (skip && report) {
            _recordSkipped(results, combination, goldenPath);
          }

          testWidgets(
            _testDescription(combination),
            skip: skip,
            (tester) => _executeGoldenTest(
              tester: tester,
              combination: combination,
              goldenPath: goldenPath,
              widgetBuilder: widgetBuilder,
              report: report,
              results: results,
              setup: setup,
              freezeAnimations: freezeAnimations,
              captureAfter: captureAfter,
            ),
          );
        }
      });
    }

    if (report) {
      _setupReportWriting(name, results, stopwatch, reportDir, printSummary);
    }
  });
}

// -- Config resolution --

/// Resolves the final list of [MatrixCombination] for a given configuration.
///
/// Shared by the test runner and [previewMatrixGolden]. Applies preset
/// defaults, scenario-tag filtering, exclude/includeOnly rules, the chosen
/// sampling strategy, and the global `maxCombinations` cap.
List<MatrixCombination> resolveCombinations({
  required List<MatrixScenario> scenarios,
  MatrixAxes? axes,
  MatrixPreset? preset,
  MatrixSampling? sampling,
  List<MatrixRule> rules = const [],
  List<String>? scenarioTags,
  int? maxCombinations,
}) {
  final effectiveAxes = axes ?? preset?.axes ?? const MatrixAxes();
  final effectiveSampling = sampling ?? preset?.sampling ?? MatrixSampling.full;
  final effectiveRules = [...?preset?.rules, ...rules];

  final filteredScenarios = scenarioTags != null
      ? scenarios.where((s) => s.tags.any((t) => scenarioTags.contains(t))).toList()
      : scenarios;

  return MatrixGenerator.generate(
    scenarios: filteredScenarios,
    axes: effectiveAxes,
    sampling: effectiveSampling,
    rules: effectiveRules,
    maxCombinations: maxCombinations,
  );
}

@visibleForTesting
Map<String, List<MatrixCombination>> groupByScenario(List<MatrixCombination> combinations) {
  final grouped = <String, List<MatrixCombination>>{};
  for (final c in combinations) {
    (grouped[c.scenario.name] ??= []).add(c);
  }
  return grouped;
}

// -- Tolerance --

void _setupTolerance(double? tolerance) {
  if (tolerance == null) return;

  if (tolerance < 0.0 || tolerance > 1.0) {
    throw ArgumentError.value(tolerance, 'tolerance', 'must be in range 0.0..1.0');
  }

  GoldenFileComparator? originalComparator;

  setUp(() {
    originalComparator = goldenFileComparator;
    final current = goldenFileComparator;
    if (current is! LocalFileComparator) {
      throw StateError(
        'golden_matrix: tolerance requires goldenFileComparator to be a '
        'LocalFileComparator, but got ${current.runtimeType}. '
        'Custom comparators are not supported with the tolerance parameter.',
      );
    }
    goldenFileComparator = _TolerantComparator(current, tolerance);
  });

  tearDown(() {
    if (originalComparator != null) {
      goldenFileComparator = originalComparator!;
    }
  });
}

// -- Test execution --

Future<void> _executeGoldenTest({
  required WidgetTester tester,
  required MatrixCombination combination,
  required String goldenPath,
  required MatrixWidgetBuilder widgetBuilder,
  required bool report,
  required List<MatrixCombinationResult> results,
  MatrixSetupCallback? setup,
  bool freezeAnimations = false,
  Duration? captureAfter,
}) async {
  PumpHelpers.configureView(tester, combination.device);
  final capture = ErrorCapture()..start();
  try {
    final widget = RepaintBoundary(
      key: _goldenBoundaryKey,
      child: TickerMode(enabled: !freezeAnimations, child: widgetBuilder(combination)),
    );

    await tester.pumpWidget(widget);

    // Initial settle. When captureAfter is set, use pump(duration) instead
    // of pumpAndSettle — pumpAndSettle would hang on infinite animations
    // (the very use case captureAfter exists for).
    if (captureAfter != null) {
      await tester.pump(captureAfter);
    } else {
      await tester.pumpAndSettle();
    }

    if (setup != null) {
      await setup(tester, combination);
      if (captureAfter != null) {
        await tester.pump(captureAfter);
      } else {
        await tester.pumpAndSettle();
      }
    }

    capture.stop();

    if (report) {
      try {
        await expectLater(find.byKey(_goldenBoundaryKey), matchesGoldenFile(goldenPath));
        results.add(
          MatrixCombinationResult(
            combination: combination,
            status: MatrixResultStatus.passed,
            goldenPath: goldenPath,
            warnings: List.unmodifiable(capture.warnings),
          ),
        );
      } catch (e) {
        results.add(
          MatrixCombinationResult(
            combination: combination,
            status: MatrixResultStatus.failed,
            goldenPath: goldenPath,
            errorMessage: e.toString(),
            warnings: List.unmodifiable(capture.warnings),
          ),
        );
        rethrow;
      }
    } else {
      await expectLater(find.byKey(_goldenBoundaryKey), matchesGoldenFile(goldenPath));
    }
  } finally {
    capture.stop();
    PumpHelpers.resetView(tester);
  }
}

// -- Result recording --

void _recordSkipped(
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

// -- Report writing --

void _setupReportWriting(
  String name,
  List<MatrixCombinationResult> results,
  Stopwatch stopwatch,
  String? reportDir,
  bool printSummary,
) {
  tearDownAll(() async {
    stopwatch.stop();
    final result = MatrixResult(name: name, results: results, duration: stopwatch.elapsed);
    await MatrixReportWriter.write(result, outputDir: reportDir);
    await MatrixReportWriter.writeHtml(result, outputDir: reportDir);
    if (printSummary) {
      debugPrint(formatSummary(result));
    }
  });
}

/// Formats a human-readable summary of a [MatrixResult] for console output.
///
/// Includes counts, duration, and a list of failed combinations.
@visibleForTesting
String formatSummary(MatrixResult result) {
  final buf = StringBuffer();
  buf.writeln(result.name);

  final parts = <String>[
    '${result.total} total',
    '${result.passed} passed',
    if (result.failed > 0) '${result.failed} failed',
    if (result.skipped > 0) '${result.skipped} skipped',
    if (result.warningCount > 0) '${result.warningCount} warnings',
  ];
  final duration = result.duration.inMilliseconds < 1000
      ? '${result.duration.inMilliseconds}ms'
      : '${result.duration.inSeconds}s';
  buf.writeln('  ${parts.join(' | ')} ($duration)');

  final failed = result.results.where((r) => r.status == MatrixResultStatus.failed);
  if (failed.isNotEmpty) {
    buf.writeln('  Failed:');
    for (final f in failed) {
      final c = f.combination;
      final dir = c.direction == TextDirection.ltr ? 'ltr' : 'rtl';
      buf.writeln(
        '    - ${c.scenario.name} | ${c.theme.name} ${c.locale} $dir ${c.textScale}x ${c.device.name}',
      );
    }
  }

  return buf.toString().trimRight();
}

// -- Helpers --

/// Strips the public API prefix ('matrixGolden: ' or 'screenMatrixGolden: ')
/// from a test name to get just the user-provided identifier.
String _stripPrefix(String name) {
  const prefixes = ['matrixGolden: ', 'screenMatrixGolden: '];
  for (final prefix in prefixes) {
    if (name.startsWith(prefix)) return name.substring(prefix.length);
  }
  return name;
}

String _testDescription(MatrixCombination c) {
  final dir = c.direction == TextDirection.ltr ? 'ltr' : 'rtl';
  return '${c.theme.name} ${c.locale} $dir ${c.textScale}x ${c.device.name}';
}

/// A [LocalFileComparator] wrapper that allows a percentage of pixels to differ.
class _TolerantComparator extends LocalFileComparator {
  final double _tolerance;

  _TolerantComparator(LocalFileComparator delegate, this._tolerance) : super(delegate.basedir);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    if (!result.passed && result.diffPercent <= _tolerance) {
      return true;
    }

    if (!result.passed) {
      final error = await generateFailureOutput(result, golden, basedir);
      throw FlutterError(error);
    }

    return result.passed;
  }
}
