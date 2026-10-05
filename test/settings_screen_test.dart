import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eng_widget_app/l10n/generated/app_localizations.dart';
import 'package:eng_widget_app/services/settings_service.dart';
import 'package:eng_widget_app/ui/screens/settings_screen.dart';

/// Тесты экрана настроек (этап 18): сервис с временным documents —
/// паттерн favorites_screen_test.
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('settings_screen_test');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  SettingsService buildService() =>
      SettingsService(documentsDirectory: () async => tmp);

  File storageFile() => File(
      '${tmp.path}${Platform.pathSeparator}${SettingsService.fileName}');

  /// Локаль теста: WidgetsApp резолвит по списку локалей — в тестовом
  /// фейке одиночное значение и список независимы, ставим оба;
  /// tearDown возвращает системную среду хоста.
  void setTestLocale(WidgetTester tester, Locale locale) {
    tester.platformDispatcher.localeTestValue = locale;
    tester.platformDispatcher.localesTestValue = <Locale>[locale];
    addTearDown(() {
      tester.platformDispatcher.clearLocaleTestValue();
      tester.platformDispatcher.clearLocalesTestValue();
    });
  }

  Future<void> pumpScreen(WidgetTester tester, SettingsService settings) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(settings: settings),
      ),
    );
    await tester.pump();
  }

  testWidgets('Пикер: «как в системе» + 5 языков, English среди опций нет',
      (tester) async {
    setTestLocale(tester, const Locale('ru'));
    final settings = buildService();
    await settings.load();
    await pumpScreen(tester, settings);

    expect(find.text('Настройки'), findsOneWidget);
    expect(find.text('Язык интерфейса'), findsOneWidget);
    expect(find.text('Как в системе'), findsOneWidget);
    // Этап 19: вторая секция — язык переводов слов.
    expect(find.text('Язык переводов'), findsOneWidget);
    // Аутонимы дублируются в двух секциях; «Русский» в секции интерфейса
    // встречается трижды — опция, подпись системной опции (системная
    // локаль теста ru показывает аутоним) и опция секции переводов.
    expect(find.text('Русский'), findsNWidgets(3));
    expect(find.text('Bahasa Indonesia'), findsNWidgets(2));
    expect(find.text('Deutsch'), findsNWidgets(2));
    expect(find.text('Français'), findsNWidgets(2));
    expect(find.text('Español'), findsNWidgets(2));
    // en — template-фолбэк локализации, опцией не выбирается.
    expect(find.text('English'), findsNothing);
    expect(find.byType(ListTile), findsNWidgets(11));
    // По галочке в каждой секции: интерфейс — «как в системе»,
    // переводы — «ru» по умолчанию (этап 19).
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    settings.dispose();
  });

  testWidgets('Тап по Deutsch: выбор, галочка и файл обновляются',
      (tester) async {
    setTestLocale(tester, const Locale('en'));
    final settings = buildService();
    await settings.load();
    await pumpScreen(tester, settings);

    // Аутонимы в двух секциях — тапаем первую (секция интерфейса).
    await tester.tap(find.text('Deutsch').first);
    await tester.pump();

    expect(settings.localeOverride.value, 'de');
    expect(settings.locale!.languageCode, 'de');
    // По галочке в каждой из двух секций.
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    final tile = tester.widget<ListTile>(
      find
          .ancestor(
            of: find.text('Deutsch').first,
            matching: find.byType(ListTile),
          )
          .first,
    );
    expect(tile.trailing, isNotNull, reason: 'галочка переехала на Deutsch');
    expect(storageFile().readAsStringSync(), contains('"de"'));

    // Повторный тап по выбранному — идемпотентен.
    await tester.tap(find.text('Deutsch').first);
    await tester.pump();
    expect(settings.localeOverride.value, 'de');
    settings.dispose();
  });

  testWidgets('Опция «Follow system» сбрасывает ручной выбор', (tester) async {
    setTestLocale(tester, const Locale('en'));
    final settings = buildService();
    await settings.load();
    await settings.setInterfaceLanguage('ru');
    await pumpScreen(tester, settings);

    expect(settings.localeOverride.value, 'ru');
    await tester.tap(find.text('Follow system'));
    await tester.pump();

    expect(settings.localeOverride.value, isNull);
    expect(settings.locale, isNull);
    expect(storageFile().readAsStringSync(),
        contains('"interfaceLanguage": "system"'));
    settings.dispose();
  });

  testWidgets('Локаль en: подписи экрана по шаблону', (tester) async {
    setTestLocale(tester, const Locale('en'));
    final settings = buildService();
    await settings.load();
    await pumpScreen(tester, settings);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Interface language'), findsOneWidget);
    expect(find.text('Follow system'), findsOneWidget);
    // Этап 19: вторая секция — язык переводов.
    expect(find.text('Translation language'), findsOneWidget);
    settings.dispose();
  });

  testWidgets('Подпись системной опции показывает фактический фолбэк',
      (tester) async {
    // Системная локаль не поддерживается (kk) → локализация даёт en:
    // подпись честно показывает English, хотя опцией он не выбирается.
    setTestLocale(tester, const Locale('kk'));
    final settings = buildService();
    await settings.load();
    await pumpScreen(tester, settings);

    expect(find.text('English'), findsOneWidget);
    settings.dispose();
  });

  testWidgets('Секция переводов: тап по Español пишет нотифаер и файл v2',
      (tester) async {
    setTestLocale(tester, const Locale('ru'));
    final settings = buildService();
    await settings.load();
    await pumpScreen(tester, settings);

    // Секция переводов — вторые вхождения аутонимов; нижние тайлы за
    // экраном — сначала прокручиваем до нужного.
    await tester.ensureVisible(find.text('Español').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Español').last);
    await tester.pump();

    expect(settings.translationLanguage.value, 'es');
    // Интерфейс не тронут — настройки независимы.
    expect(settings.localeOverride.value, isNull);

    final raw = storageFile().readAsStringSync();
    expect(raw, contains('"translationLanguage": "es"'));
    expect(raw, contains('"interfaceLanguage": "system"'));
    expect(raw, contains('"version": 2'));

    // Галочка в секции переводов переехала на Español.
    final tile = tester.widget<ListTile>(
      find
          .ancestor(
            of: find.text('Español').last,
            matching: find.byType(ListTile),
          )
          .first,
    );
    expect(tile.trailing, isNotNull);
    settings.dispose();
  });

  testWidgets('Секции независимы: интерфейс de, переводы fr', (tester) async {
    setTestLocale(tester, const Locale('en'));
    final settings = buildService();
    await settings.load();
    await pumpScreen(tester, settings);

    await tester.tap(find.text('Deutsch').first); // интерфейс
    await tester.pump();
    // Секция переводов ниже — прокручиваем до Français и тапаем.
    await tester.ensureVisible(find.text('Français').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Français').last); // переводы
    await tester.pump();

    expect(settings.localeOverride.value, 'de');
    expect(settings.translationLanguage.value, 'fr');
    final raw = storageFile().readAsStringSync();
    expect(raw, contains('"interfaceLanguage": "de"'));
    expect(raw, contains('"translationLanguage": "fr"'));
    settings.dispose();
  });
}