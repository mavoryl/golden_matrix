import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

Widget _placeholder() => const SizedBox.shrink();

TextDirection _everythingIsRtl(Locale locale) => TextDirection.rtl;

void main() {
  group('MatrixGenerator.directionForLocale', () {
    test('the classic RTL languages are RTL', () {
      for (final code in ['ar', 'he', 'fa', 'ur', 'ps', 'yi']) {
        expect(
          MatrixGenerator.directionForLocale(Locale(code)),
          TextDirection.rtl,
          reason: '$code is written right-to-left',
        );
      }
    });

    test('the list is no longer seven hardcoded codes', () {
      // Sindhi, Uyghur, Divehi, Central Kurdish, Syriac and N'Ko were all
      // silently laid out left-to-right, which is a wrong golden, not a
      // missing one — the test passed and the screenshot was mirrored.
      for (final code in ['sd', 'ug', 'dv', 'ckb', 'syr', 'nqo', 'prs', 'ks']) {
        expect(
          MatrixGenerator.directionForLocale(Locale(code)),
          TextDirection.rtl,
          reason: '$code is written right-to-left',
        );
      }
    });

    test('Kurdish in Latin script is left-to-right', () {
      // `ku` was hardcoded RTL. Kurmanji Kurdish — what `ku` means in CLDR —
      // is written in the Latin alphabet. The Arabic-script variant has its
      // own code, `ckb`.
      expect(MatrixGenerator.directionForLocale(const Locale('ku')), TextDirection.ltr);
    });

    test('an explicit script wins over the language default', () {
      // Azerbaijani in Arabic script is RTL, Kurdish in Latin script is LTR,
      // and romanised Arabic is LTR. `scriptCode` was ignored outright.
      expect(
        MatrixGenerator.directionForLocale(
          const Locale.fromSubtags(languageCode: 'az', scriptCode: 'Arab'),
        ),
        TextDirection.rtl,
      );
      expect(
        MatrixGenerator.directionForLocale(
          const Locale.fromSubtags(languageCode: 'ku', scriptCode: 'Latn'),
        ),
        TextDirection.ltr,
      );
      expect(
        MatrixGenerator.directionForLocale(
          const Locale.fromSubtags(languageCode: 'ar', scriptCode: 'Latn'),
        ),
        TextDirection.ltr,
        reason: 'romanised Arabic reads left to right',
      );
    });

    test('a country code does not change direction', () {
      expect(
        MatrixGenerator.directionForLocale(const Locale('ar', 'EG')),
        TextDirection.rtl,
      );
      expect(
        MatrixGenerator.directionForLocale(const Locale('en', 'IL')),
        TextDirection.ltr,
      );
    });
  });

  group('MatrixAxes.directionResolver', () {
    test('a resolver replaces the built-in inference', () {
      // Any inference over a finite table is wrong for someone: a custom
      // language subtag, a private-use locale, a design that mirrors on a flag
      // rather than on the locale. Before this there was no way to say so
      // except enumerating `directions` and losing per-locale inference.
      final combos = MatrixGenerator.generate(
        scenarios: const [MatrixScenario('s', builder: _placeholder)],
        axes: const MatrixAxes(
          locales: [Locale('en'), Locale('ar')],
          directionResolver: _everythingIsRtl,
        ),
      );

      expect(combos.map((c) => c.direction), everyElement(TextDirection.rtl));
    });

    test('an explicit directions axis still wins over the resolver', () {
      // `directions` is the enumerate-both-ways axis; a resolver answers "what
      // is this locale's direction", which is a different question.
      final combos = MatrixGenerator.generate(
        scenarios: const [MatrixScenario('s', builder: _placeholder)],
        axes: const MatrixAxes(
          locales: [Locale('ar')],
          directions: [TextDirection.ltr],
          directionResolver: _everythingIsRtl,
        ),
      );

      expect(combos.single.direction, TextDirection.ltr);
    });

    test('copyWith carries the resolver', () {
      const axes = MatrixAxes(directionResolver: _everythingIsRtl);

      expect(axes.copyWith(locales: const [Locale('en')]).directionResolver, isNotNull);
    });

    test('the resolver reaches sampled runs too', () {
      // Smoke and pairwise build their combinations through separate code
      // paths; a resolver honoured by only one of them is worse than none.
      for (final sampling in MatrixSampling.values) {
        final combos = MatrixGenerator.generate(
          scenarios: const [MatrixScenario('s', builder: _placeholder)],
          axes: const MatrixAxes(
            themes: [MatrixTheme.light, MatrixTheme.dark],
            locales: [Locale('en'), Locale('de')],
            directionResolver: _everythingIsRtl,
          ),
          sampling: sampling,
        );

        expect(
          combos.map((c) => c.direction),
          everyElement(TextDirection.rtl),
          reason: 'sampling ${sampling.name} ignored the resolver',
        );
      }
    });
  });
}
