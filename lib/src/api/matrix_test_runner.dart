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
  List<String>? tags,
  String Function(MatrixCombination)? fileNameBuilder,
  bool report = true,
  String? reportDir,
  bool skip = false,
  double? tolerance,
  bool printSummary = true,
}) {
  final combinations = resolveCombinations(
    scenarios: scenarios,
    axes: axes,
    preset: preset,
    sampling: sampling,
    rules: rules,
    tags: tags,
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
              : NamingStrategy.goldenPath(combination);

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

@visibleForTesting
List<MatrixCombination> resolveCombinations({
  required List<MatrixScenario> scenarios,
  MatrixAxes? axes,
  MatrixPreset? preset,
  MatrixSampling? sampling,
  List<MatrixRule> rules = const [],
  List<String>? tags,
  int? maxCombinations,
}) {
  final effectiveAxes = axes ?? preset?.axes ?? const MatrixAxes();
  final effectiveSampling = sampling ?? preset?.sampling ?? MatrixSampling.full;
  final effectiveRules = [...?preset?.rules, ...rules];

  final filteredScenarios = tags != null
      ? scenarios.where((s) => s.tags.any((t) => tags.contains(t))).toList()
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

  GoldenFileComparator? originalComparator;

  setUp(() {
    originalComparator = goldenFileComparator;
    goldenFileComparator = _TolerantComparator(
      goldenFileComparator as LocalFileComparator,
      tolerance,
    );
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
}) async {
  PumpHelpers.configureView(tester, combination.device);
  final capture = ErrorCapture()..start();
  try {
    final widget = RepaintBoundary(key: _goldenBoundaryKey, child: widgetBuilder(combination));

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
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
      // ignore: avoid_print
      print(formatSummary(result));
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
