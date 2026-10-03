import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eng_widget_app/l10n/generated/app_localizations.dart';
import 'package:eng_widget_app/main.dart';
import 'package:eng_widget_app/ui/screens/home_screen.dart';
import 'package:eng_widget_app/ui/screens/welcome_screen.dart';

/// Этап 17 (идея B-009): preload-экран приветствия.
///
/// Первый тест — гейт холодного старта на целом приложении (моки каналов
/// как в widget_test.dart, но стартовый URI виджета возвращает дату —
/// дееплинк-запуск). Платформенный ответ канала 'flutter/assets' живёт
/// только в этом первом тесте файла (БЗ §15), поэтому дальше
/// [WelcomeScreen] проверяется автономно: логотип студии лежит за
/// errorBuilder и при недоступном ассете тихо заменяется заглушкой —
/// тексты и анимация от ассетов не зависят.
void main() {
  testWidgets(
    'Гейт этапа 17: холодный старт тапом с виджета — без приветствия',
    (tester) async {
      Future<Object?>? handler(MethodCall call) async {
        // Дееплинк: приложение подняли тапом по виджету за 2026-10-03.
        if (call.method == 'initiallyLaunchedFromHomeWidget') {
          return 'wordoftheday://word?date=2026-10-03';
        }
        return null;
      }

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('home_widget'),
        handler,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('home_widget/updates'),
        (call) async => null,
      );
      final documents = Directory.systemTemp.createTempSync(
        'eng_widget_app_welcome_test',
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => documents.path,
      );
      Future<ByteData?>? assetsHandler(ByteData? message) async {
        final key = utf8.decode(
          message!.buffer.asUint8List(
            message.offsetInBytes,
            message.lengthInBytes,
          ),
        );
        final file = File(key);
        if (!file.existsSync()) {
          return null;
        }
        final bytes = file.readAsBytesSync();
        return ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);
      }

      messenger.setMockMessageHandler('flutter/assets', assetsHandler);
      addTearDown(() {
        try {
          documents.deleteSync(recursive: true);
        } catch (_) {
          /* папки уже нет — не страшно */
        }
      });

      await tester.pumpWidget(const WordOfTheDayApp());
      // pump прогоняет микрозадачи резолва стартовых источников (URI
      // виджета + payload уведомления) и кадр после отпирания гейта.
      await tester.pump();
      await tester.pump();

      // Дееплинк: приветствия нет, сразу экран приложения. Содержимое
      // карточки этот тест не ждёт — гейт про первый кадр; полный
      // сценарий карточки живёт в widget_test.dart.
      expect(find.byType(WelcomeScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  Widget host({
    VoidCallback? onFinished,
    Locale locale = const Locale('en'),
  }) =>
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: WelcomeScreen(onFinished: onFinished ?? () {}),
      );

  testWidgets('Приветствие: бренд и теглайн, доигрывание зовёт onFinished', (
    tester,
  ) async {
    var finished = 0;
    await tester.pumpWidget(host(onFinished: () => finished++));

    // Тексты в дереве с первого кадра (проявляются анимацией);
    // логотип студии — через errorBuilder (ассет-канал уже молчит).
    expect(find.text('Word of Day'), findsOneWidget);
    expect(find.text('A new English word every day'), findsOneWidget);
    expect(finished, 0);

    await tester.pumpAndSettle();
    expect(finished, 1);
  });

  testWidgets('Тап в любую точку пропускает приветствие мгновенно', (
    tester,
  ) async {
    var skipped = false;
    await tester.pumpWidget(host(onFinished: () => skipped = true));

    await tester.tap(find.byType(WelcomeScreen));
    await tester.pump();
    expect(skipped, isTrue);

    // Демонтаж до конца анимации безопасен — контроллер dispose-ится.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Зона пропуска подписана для доступности (Semantics)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(host());

    expect(find.bySemanticsLabel('Skip'), findsOneWidget);

    // Handle обязан быть закрыт до конца тела теста — проверки фреймворка
    // выполняются раньше teardown-колбэков.
    handle.dispose();
  });

  testWidgets('Теглайн — часть бренда (ru): всегда английский', (tester) async {
    await tester.pumpWidget(host(locale: const Locale('ru')));

    // Правка по итогам приёмки этапа 17: теглайн не переводим (как бренд),
    // короткий и честный — без офлайна и без обещания произношения;
    // в ru-локали локализован только Semantics.
    expect(find.text('A new English word every day'), findsOneWidget);
    expect(find.text('Word of Day'), findsOneWidget);
  });
}
