import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eng_widget_app/l10n/generated/app_localizations.dart';
import 'package:eng_widget_app/services/settings_service.dart';
import 'package:eng_widget_app/ui/screens/settings_screen.dart';

/// Тесты экрана настроек (этапы 18–19; правки приёмки 05.10.2026 —
/// единая секция «Язык», и 06.10.2026 — «как в системе»/English под
/// капотом, 5 опций, галочка у эффективного языка): сервис с временным
/// documents — паттерн favorites_screen_test.
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
  /// читают резолвы сервиса (эффективный язык — галочка секции).
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

  testWidgets('Пикер: 5 языков аутонимами, без «Как в системе» и English',
      (tester) async {
    setTestLocale(tester, const Locale('ru'));
    final settings = buildService();
    await settings.load();
    await pumpScreen(tester, settings);

    expect(find.text('Настройки'), findsOneWidget);
    expect(find.text('Язык'), findsOneWidget);
    // Правка приёмки 06.10.2026: «как в системе» и English — под
    // капотом, в опциях только 5 языков с переводами в словаре.
    expect(find.text('Как в системе'), findsNothing);
    expect(find.text('English'), findsNothing);
    expect(find.text('Русский'), findsOneWidget);
    expect(find.text('Bahasa Indonesia'), findsOneWidget);
    expect(find.text('Deutsch'), findsOneWidget);
    expect(find.text('Français'), findsOneWidget);
    expect(find.text('Español'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(5));
    // «Как в системе» — режим под капотом: галочка стоит у эффективного
    // языка — системная локаль ru дала русский. Подписей у опций нет.
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(1));
    final checked = tester.widget<ListTile>(
      find
          .ancestor(
            of: find.byIcon(Icons.check_rounded),
            matching: find.byType(ListTile),
          )
          .first,
    );
    expect((checked.title as Text).data, 'Русский');
    expect(find.text('Интерфейс: Русский · Переводы: Русский'),
        findsNothing);
    expect(find.text('Переводы слов: Русский'), findsNothing);

    // Тап по отмеченному — пишет явный выбор вместо system-режима.
    await tester.tap(find.text('Русский'));
    await tester.pump();
    expect(settings.appLanguage.value, 'ru');
    expect(
        storageFile().readAsStringSync(), contains('"appLanguage": "ru"'));
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

  testWidgets('Системная локаль en: галочки нет — English под капотом',
      (tester) async {
    setTestLocale(tester, const Locale('en'));
    final settings = buildService();
    await settings.load();
    await pumpScreen(tester, settings);

    // en-локаль → интерфейс English (фолбэк), но опции English в списке
    // нет: эффективного языка среди выбираемых нет — ни одной галочки;
    // заголовки экрана — по en-шаблону (правка приёмки 06.10.2026).
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Follow system'), findsNothing);
    expect(find.text('English'), findsNothing);
    expect(find.byType(ListTile), findsNWidgets(5));
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    settings.dispose();
  });
}