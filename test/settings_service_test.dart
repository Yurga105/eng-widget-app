import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';

import 'package:eng_widget_app/services/settings_service.dart';

/// Тесты SettingsService (этапы 18–19; правки приёмки 05.10 и
/// 06.10.2026):
/// каталог documents подменяется временным — паттерн
/// favorite_service_test. Резолвы системной локали вынесены в чистые
/// статические функции ([SettingsService.resolveTranslationLanguage] и
/// др.) — юнит-тесты платформу не трогают; геттеры с
/// platformDispatcher не вызываем (нет биндинга).
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('settings_service_test');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  SettingsService buildService() =>
      SettingsService(documentsDirectory: () async => tmp);

  File storageFile() => File(
      '${tmp.path}${Platform.pathSeparator}${SettingsService.fileName}');

  test(
      'load: файла нет → «как в системе», онбординги впереди, файл не создаётся',
      () async {
    final service = buildService();
    await service.load();

    expect(service.appLanguage.value, SettingsService.systemLanguage);
    expect(service.locale, isNull);
    expect(service.languagePromptShown, isFalse);
    expect(service.onboardingShown, isFalse);
    expect(service.isLoaded, isTrue);
    expect(storageFile().existsSync(), isFalse,
        reason: 'системный выбор не порождает файл');
    service.dispose();
  });

  test('setAppLanguage: код сохраняется в нотифаер и файл v3', () async {
    final service = buildService();
    await service.setAppLanguage('de');

    expect(service.appLanguage.value, 'de');
    expect(service.locale!.languageCode, 'de');
    final raw = storageFile().readAsStringSync();
    expect(raw, contains('"appLanguage": "de"'));
    expect(raw, contains('"version": 3'));
    service.dispose();
  });

  test('setAppLanguage(system): сброс на системную локаль', () async {
    final service = buildService();
    await service.setAppLanguage('ru');
    expect(service.appLanguage.value, 'ru');

    await service.setAppLanguage(SettingsService.systemLanguage);
    expect(service.appLanguage.value, SettingsService.systemLanguage);
    expect(service.locale, isNull);
    expect(storageFile().readAsStringSync(),
        contains('"appLanguage": "system"'));
    service.dispose();
  });

  test('setAppLanguage(en): допустим — интерфейс English, переводы русские',
      () async {
    final service = buildService();
    await service.setAppLanguage('en');

    expect(service.appLanguage.value, 'en');
    expect(service.locale!.languageCode, 'en');
    expect(
        storageFile().readAsStringSync(), contains('"appLanguage": "en"'));
    service.dispose();
  });

  test('setAppLanguage: неизвестный код → «как в системе» (валидация записи)',
      () async {
    final service = buildService();
    await service.setAppLanguage('xx');
    expect(service.appLanguage.value, SettingsService.systemLanguage);
    expect(storageFile().readAsStringSync(),
        contains('"appLanguage": "system"'));
    service.dispose();
  });

  test('нотифаер оповещает слушателей (main.dart пересобирает MaterialApp)',
      () async {
    final service = buildService();
    final values = <String>[];
    void listen() => values.add(service.appLanguage.value);
    service.appLanguage.addListener(listen);

    await service.setAppLanguage('es');
    await service.setAppLanguage(SettingsService.systemLanguage);

    expect(values, ['es', SettingsService.systemLanguage]);
    service.appLanguage.removeListener(listen);
    service.dispose();
  });

  test('персистентность: выбор переживает новый экземпляр сервиса', () async {
    final first = buildService();
    await first.setAppLanguage('fr');
    first.dispose();

    final second = buildService();
    await second.load();
    expect(second.appLanguage.value, 'fr');
    expect(second.locale!.languageCode, 'fr');
    expect(second.isLoaded, isTrue);
    second.dispose();
  });

  test('битый JSON → тихие дефолты', () async {
    storageFile().writeAsStringSync('{ не json');
    final service = buildService();
    await service.load();
    expect(service.appLanguage.value, SettingsService.systemLanguage);
    expect(service.languagePromptShown, isFalse);
    expect(service.onboardingShown, isFalse);
    expect(service.isLoaded, isTrue);
    service.dispose();
  });

  test('мусор в appLanguage файла v3 → system, валидные читаются', () async {
    storageFile().writeAsStringSync(jsonEncode(<String, Object>{
      'version': 3,
      'appLanguage': 'kk', // язык не поддерживается
    }));
    final unknown = buildService();
    await unknown.load();
    expect(unknown.appLanguage.value, SettingsService.systemLanguage);
    unknown.dispose();

    storageFile().writeAsStringSync(jsonEncode(<String, Object>{
      'version': 3,
      'appLanguage': 42, // не строка
    }));
    final wrongType = buildService();
    await wrongType.load();
    expect(wrongType.appLanguage.value, SettingsService.systemLanguage);
    wrongType.dispose();

    storageFile().writeAsStringSync(jsonEncode(<String, Object>{
      'version': 3,
      'appLanguage': 'id',
    }));
    final valid = buildService();
    await valid.load();
    expect(valid.appLanguage.value, 'id');
    valid.dispose();
  });

  test('v3: флаги онбордингов читаются, кривые флаги → false', () async {
    storageFile().writeAsStringSync(jsonEncode(<String, Object>{
      'version': 3,
      'appLanguage': 'system',
      'languagePromptShown': true,
      'onboardingShown': true,
    }));
    final shown = buildService();
    await shown.load();
    expect(shown.languagePromptShown, isTrue);
    expect(shown.onboardingShown, isTrue);
    shown.dispose();

    storageFile().writeAsStringSync(jsonEncode(<String, Object>{
      'version': 3,
      'appLanguage': 'de',
      'languagePromptShown': 'да', // не булево
    }));
    final broken = buildService();
    await broken.load();
    expect(broken.languagePromptShown, isFalse);
    expect(broken.onboardingShown, isFalse);
    broken.dispose();
  });

  test('сбой каталога documents → тихо, нотифаер живёт', () async {
    final service = SettingsService(
      documentsDirectory: () async => throw Exception('нет path_provider'),
    );
    await service.load();
    expect(service.appLanguage.value, SettingsService.systemLanguage);
    expect(service.isLoaded, isTrue);

    await service.setAppLanguage('ru'); // запись упадёт — молча
    expect(service.appLanguage.value, 'ru');
    service.dispose();
  });

  test('kInterfaceLanguages: 6 языков, en скрыт, выбираемые = словарю', () {
    expect(kInterfaceLanguages.map((l) => l.code),
        ['en', 'ru', 'id', 'de', 'fr', 'es']);
    expect(
        kInterfaceLanguages.map((l) => l.autonym), everyElement(isNotEmpty));
    // Правка приёмки 06.10.2026: en в списке (фолбэк локализации и
    // легаси-значение), но скрыт из пикеров; выбираемые языки — ровно
    // коды с переводами в словаре.
    expect(kInterfaceLanguages.first.code, SettingsService.englishLanguage);
    expect(kInterfaceLanguages.first.selectable, isFalse);
    expect(
      kInterfaceLanguages
          .where((l) => l.selectable)
          .map((l) => l.code)
          .toSet(),
      SettingsService.translationLanguageCodes,
    );
  });

  // --- миграция v1/v2 → v3 (правка приёмки 05.10.2026) ---

  test('v2: interface ≠ system → он (приоритет выбору интерфейса)', () async {
    storageFile().writeAsStringSync(jsonEncode(<String, Object>{
      'version': 2,
      'interfaceLanguage': 'de',
      'translationLanguage': 'fr',
    }));
    final service = buildService();
    await service.load();
    expect(service.appLanguage.value, 'de');
    expect(service.languagePromptShown, isTrue,
        reason: 'онбординги уже показывались — не спрашиваем повторно');
    expect(service.onboardingShown, isTrue);
    service.dispose();
  });

  test('v2: interface system + translations ≠ ru → переводы', () async {
    storageFile().writeAsStringSync(jsonEncode(<String, Object>{
      'version': 2,
      'interfaceLanguage': 'system',
      'translationLanguage': 'id',
    }));
    final service = buildService();
    await service.load();
    expect(service.appLanguage.value, 'id');
    expect(service.languagePromptShown, isTrue);
    service.dispose();
  });

  test('v2: interface system + translations ru → system', () async {
    storageFile().writeAsStringSync(jsonEncode(<String, Object>{
      'version': 2,
      'interfaceLanguage': 'system',
      'translationLanguage': 'ru',
    }));
    final service = buildService();
    await service.load();
    expect(service.appLanguage.value, SettingsService.systemLanguage);
    expect(service.languagePromptShown, isTrue);
    service.dispose();
  });

  test('v1/v2 мусорные значения → system, флаги → true', () async {
    storageFile().writeAsStringSync(jsonEncode(<String, Object>{
      'version': 2,
      'interfaceLanguage': 'kk',
      'translationLanguage': 'kk',
    }));
    final garbage = buildService();
    await garbage.load();
    expect(garbage.appLanguage.value, SettingsService.systemLanguage);
    expect(garbage.languagePromptShown, isTrue);
    garbage.dispose();

    storageFile().writeAsStringSync(jsonEncode(<String, Object>{
      'version': 1,
      'interfaceLanguage': 'es',
    }));
    final v1 = buildService();
    await v1.load();
    expect(v1.appLanguage.value, 'es');
    expect(v1.onboardingShown, isTrue);
    v1.dispose();

    storageFile().writeAsStringSync(jsonEncode(<String, Object>{
      'version': 1,
      'interfaceLanguage': 'system',
    }));
    final v1System = buildService();
    await v1System.load();
    expect(v1System.appLanguage.value, SettingsService.systemLanguage);
    v1System.dispose();
  });

  test('запись после миграции пишет schema v3', () async {
    storageFile().writeAsStringSync(jsonEncode(<String, Object>{
      'version': 2,
      'interfaceLanguage': 'de',
      'translationLanguage': 'fr',
    }));
    final service = buildService();
    await service.load();
    await service.setAppLanguage('de'); // тот же выбор — файл перепишется

    final decoded =
        jsonDecode(storageFile().readAsStringSync()) as Map<String, dynamic>;
    expect(decoded['version'], 3);
    expect(decoded['appLanguage'], 'de');
    expect(decoded['languagePromptShown'], isTrue);
    expect(decoded.containsKey('interfaceLanguage'), isFalse);
    expect(decoded.containsKey('translationLanguage'), isFalse);
    service.dispose();
  });

  test('markLanguagePromptShown / markOnboardingShown: флаги + файл',
      () async {
    final service = buildService();
    await service.markLanguagePromptShown();
    expect(service.languagePromptShown, isTrue);
    expect(service.onboardingShown, isFalse, reason: 'флаги независимы');

    await service.markOnboardingShown();
    expect(service.onboardingShown, isTrue);

    final raw = storageFile().readAsStringSync();
    expect(raw, contains('"languagePromptShown": true'));
    expect(raw, contains('"onboardingShown": true'));
    service.dispose();
  });

  // --- чистые резолвы (платформа не нужна) ---

  test('interfaceLanguageForSystemLocale: канонизация «in» и фолбэк en', () {
    expect(SettingsService.interfaceLanguageForSystemLocale(
        const Locale('ru')), 'ru');
    expect(SettingsService.interfaceLanguageForSystemLocale(
        const Locale('in')), 'id'); // legacy-код Android
    expect(SettingsService.interfaceLanguageForSystemLocale(
        const Locale('de')), 'de');
    expect(SettingsService.interfaceLanguageForSystemLocale(
        const Locale('ja')), 'en'); // неподдержанная → фолбэк
    expect(SettingsService.interfaceLanguageForSystemLocale(
        const Locale('en')), 'en');
  });

  test('resolveInterfaceLanguage: ручной — сам, system — по локали', () {
    expect(
        SettingsService.resolveInterfaceLanguage('de', const Locale('ru')),
        'de');
    expect(
        SettingsService.resolveInterfaceLanguage('en', const Locale('ru')),
        'en',
        reason: 'легаси-«en» тихо чтится — режим под капотом');
    expect(
        SettingsService.resolveInterfaceLanguage(
            SettingsService.systemLanguage, const Locale('de')),
        'de');
    expect(
        SettingsService.resolveInterfaceLanguage(
            SettingsService.systemLanguage, const Locale('in')),
        'id',
        reason: 'legacy-код Android канонизируется');
    expect(
        SettingsService.resolveInterfaceLanguage(
            SettingsService.systemLanguage, const Locale('ja')),
        'en',
        reason: 'неподдержанная локаль → en-фолбэк');
  });

  test('resolveTranslationLanguage: ручной выбор, en → русский', () {
    expect(
      SettingsService.resolveTranslationLanguage('fr', const Locale('ru')),
      'fr',
    );
    expect(
      SettingsService.resolveTranslationLanguage('en', const Locale('ru')),
      'ru',
      reason: 'английских переводов в словаре нет',
    );
  });

  test('resolveTranslationLanguage: system — по системной локали', () {
    expect(
      SettingsService.resolveTranslationLanguage(
          SettingsService.systemLanguage, const Locale('de')),
      'de',
    );
    expect(
      SettingsService.resolveTranslationLanguage(
          SettingsService.systemLanguage, const Locale('in')),
      'id',
      reason: 'legacy-код Android канонизируется',
    );
    expect(
      SettingsService.resolveTranslationLanguage(
          SettingsService.systemLanguage, const Locale('en')),
      'ru',
      reason: 'en-локаль → русский дефолт',
    );
    expect(
      SettingsService.resolveTranslationLanguage(
          SettingsService.systemLanguage, const Locale('ja')),
      'ru',
      reason: 'неподдержанная локаль → русский дефолт',
    );
  });

  test('shouldPromptLanguage: один раз, только в режиме system и без en',
      () {
    expect(
      SettingsService.shouldPromptLanguage(
        promptShown: false,
        appLanguage: SettingsService.systemLanguage,
        systemLocale: const Locale('en'),
      ),
      isTrue,
    );
    expect(
      SettingsService.shouldPromptLanguage(
        promptShown: false,
        appLanguage: SettingsService.systemLanguage,
        systemLocale: const Locale('ja'),
      ),
      isTrue,
      reason: 'неподдержанная локаль — тоже en-фолбэк',
    );
    expect(
      SettingsService.shouldPromptLanguage(
        promptShown: true,
        appLanguage: SettingsService.systemLanguage,
        systemLocale: const Locale('en'),
      ),
      isFalse,
      reason: 'уже спрашивали',
    );
    expect(
      SettingsService.shouldPromptLanguage(
        promptShown: false,
        appLanguage: 'en',
        systemLocale: const Locale('en'),
      ),
      isFalse,
      reason: 'ручной выбор сделан — вопрос не нужен',
    );
    expect(
      SettingsService.shouldPromptLanguage(
        promptShown: false,
        appLanguage: SettingsService.systemLanguage,
        systemLocale: const Locale('ru'),
      ),
      isFalse,
      reason: 'поддержанная локаль обошлась без вопроса',
    );
  });
}