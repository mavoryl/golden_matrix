import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

class _TestInherited extends InheritedWidget {
  const _TestInherited({required this.value, required super.child});
  final String value;

  static _TestInherited? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TestInherited>();

  @override
  bool updateShouldNotify(_TestInherited old) => old.value != value;
}

MatrixCombination _combo({
  String scenarioName = 'default',
  ScenarioBuilder? builder,
  MatrixTheme theme = MatrixTheme.light,
  Locale locale = const Locale('en'),
}) {
  return MatrixCombination(
    scenario: MatrixScenario(scenarioName, builder: builder ?? () => const SizedBox.shrink()),
    theme: theme,
    locale: locale,
    textScale: 1.0,
    device: MatrixDevice.phoneSmall,
    direction: TextDirection.ltr,
  );
}

void main() {
  group('buildMatrixGoldenWidget — wrapApp wiring', () {
    testWidgets('without wrapApp produces a MatrixWidgetWrapper directly (no extra ancestor)', (
      tester,
    ) async {
      final widget = buildMatrixGoldenWidget(combination: _combo());
      expect(widget, isA<MatrixWidgetWrapper>());
      await tester.pumpWidget(widget);
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('wrapApp is invoked exactly once per call', (tester) async {
      var calls = 0;
      buildMatrixGoldenWidget(
        combination: _combo(),
        wrapApp: (app, c) {
          calls++;
          return app;
        },
      );
      expect(calls, 1);
    });

    testWidgets('wrapApp receives the MatrixWidgetWrapper (which renders the MaterialApp)', (
      tester,
    ) async {
      Widget? capturedApp;
      buildMatrixGoldenWidget(
        combination: _combo(),
        wrapApp: (app, c) {
          capturedApp = app;
          return app;
        },
      );
      expect(capturedApp, isA<MatrixWidgetWrapper>());

      await tester.pumpWidget(capturedApp!);
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('wrapApp receives the combination unchanged', (tester) async {
      final combo = _combo(
        scenarioName: 'loading',
        theme: MatrixTheme.dark,
        locale: const Locale('ru'),
      );
      MatrixCombination? captured;
      buildMatrixGoldenWidget(
        combination: combo,
        wrapApp: (app, c) {
          captured = c;
          return app;
        },
      );
      expect(captured, isNotNull);
      expect(captured!.scenario.name, 'loading');
      expect(captured!.theme, MatrixTheme.dark);
      expect(captured!.locale, const Locale('ru'));
    });

    testWidgets('wrapApp can inject an InheritedWidget the scenario builder reads', (tester) async {
      String? seenByScenario;
      final combo = _combo(
        builder: () => Builder(
          builder: (context) {
            seenByScenario = _TestInherited.maybeOf(context)?.value;
            return Text(seenByScenario ?? '<missing>');
          },
        ),
      );

      final widget = buildMatrixGoldenWidget(
        combination: combo,
        wrapApp: (app, c) => _TestInherited(value: 'injected', child: app),
      );
      await tester.pumpWidget(widget);

      expect(seenByScenario, 'injected');
      expect(find.text('injected'), findsOneWidget);
    });

    testWidgets('wrapApp can vary by combination', (tester) async {
      Widget buildForScenario(String name) {
        final combo = _combo(
          scenarioName: name,
          builder: () => Builder(
            builder: (context) => Text(_TestInherited.maybeOf(context)?.value ?? '<missing>'),
          ),
        );
        return buildMatrixGoldenWidget(
          combination: combo,
          wrapApp: (app, c) =>
              _TestInherited(value: c.scenario.name == 'loading' ? 'L' : 'D', child: app),
        );
      }

      await tester.pumpWidget(buildForScenario('loading'));
      expect(find.text('L'), findsOneWidget);

      await tester.pumpWidget(buildForScenario('default'));
      expect(find.text('D'), findsOneWidget);
    });

    testWidgets('wrapApp + wrapChild compose: both effects visible', (tester) async {
      const childKey = ValueKey('scenario-child');
      final combo = _combo(builder: () => const SizedBox(key: childKey));

      final widget = buildMatrixGoldenWidget(
        combination: combo,
        wrapChild: (child) => Padding(padding: const EdgeInsets.all(8), child: child),
        wrapApp: (app, c) => _TestInherited(value: 'outer', child: app),
      );
      await tester.pumpWidget(widget);

      expect(find.byKey(childKey), findsOneWidget);
      expect(find.byType(Padding), findsWidgets); // wrapChild's Padding present
      // _TestInherited sits above MaterialApp:
      final inheritedFinder = find.byType(_TestInherited);
      final materialFinder = find.byType(MaterialApp);
      expect(inheritedFinder, findsOneWidget);
      expect(materialFinder, findsOneWidget);

      // verify ancestor relationship: MaterialApp is a descendant of _TestInherited
      expect(find.descendant(of: inheritedFinder, matching: materialFinder), findsOneWidget);
    });
  });
}
