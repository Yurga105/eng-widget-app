import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Язык интерфейса, который пользователь может выбрать вручную
/// (этап 18, идея B-005). [autonym] — название «на самом языке»
/// («Русский», «Deutsch»): аутонимы не переводятся, поэтому живут
/// в коде, а не в ARB-файлах — одинаковые в любой локали.
class InterfaceLanguage {
  const InterfaceLanguage(this.code, this.autonym);

  /// Код локали: ключ `settings.json` и [Locale.languageCode].
  final String code;

  /// Название для пикера настроек (одинаковое во всех локалях).
  final String autonym;
}

/// Языки интерфейса пикера настроек — единственная точка расширения:
/// новый язык = ARB-файл `app_xx.arb` (+ нативные строки по образцу
/// существующих) и одна строка здесь; валидация, пикер и тесты читают
/// этот список. en в списке нет сознательно: он template-фолбэк
/// локализации (неподдержанная системная локаль → en, `l10n.yaml`) и
/// вручную не выбирается.
const List<InterfaceLanguage> kInterfaceLanguages = <InterfaceLanguage>[
  InterfaceLanguage('ru', 'Русский'),
  InterfaceLanguage('id', 'Bahasa Indonesia'),
  InterfaceLanguage('de', 'Deutsch'),
  InterfaceLanguage('fr', 'Français'),
  InterfaceLanguage('es', 'Español'),
];

/// Настройки приложения (этапы 18–19, идея B-005): язык интерфейса
/// (schema v1) и язык переводов слов (этап 19, schema v2).
///
/// Хранение — JSON-файл `documents/settings.json` по паттерну
/// `FavoriteService` (этап 13): инжектируемый каталог documents, после
/// его резолва — синхронный файловый IO (детерминирован в fake-async
/// тестах), «тихие» ошибки — смена языка не должна ронять приложение.
/// В окружении без плагина path_provider (тесты виджетов) сервис
/// молча работает с системным языком.
///
/// Состояние — публичные нотифаеры: [localeOverride]
/// (`ValueNotifier<String?>`, null = «как в системе») и
/// [translationLanguage] (`ValueNotifier<String>`, язык переводов,
/// этап 19): `main.dart` пересобирает MaterialApp по первому, экран
/// настроек слушает оба — смена языка мгновенная, без перезапуска.
class SettingsService {
  SettingsService({Future<Directory> Function()? documentsDirectory})
      : _documentsDirectory =
                documentsDirectory ?? getApplicationDocumentsDirectory {
    // Читаем файл сразу при создании: override подхватится, когда
    // данные готовы (первый кадр — системная локаль, без блокировки).
    unawaited(load());
  }

  /// Имя файла хранения в каталоге documents.
  static const String fileName = 'settings.json';

  /// Значение «как в системе» в `settings.json`.
  static const String systemLanguage = 'system';

  /// Язык переводов по умолчанию (этап 19): он есть у каждой записи
  /// словаря v2; файлы настроек v1 без ключа читаются как «ru».
  static const String defaultTranslationLanguage = 'ru';

  final Future<Directory> Function() _documentsDirectory;

  /// Выбранный язык интерфейса: код из [kInterfaceLanguages] или
  /// null — «как в системе» (обычная резолв локали MaterialApp).
  final ValueNotifier<String?> localeOverride = ValueNotifier<String?>(null);

  /// Язык, на котором показываются перевод и пример слова (этап 19,
  /// часть 2): один из кодов [kInterfaceLanguages], без опции «как в
  /// системе» — по умолчанию [defaultTranslationLanguage].
  final ValueNotifier<String> translationLanguage =
      ValueNotifier<String>(defaultTranslationLanguage);

  /// Стартовое чтение: выполняется один раз; повторные вызовы [load]
  /// ждут тот же future (детерминизм в тестах).
  Future<void>? _loading;

  /// Локаль для `MaterialApp.locale`: null — системная резолюция
  /// (включая канонизацию legacy-кода Android «in» → «id»), иначе
  /// выбранный в настройках язык.
  Locale? get locale {
    final code = localeOverride.value;
    if (code == null || code == systemLanguage) {
      return null;
    }
    return Locale(code);
  }

  /// Прочитать сохранённый выбор (перезапуск приложения). Битый файл,
  /// ошибки плагина — тихий «как в системе» (мягкая деградация, §9).
  Future<void> load() => _loading ??= _loadFromFile();

  Future<void> _loadFromFile() async {
    try {
      final file = await _fileFor();
      if (!file.existsSync()) {
        return; // первый запуск — системная локаль
      }
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('верхний уровень — не объект');
      }
      localeOverride.value = _validated(decoded['interfaceLanguage']);
      translationLanguage.value =
          _validatedTranslation(decoded['translationLanguage']);
    } catch (e) {
      debugPrint(
          'Settings: $fileName не прочитан ($e) — значения по умолчанию');
      localeOverride.value = null;
      translationLanguage.value = defaultTranslationLanguage;
    }
  }

  /// Выбрать язык интерфейса (экран настроек). null или [systemLanguage]
  /// — «как в системе»; неизвестный код тихо превращается в «как в
  /// системе» (та же валидация, что при чтении). Нотифаер обновляется
  /// сразу — UI отзывчив; при сбое записи файл отстанет от выбора
  /// (после перезапуска вернёмся к последней успешной записи).
  Future<void> setInterfaceLanguage(String? code) async {
    await load(); // стартовое чтение завершилось до первой записи
    final normalized = _validated(code);
    localeOverride.value = normalized;
    try {
      final file = await _fileFor();
      file.writeAsStringSync(_encode(normalized), flush: true);
    } catch (e) {
      debugPrint('Settings: $fileName не записан ($e)');
    }
  }

  /// Выбрать язык переводов слов и примеров (этап 19, часть 2).
  /// Неизвестный код тихо заменяется дефолтом [defaultTranslationLanguage]
  /// (та же валидация, что при чтении). Нотифаер обновляется сразу — UI
  /// отзывчив; слушателей карточки/виджета/уведомлений подключают
  /// шаги 4–6 этапа 19.
  Future<void> setTranslationLanguage(String code) async {
    await load(); // стартовое чтение завершилось до первой записи
    final normalized = _validatedTranslation(code);
    translationLanguage.value = normalized;
    try {
      final file = await _fileFor();
      file.writeAsStringSync(_encode(localeOverride.value), flush: true);
    } catch (e) {
      debugPrint('Settings: $fileName не записан ($e)');
    }
  }

  /// Валидные значения: [systemLanguage] (→ null) или код из
  /// [kInterfaceLanguages]; устаревшее/кривое — «как в системе».
  String? _validated(Object? raw) {
    if (raw is! String || raw == systemLanguage) {
      return null;
    }
    return kInterfaceLanguages.any((l) => l.code == raw) ? raw : null;
  }

  /// Валидные значения языка переводов: код из [kInterfaceLanguages];
  /// устаревшее/кривое — дефолт [defaultTranslationLanguage] («ru»).
  String _validatedTranslation(Object? raw) {
    if (raw is! String) {
      return defaultTranslationLanguage;
    }
    return kInterfaceLanguages.any((l) => l.code == raw)
        ? raw
        : defaultTranslationLanguage;
  }

  /// Schema v2 (этап 19): обе настройки в одном файле. Файлы v1 читаются
  /// без миграции — отсутствующий `translationLanguage` получит дефолт.
  String _encode(String? interfaceCode) =>
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'version': 2,
        'interfaceLanguage': interfaceCode ?? systemLanguage,
        'translationLanguage': translationLanguage.value,
      });

  Future<File> _fileFor() async {
    final dir = await _documentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  /// Освободить слушателей; вызывается из `dispose` владельца в main.
  void dispose() {
    localeOverride.dispose();
    translationLanguage.dispose();
  }
}