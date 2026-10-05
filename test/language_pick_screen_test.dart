import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eng_widget_app/l10n/generated/app_localizations.dart';
import 'package:eng_widget_app/services/settings_service.dart';
import 'package:eng_widget_app/ui/screens/language_pick_screen.dart';

/// Тесты онбординг-пикера языка (правка приёмки 05.10.2026): сервис с
/// временным documents — паттерн settings_screen_test. В проде экран
/// локализуется по en (иначе вопрос не понадобился бы) — локаль теста
/// зафиксирована за компанию с этим условием.
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('language_pick_screen_test');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  SettingsService buildService() =>
      SettingsService(documentsDirectory: () async => tmp);

  File storageFile() => File(
      '${tmp.path}${Platform.pathSeparator}${SettingsService.fileName}');

  void setEnLocale(WidgetTester tester) {
    tester.platformDispatcher.localeTestValue = const Locale('en');
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('en')];
    addTearDown(() {
      tester.platformDispatcher.clearLocaleTestValue();
      tester.platformDispatcher.clearLocalesTestValue();
    });
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    SettingsService settings, [
    VoidCallback? onDone,
  ]) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LanguagePickScreen(
          settings: settings,
          onDone: onDone ?? () {},
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Показываются заголовок и 6 языков, у English подпись',
      (tester) async {
    setEnLocale(tester);
    final settings = buildService();
    await settings.load();
    var done = false;
    await pumpScreen(tester, settings, () => done = true);

    expect(find.text('Choose your language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);
    expect(find.text('Bahasa Indonesia'), findsOneWidget);
    expect(find.text('Deutsch'), findsOneWidget);
    expect(find.text('Français'), findsOneWidget);
    expect(find.text('Español'), findsOneWidget);
    // Подпись English: английских переводов слов в словаре нет.
    expect(find.text('Word translations: Русский'), findsOneWidget);
    expect(done, isFalse, reason: 'пока ничего не выбрано');
    settings.dispose();
  });

  testWidgets('Тап по Deutsch: выбор + флаг показа + onDone + файл v3',
      (tester) async {
    setEnLocale(tester);
    final settings = buildService();
    await settings.load();
    var done = false;
    await pumpScreen(tester, settings, () => done = true);

    await tester.tap(find.text('Deutsch'));
    await tester.pump();

    expect(done, isTrue);
    expect(settings.appLanguage.value, 'de');
    expect(settings.languagePromptShown, isTrue);
    final raw = storageFile().readAsStringSync();
    expect(raw, contains('"appLanguage": "de"'));
    expect(raw, contains('"languagePromptShown": true'));
    expect(raw, contains('"version": 3'));
    settings.dispose();
  });

  testWidgets('Назад с экрана не уйти: выбор обязателен', (tester) async {
    setEnLocale(tester);
    final settings = buildService();
    await settings.load();
    await pumpScreen(tester, settings);

    final popScope = tester.widget<PopScope>(find.byType(PopScope));
    expect(popScope.canPop, isFalse, reason: 'язык должен быть выбран');
    settings.dispose();
  });
}