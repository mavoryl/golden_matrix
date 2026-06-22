import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:golden_matrix/src/models/matrix_combination.dart';

/// Wraps a widget in a configured [MaterialApp] shell for golden testing.
///
/// Applies theme, locale, directionality, text scale, and device safe area
/// from the given [MatrixCombination].
///
/// By default wraps [child] in `Scaffold(body: Center(child: child))`.
/// Use [wrapChild] to customize the inner layout (e.g. remove Scaffold,
/// change alignment, add padding).
class MatrixWidgetWrapper extends StatelessWidget {
  /// Wraps [child] in a configured `MaterialApp` for the given [combination].
  const MatrixWidgetWrapper({
    super.key,
    required this.combination,
    required this.child,
    this.extraLocalizationsDelegates = const [],
    this.wrapChild,
  });

  /// The combination whose theme/locale/device/direction is applied.
  final MatrixCombination combination;

  /// The widget under test.
  final Widget child;

  /// Extra localization delegates merged into the `MaterialApp`.
  final List<LocalizationsDelegate<dynamic>> extraLocalizationsDelegates;

  /// Optional builder that wraps [child] before it's placed inside the app.
  ///
  /// When null, [child] is wrapped in `Scaffold(body: Center(child: child))`.
  final Widget Function(Widget child)? wrapChild;

  @override
  Widget build(BuildContext context) {
    final themeData = combination.theme.resolve();

    final delegates = [
      ...extraLocalizationsDelegates,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ];

    final wrappedChild =
        wrapChild != null ? wrapChild!(child) : Scaffold(body: Center(child: child));

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themeData,
      locale: combination.locale,
      supportedLocales: [combination.locale],
      localizationsDelegates: delegates,
      home: Directionality(
        textDirection: combination.direction,
        child: MediaQuery(
          data: MediaQueryData(
            size: combination.device.logicalSize,
            devicePixelRatio: combination.device.pixelRatio,
            textScaler: TextScaler.linear(combination.textScale),
            padding: combination.device.safeArea,
          ),
          child: wrappedChild,
        ),
      ),
    );
  }
}
