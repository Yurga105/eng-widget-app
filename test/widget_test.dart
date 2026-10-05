import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eng_widget_app/main.dart';
import 'package:eng_widget_app/services/dictionary_service.dart';
import 'package:eng_widget_app/services/word_of_day_service.dart';
import 'package:eng_widget_app/ui/screens/welcome_screen.dart';

void main() {
  // Общие приготовления (этап 13): в тестовом окружении нет платформенных
  // плагинов — подменяем каналы. home_widget (методы и стрим тапов) — иначе
  // initState приложения поймает MissingPluginException. path_provider —
  // documents-каталог указывает во временную папку теста.
  //
  // Гонка этапа 13 была глубже: платформенный ответ канала 'flutter/assets'
  // (чтение rootBundle — словарь карточки дня) доставляется только внутри
  // runAsync-зон реального времени. Запущенное в первом тесте файла
  // приложение оставляло «недокрученные» фьючерсы чтения ассета, после чего
  // платформа переставала отвечать каналу вовсе: карточка дня в следующих
  // тестах ждала ассет вечно (вечный спиннер). Поэтому за чтение ассетов
  // отвечаем сами — байтами файлов из каталога assets/ репозитория.
  Directory mockAppChannels() {
    Future<Object?>? handler(MethodCall call) async => null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      handler,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('home_widget/updates'),
      handler,
    );
    final documents = Directory.systemTemp.createTempSync(
      'eng_widget_app_test',
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
    return documents;
  }

  testWidgets('Приложение: слово дня, звезда избранного, список (этап 13)', (
    tester,
  ) async {
    mockAppChannels();

    await tester.pumpWidget(const WordOfTheDayApp());

    // Этап 17: холодный старт — preload-экран приветствия (стартовые
    // моки отдают null → обычный запуск). pump прогоняет микрозадачи
    // резолва стартовых источников и кадр после отпирания гейта.
    await tester.pump();
    await tester.pump();
    expect(find.byType(WelcomeScreen), findsOneWidget);

    // Тап пропускает приветствие мгновенно — под ним обычная карточка дня.
    await tester.tap(find.byType(WelcomeScreen));
    await tester.pump();
    expect(find.byType(WelcomeScreen), findsNothing);

    // Ассет читается реальным асинхронным I/O, поэтому «оживляем» время
    // порциями через runAsync и ждём данные FutureBuilder'а. pumpAndSettle
    // здесь не годится: индикатор загрузки анимируется бесконечно.
    //
    // Все сценарии карточки собраны в один тест не случайно: платформенный
    // ответ канала 'flutter/assets' живёт только в первом тесте файла
    // (см. комментарий mockAppChannels), поэтому второе запущенное
    // приложение в следующем testWidgets зависло бы на вечном спиннере.
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
      expectedWord = (await WordOfDayService(
        DictionaryService(),
      ).todayWord).word;
    });
    expect(expectedWord, isNotNull);

    // Локаль тестового окружения — en: AppBar показывает homeTitle
    // из AppLocalizations (бренд приложения — «Word of Day»).
    expect(find.text('Word of Day'), findsOneWidget);
    expect(find.text(expectedWord!), findsOneWidget);

    // Этап 13: тап по контурной звезде — заливает янтарным и обратно.
    final outline = find.byIcon(Icons.star_outline_rounded);
    expect(outline, findsOneWidget);

    await tester.tap(outline);
    await tester.pump();
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(outline, findsNothing);

    await tester.tap(find.byIcon(Icons.star_rounded));
    await tester.pump();
    expect(outline, findsOneWidget);

    // Этап 13: иконка в AppBar открывает список избранного.
    await tester.tap(find.byIcon(Icons.star_border_rounded));
    await tester.pump();
    // Список избранных подгружается файловым I/O — как и карточку,
    // дожидаемся ухода индикатора (Material и Cupertino) циклом runAsync.
    attempts = 0;
    while ((find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
            find.byType(CupertinoActivityIndicator).evaluate().isNotEmpty) &&
        attempts < 50) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      attempts++;
    }
    await tester.pumpAndSettle();

    expect(find.text('Favorites'), findsOneWidget);
    expect(find.textContaining('No favorite words yet'), findsOneWidget);

    // Назад — снова карточка дня.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Favorites'), findsNothing);

    // Этап 14: иконка квиза в AppBar открывает экран квиза (избранное
    // пусто — вопросы добираются из словаря).
    await tester.tap(find.byIcon(Icons.quiz_rounded));
    await tester.pump();
    attempts = 0;
    while (find.byType(CircularProgressIndicator).evaluate().isNotEmpty &&
        attempts < 50) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      attempts++;
    }
    await tester.pumpAndSettle();

    expect(find.text('Quiz'), findsOneWidget);
    expect(find.textContaining('Question 1 of'), findsOneWidget);
    // 4 варианта ответа (FilledButton.tonal — это FilledButton).
    expect(find.byType(FilledButton), findsNWidgets(4));

    // Назад — снова карточка дня.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Quiz'), findsNothing);

    // Этап 18: шестерёнка справа открывает настройки; пикер — «как в
    // системе» + 5 языков (English опцией не выбирается — template-фолбэк).
    // Этап 19: ниже добавилась секция «Translation language» — ещё 5 строк.
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Interface language'), findsOneWidget);
    expect(find.text('Translation language'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(11));

    // Тап по Deutsch — язык меняется мгновенно, включая уже открытый
    // экран настроек (нотифаер сервиса слушает и main.dart). Аутоним
    // в двух секциях — тапаем первую (язык интерфейса).
    await tester.tap(find.text('Deutsch').first);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Einstellungen'), findsOneWidget);

    // Назад — домашний экран уже на немецком (homeTitle, не бренд).
    // pageBack ищет кнопку по en-тултипу «Back» — на de он «Zurück»,
    // поэтому тапаем по типу кнопки, он от локали не зависит.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Wort des Tages'), findsOneWidget);

    // Демонтируем приложение: dispose гасит полуночный таймер и подписку,
    // иначе фреймворк пожалуется на незавершённую работу.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Системная локаль de → немецкий интерфейс без ручного выбора',
      (tester) async {
    mockAppChannels();
    tester.platformDispatcher.localeTestValue = const Locale('de');
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('de')];
    addTearDown(() {
      tester.platformDispatcher.clearLocaleTestValue();
      tester.platformDispatcher.clearLocalesTestValue();
    });

    await tester.pumpWidget(const WordOfTheDayApp());
    await tester.pump();
    await tester.pump();
    expect(find.byType(WelcomeScreen), findsOneWidget);
    await tester.tap(find.byType(WelcomeScreen));
    await tester.pump();
    await tester.pump();

    // settings.json ещё не существует → locale = null → обычная резолв
    // MaterialApp: системная локаль de теперь поддерживается (этап 18).
    // AppBar рисуется до загрузки словаря, поэтому спиннер-цикл из
    // первого теста не нужен (и опасен: см. гонку ассет-канала выше).
    expect(find.text('Wort des Tages'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
