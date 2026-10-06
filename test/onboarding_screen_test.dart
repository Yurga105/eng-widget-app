import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eng_widget_app/l10n/generated/app_localizations.dart';
import 'package:eng_widget_app/ui/screens/onboarding_screen.dart';

/// Тесты онбординга первого запуска (этап 20, идея B-011): экран
/// автономный, сервисы не нужны. Локаль en — как в проде для новичков
/// с en/неподдержанной системной локалью.
void main() {
  void setEnLocale(WidgetTester tester) {
    tester.platformDispatcher.localeTestValue = const Locale('en');
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('en')];
    addTearDown(() {
      tester.platformDispatcher.clearLocaleTestValue();
      tester.platformDispatcher.clearLocalesTestValue();
    });
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    required ValueChanged<int> onStart,
    required ValueChanged<int> onDone,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingScreen(
          onStart: () => onStart(1),
          onDone: () => onDone(1),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Слайд 1: заголовок, Skip и «Next» на месте', (tester) async {
    setEnLocale(tester);
    var startCalls = 0;
    var doneCalls = 0;
    await pumpScreen(
      tester,
      onStart: (_) => startCalls++,
      onDone: (_) => doneCalls++,
    );

    expect(find.text('A new word every day'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Get started'), findsNothing);
    expect(startCalls, 0);
    expect(doneCalls, 0);
  });

  testWidgets('«Next» листает слайды, на последнем — «Get started»',
      (tester) async {
    setEnLocale(tester);
    var startCalls = 0;
    var doneCalls = 0;
    await pumpScreen(
      tester,
      onStart: (_) => startCalls++,
      onDone: (_) => doneCalls++,
    );

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Always in sight'), findsOneWidget,
        reason: 'второй слайд — виджет на домашнем экране');

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Remember for good'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    expect(startCalls, 0, reason: 'листание само онбординг не завершает');
    expect(doneCalls, 0);

    // «Get started» — запросить уведомления и завершить знакомство.
    await tester.tap(find.text('Get started'));
    await tester.pump();
    expect(startCalls, 1);
    expect(doneCalls, 1);
  });

  testWidgets('Skip завершает знакомство без запроса уведомлений',
      (tester) async {
    setEnLocale(tester);
    var startCalls = 0;
    var doneCalls = 0;
    await pumpScreen(
      tester,
      onStart: (_) => startCalls++,
      onDone: (_) => doneCalls++,
    );

    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(doneCalls, 1);
    expect(startCalls, 0,
        reason: 'разрешение попросят при следующем запуске');
  });

  // Правка приёмки 06.10.2026: разрыв строки по « — » (класс B2) или внутри
  // «фото-ассоциации» (класс HY) некрасив в центрированном тексте слайдов,
  // настройками Text это не отключается. Конвенция: пробелы вокруг тире —
  // NBSP (U+00A0), внутрисловный дефис — неразрывный дефис (U+2011).
  // Сентинел ловит потерю невидимых символов при будущих правках ARB.
  test('Типографика слайдов: тире и внутрисловные дефисы неразрывны', () {
    const locales = <Locale>[
      Locale('en'),
      Locale('ru'),
      Locale('id'),
      Locale('de'),
      Locale('fr'),
      Locale('es'),
    ];
    final breakableHyphen = RegExp(r'\p{L}-\p{L}', unicode: true);
    for (final locale in locales) {
      final l10n = lookupAppLocalizations(locale);
      final bodies = <String>[
        l10n.onboardingBody1,
        l10n.onboardingBody2,
        l10n.onboardingBody3,
      ];
      for (final body in bodies) {
        expect(body.contains(' — '), isFalse,
            reason:
                '$locale: тире должно быть склеено NBSP (U+00A0): $body');
        expect(breakableHyphen.hasMatch(body), isFalse,
            reason:
                '$locale: внутрисловный дефис должен быть U+2011: $body');
      }
    }
  });
}