import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

void main() {
  Widget placeholder() => const SizedBox();

  MatrixCombination combo({
    MatrixTheme theme = MatrixTheme.light,
    Locale locale = const Locale('en'),
    double textScale = 1.0,
    MatrixDevice device = MatrixDevice.phoneSmall,
    TextDirection direction = TextDirection.ltr,
  }) {
    return MatrixCombination(
      scenario: MatrixScenario('test', builder: placeholder),
      theme: theme,
      locale: locale,
      textScale: textScale,
      device: device,
      direction: direction,
    );
  }

  group('MatrixWidgetWrapper integration', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        MatrixWidgetWrapper(combination: combo(), child: const Text('Hello')),
      );

      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('applies light theme', (tester) async {
      await tester.pumpWidget(
        MatrixWidgetWrapper(
          combination: combo(),
          child: Builder(
            builder: (context) {
              final brightness = Theme.of(context).brightness;
              return Text('brightness: $brightness');
            },
          ),
        ),
      );

      expect(find.text('brightness: Brightness.light'), findsOneWidget);
    });

    testWidgets('applies dark theme', (tester) async {
      await tester.pumpWidget(
        MatrixWidgetWrapper(
          combination: combo(theme: MatrixTheme.dark),
          child: Builder(
            builder: (context) {
              final brightness = Theme.of(context).brightness;
              return Text('brightness: $brightness');
            },
          ),
        ),
      );

      expect(find.text('brightness: Brightness.dark'), findsOneWidget);
    });

    testWidgets('applies locale', (tester) async {
      await tester.pumpWidget(
        MatrixWidgetWrapper(
          combination: combo(locale: const Locale('ru')),
          child: Builder(
            builder: (context) {
              final locale = Localizations.localeOf(context);
              return Text('locale: ${locale.languageCode}');
            },
          ),
        ),
      );

      expect(find.text('locale: ru'), findsOneWidget);
    });

    testWidgets('applies text direction', (tester) async {
      await tester.pumpWidget(
        MatrixWidgetWrapper(
          combination: combo(direction: TextDirection.rtl),
          child: Builder(
            builder: (context) {
              final dir = Directionality.of(context);
              return Text('dir: $dir');
            },
          ),
        ),
      );

      expect(find.text('dir: TextDirection.rtl'), findsOneWidget);
    });

    testWidgets('applies text scale via MediaQuery', (tester) async {
      await tester.pumpWidget(
        MatrixWidgetWrapper(
          combination: combo(textScale: 2.0),
          child: Builder(
            builder: (context) {
              final scaler = MediaQuery.of(context).textScaler;
              final scaled = scaler.scale(14.0);
              return Text('scaled: $scaled');
            },
          ),
        ),
      );

      expect(find.text('scaled: 28.0'), findsOneWidget);
    });

    testWidgets('default wrapChild uses Scaffold and Center', (tester) async {
      await tester.pumpWidget(
        MatrixWidgetWrapper(combination: combo(), child: const Text('centered')),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(Center), findsOneWidget);
    });

    testWidgets('custom wrapChild removes Scaffold', (tester) async {
      await tester.pumpWidget(
        MatrixWidgetWrapper(
          combination: combo(),
          wrapChild: (child) => child,
          child: const Text('bare'),
        ),
      );

      expect(find.text('bare'), findsOneWidget);
      expect(find.byType(Scaffold), findsNothing);
    });

    testWidgets('custom wrapChild with Padding', (tester) async {
      await tester.pumpWidget(
        MatrixWidgetWrapper(
          combination: combo(),
          wrapChild: (child) => Padding(padding: const EdgeInsets.all(16), child: child),
          child: const Text('padded'),
        ),
      );

      expect(find.text('padded'), findsOneWidget);
      expect(find.byType(Padding), findsWidgets);
      expect(find.byType(Scaffold), findsNothing);
    });

    testWidgets('hides debug banner', (tester) async {
      await tester.pumpWidget(MatrixWidgetWrapper(combination: combo(), child: const SizedBox()));

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.debugShowCheckedModeBanner, isFalse);
    });
  });
}
