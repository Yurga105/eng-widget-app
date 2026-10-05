import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:eng_widget_app/services/settings_service.dart';

/// Тесты SettingsService (этап 18): каталог documents подменяется
/// временным — паттерн favorite_service_test.
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

  test('load: файла нет → «как в системе», файл не создаётся', () async {
    final service = buildService();
    await service.load();

    expect(service.localeOverride.value, isNull);
    expect(service.locale, isNull);
    expect(storageFile().existsSync(), isFalse,
        reason: 'системный выбор не порождает файл');
    service.dispose();
  });

  test('setInterfaceLanguage: код сохраняется в нотифаер и файл', () async {
    final service = buildService();
    await service.setInterfaceLanguage('de');

    expect(service.localeOverride.value, 'de');
    expect(service.locale!.languageCode, 'de');
    expect(storageFile().readAsStringSync(), contains('"de"'));
    service.dispose();
  });

  test('setInterfaceLanguage(null/system): сброс на системную локаль',
      () async {
    final service = buildService();
    await service.setInterfaceLanguage('ru');
    expect(service.localeOverride.value, 'ru');

    await service.setInterfaceLanguage(null);
    expect(service.localeOverride.value, isNull);
    expect(storageFile().readAsStringSync(),
        contains('"interfaceLanguage": "system"'));

    await service.setInterfaceLanguage(SettingsService.systemLanguage);
    expect(service.localeOverride.value, isNull);
    service.dispose();
  });

  test('нотифаер оповещает слушателей (main.dart пересобирает MaterialApp)',
      () async {
    final service = buildService();
    final values = <String?>[];
    void listen() => values.add(service.localeOverride.value);
    service.localeOverride.addListener(listen);

    await service.setInterfaceLanguage('es');
    await service.setInterfaceLanguage(null);

    expect(values, ['es', null]);
    service.localeOverride.removeListener(listen);
    service.dispose();
  });

  test('персистентность: выбор переживает новый экземпляр сервиса', () async {
    final first = buildService();
    await first.setInterfaceLanguage('fr');
    first.dispose();

    final second = buildService();
    await second.load();
    expect(second.localeOverride.value, 'fr');
    expect(second.locale!.languageCode, 'fr');
    second.dispose();
  });

  test('битый JSON → тихий «как в системе»', () async {
    storageFile().writeAsStringSync('{ не json');
    final service = buildService();
    await service.load();
    expect(service.localeOverride.value, isNull);
    service.dispose();
  });

  test('мусорные значения файла → «как в системе», валидные читаются',
      () async {
    storageFile().writeAsStringSync(jsonEncode(<String, Object>{
      'version': 1,
      'interfaceLanguage': 'kk', // язык не поддерживается
    }));
    final unknown = buildService();
    await unknown.load();
    expect(unknown.localeOverride.value, isNull);
    unknown.dispose();

    storageFile().writeAsStringSync(jsonEncode(<String, Object>{
      'version': 1,
      'interfaceLanguage': 42, // не строка
    }));
    final wrongType = buildService();
    await wrongType.load();
    expect(wrongType.localeOverride.value, isNull);
    wrongType.dispose();

    storageFile().writeAsStringSync(jsonEncode(<String, Object>{
      'version': 1,
      'interfaceLanguage': 'id',
    }));
    final valid = buildService();
    await valid.load();
    expect(valid.localeOverride.value, 'id');
    valid.dispose();
  });

  test('неизвестный код при выборе → «как в системе» (валидация записи)',
      () async {
    final service = buildService();
    await service.setInterfaceLanguage('xx');
    expect(service.localeOverride.value, isNull);
    expect(storageFile().readAsStringSync(),
        contains('"interfaceLanguage": "system"'));
    service.dispose();
  });

  test('сбой каталога documents → тихо, нотифаер живёт', () async {
    final service = SettingsService(
      documentsDirectory: () async => throw Exception('нет path_provider'),
    );
    await service.load();
    expect(service.localeOverride.value, isNull);

    await service.setInterfaceLanguage('ru'); // запись упадёт — молча
    expect(service.localeOverride.value, 'ru');
    service.dispose();
  });

  test('kInterfaceLanguages: 5 языков, autonym у каждого, en отсутствует', () {
    expect(
        kInterfaceLanguages.map((l) => l.code), ['ru', 'id', 'de', 'fr', 'es']);
    expect(kInterfaceLanguages.map((l) => l.autonym), everyElement(isNotEmpty));
    expect(kInterfaceLanguages.any((l) => l.code == 'en'), isFalse,
        reason: 'en — template-фолбэк, опцией не выбирается');
  });

  test('load: файла нет → язык переводов по умолчанию «ru»', () async {
    final service = buildService();
    await service.load();
    expect(service.translationLanguage.value,
        SettingsService.defaultTranslationLanguage);
    service.dispose();
  });

  test('v1-файл без translationLanguage → «ru», миграция не нужна', () async {
    storageFile().writeAsStringSync(jsonEncode(<String, Object>{
      'version': 1,
      'interfaceLanguage': 'de',
    }));
    final service = buildService();
    await service.load();
    expect(service.localeOverride.value, 'de');
    expect(service.translationLanguage.value, 'ru');
    service.dispose();
  });

  test('setTranslationLanguage: нотифаер + файл v2, интерфейс сохраняется',
      () async {
    final service = buildService();
    await service.setInterfaceLanguage('id');
    await service.setTranslationLanguage('fr');

    expect(service.translationLanguage.value, 'fr');
    final raw = storageFile().readAsStringSync();
    expect(raw, contains('"translationLanguage": "fr"'));
    expect(raw, contains('"interfaceLanguage": "id"'));
    expect(raw, contains('"version": 2'));
    service.dispose();
  });

  test('мусор в translationLanguage файла → дефолт «ru»', () async {
    storageFile().writeAsStringSync(jsonEncode(<String, Object>{
      'version': 2,
      'interfaceLanguage': 'system',
      'translationLanguage': 'kk', // язык не поддерживается
    }));
    final unknown = buildService();
    await unknown.load();
    expect(unknown.translationLanguage.value, 'ru');
    unknown.dispose();

    storageFile().writeAsStringSync(jsonEncode(<String, Object>{
      'version': 2,
      'translationLanguage': 42, // не строка
    }));
    final wrongType = buildService();
    await wrongType.load();
    expect(wrongType.translationLanguage.value, 'ru');
    wrongType.dispose();
  });

  test('неизвестный код при выборе → дефолт «ru» (валидация записи)',
      () async {
    final service = buildService();
    await service.setTranslationLanguage('xx');
    expect(service.translationLanguage.value, 'ru');
    expect(storageFile().readAsStringSync(),
        contains('"translationLanguage": "ru"'));
    service.dispose();
  });

  test('язык переводов переживает новый экземпляр сервиса', () async {
    final first = buildService();
    await first.setTranslationLanguage('es');
    first.dispose();

    final second = buildService();
    await second.load();
    expect(second.translationLanguage.value, 'es');
    second.dispose();
  });
}