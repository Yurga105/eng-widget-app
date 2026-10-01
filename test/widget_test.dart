import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eng_widget_app/main.dart';
import 'package:eng_widget_app/services/dictionary_service.dart';
import 'package:eng_widget_app/services/word_of_day_service.dart';

void main() {
  testWidgets('Приложение запускается и показывает слово дня',
      (tester) async {
    // В тестах нет платформенной реализации home_widget — подменяем оба
    // канала плагина (методы и стрим тапов), иначе initState приложения
    // поймает MissingPluginException.
    Future<Object?>? mockHomeWidget(MethodCall call) async => null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      mockHomeWidget,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('home_widget/updates'),
      mockHomeWidget,
    );

    await tester.pumpWidget(const WordOfTheDayApp());

    // Ассет читается реальным асинхронным I/O, поэтому «оживляем» время
    // порциями через runAsync и ждём данные FutureBuilder'а. pumpAndSettle
    // здесь не годится: индикатор загрузки анимируется бесконечно.
    var attempts = 0;
    while (find.byType(CircularProgressIndicator).evaluate().isNotEmpty &&
        attempts < 50) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      attempts++;
    }
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Ожидаемое слово дня считаем той же формулой §5, что и приложение.
    String? expectedWord;
    await tester.runAsync(() async {
      expectedWord = (await WordOfDayService(DictionaryService()).todayWord).word;
    });
    expect(expectedWord, isNotNull);

    // Локаль тестового окружения — en: AppBar показывает homeTitle
    // из AppLocalizations (бренд приложения — «Word of Day»).
    expect(find.text('Word of Day'), findsOneWidget);
    expect(find.text(expectedWord!), findsOneWidget);

    // Демонтируем приложение: dispose гасит полуночный таймер и подписку,
    // иначе фреймворк пожалуется на незавершённую работу.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
