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
    // Аутонимы: «Русский» дважды — опция и подпись системной опции
    // (системная локаль теста ru, подпись показывает аутоним).
    expect(find.text('Русский'), findsNWidgets(2));
    expect(find.text('Bahasa Indonesia'), findsOneWidget);
    expect(find.text('Deutsch'), findsOneWidget);
    expect(find.text('Français'), findsOneWidget);
    expect(find.text('Español'), findsOneWidget);
    // en — template-фолбэк локализации, опцией не выбирается.
    expect(find.text('English'), findsNothing);
    expect(find.byType(ListTile), findsNWidgets(6));
    // Начальный выбор — системный: ровно одна галочка.
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    settings.dispose();
  });

  testWidgets('Тап по Deutsch: выбор, галочка и файл обновляются',
      (tester) async {
    setTestLocale(tester, const Locale('en'));
    final settings = buildService();
    await settings.load();
    await pumpScreen(tester, settings);

    await tester.tap(find.text('Deutsch'));
    await tester.pump();

    expect(settings.localeOverride.value, 'de');
    expect(settings.locale!.languageCode, 'de');
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    final tile = tester.widget<ListTile>(
      find.ancestor(of: find.text('Deutsch'), matching: find.byType(ListTile)),
    );
    expect(tile.trailing, isNotNull, reason: 'галочка переехала на Deutsch');
    expect(storageFile().readAsStringSync(), contains('"de"'));

    // Повторный тап по выбранному — идемпотентен.
    await tester.tap(find.text('Deutsch'));
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
}