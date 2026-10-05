import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eng_widget_app/l10n/generated/app_localizations.dart';
import 'package:eng_widget_app/services/settings_service.dart';
import 'package:eng_widget_app/ui/screens/settings_screen.dart';

/// Тесты экрана настроек (этапы 18–19; правка приёмки 05.10.2026 —
/// единая секция «Язык»): сервис с временным documents — паттерн
/// favorites_screen_test.
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
  /// tearDown возвращает системную среду хоста. Тот же platformDispatcher
  /// читает подпись «как в системе» и резолв переводов сервиса.
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
        // Правка приёмки 05.10.2026: резолв как в main.dart — template-
        // фолбэк локализации en. gen-l10n отдаёт supportedLocales
        // отсортированными (первая — de), и стандартная резолв
        // MaterialApp для неподдержанных локалей (kk…) дала бы немецкий.
        localeResolutionCallback: (deviceLocale, supportedLocales) => Locale(
          SettingsService.interfaceLanguageForSystemLocale(
            deviceLocale ?? const Locale('en'),
          ),
        ),
        home: SettingsScreen(settings: settings),
      ),
    );
    await tester.pump();
  }

  testWidgets('Пикер: «как в системе» + 6 языков, включая English',
      (tester) async {
    setTestLocale(tester, const Locale('ru'));
    final settings = buildService();
    await settings.load();
    await pumpScreen(tester, settings);

    expect(find.text('Настройки'), findsOneWidget);
    expect(find.text('Язык'), findsOneWidget);
    expect(find.text('Как в системе'), findsOneWidget);
    // Единая секция: 6 языков аутонимами, en среди опций (правка
    // приёмки 05.10.2026).
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);
    expect(find.text('Bahasa Indonesia'), findsOneWidget);
    expect(find.text('Deutsch'), findsOneWidget);
    expect(find.text('Français'), findsOneWidget);
    expect(find.text('Español'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(7));
    // Одна галочка — на «Как в системе» (дефолт свежей установки).
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(1));
    // Подпись системной опции: системная локаль ru даёт русский
    // интерфейс и русские переводы.
    expect(find.text('Интерфейс: Русский · Переводы: Русский'),
        findsOneWidget);
    // У English подпись: английских переводов слов в словаре нет.
    expect(find.text('Переводы слов: Русский'), findsOneWidget);
    settings.dispose();
  });

  testWidgets('Тап по Deutsch: выбор, галочка и файл v3 обновляются',
      (tester) async {
    setTestLocale(tester, const Locale('en'));
    final settings = buildService();
    await settings.load();
    await pumpScreen(tester, settings);

    await tester.tap(find.text('Deutsch'));
    await tester.pump();

    expect(settings.appLanguage.value, 'de');
    expect(settings.locale!.languageCode, 'de');
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(1));
    final tile = tester.widget<ListTile>(
      find
          .ancestor(
            of: find.text('Deutsch'),
            matching: find.byType(ListTile),
          )
          .first,
    );
    expect(tile.trailing, isNotNull, reason: 'галочка переехала на Deutsch');
    final raw = storageFile().readAsStringSync();
    expect(raw, contains('"appLanguage": "de"'));
    expect(raw, contains('"version": 3'));

    // Повторный тап по выбранному — идемпотентен.
    await tester.tap(find.text('Deutsch'));
    await tester.pump();
    expect(settings.appLanguage.value, 'de');
    settings.dispose();
  });

  testWidgets('Опция «Follow system» сбрасывает ручной выбор', (tester) async {
    setTestLocale(tester, const Locale('en'));
    final settings = buildService();
    await settings.load();
    await settings.setAppLanguage('ru');
    await pumpScreen(tester, settings);

    expect(settings.appLanguage.value, 'ru');
    await tester.tap(find.text('Follow system'));
    await tester.pump();

    expect(settings.appLanguage.value, SettingsService.systemLanguage);
    expect(settings.locale, isNull);
    expect(storageFile().readAsStringSync(),
        contains('"appLanguage": "system"'));
    settings.dispose();
  });

  testWidgets('Тап по English: интерфейс en, переводы остаются русскими',
      (tester) async {
    setTestLocale(tester, const Locale('de'));
    final settings = buildService();
    await settings.load();
    await pumpScreen(tester, settings);

    await tester.tap(find.text('English'));
    await tester.pump();

    expect(settings.appLanguage.value, 'en');
    expect(
      SettingsService.resolveTranslationLanguage(
        settings.appLanguage.value,
        const Locale('de'),
      ),
      'ru',
      reason: 'переводы слов для en — русские',
    );
    settings.dispose();
  });

  testWidgets('Локаль en: подписи экрана по шаблону', (tester) async {
    setTestLocale(tester, const Locale('en'));
    final settings = buildService();
    await settings.load();
    await pumpScreen(tester, settings);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Follow system'), findsOneWidget);
    expect(find.text('Word translations: Русский'), findsOneWidget);
    settings.dispose();
  });

  testWidgets('Подпись системной опции: локаль kk → English · Русский',
      (tester) async {
    // Системная локаль не поддержана (kk) → интерфейс English,
    // переводы — русский дефолт; подпись честно показывает оба.
    setTestLocale(tester, const Locale('kk'));
    final settings = buildService();
    await settings.load();
    await pumpScreen(tester, settings);

    expect(find.text('Interface: English · Translations: Русский'),
        findsOneWidget);
    settings.dispose();
  });

  testWidgets('Подпись системной опции: локаль de даёт немецкий',
      (tester) async {
    setTestLocale(tester, const Locale('de'));
    final settings = buildService();
    await settings.load();
    await pumpScreen(tester, settings);

    expect(find.text('Oberfläche: Deutsch · Übersetzungen: Deutsch'),
        findsOneWidget);
    settings.dispose();
  });
}