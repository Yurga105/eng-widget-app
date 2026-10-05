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

/// Настройки приложения (этап 18, идея B-005): пока одна — язык
/// интерфейса.
///
/// Хранение — JSON-файл `documents/settings.json` по паттерну
/// `FavoriteService` (этап 13): инжектируемый каталог documents, после
/// его резолва — синхронный файловый IO (детерминирован в fake-async
/// тестах), «тихие» ошибки — смена языка не должна ронять приложение.
/// В окружении без плагина path_provider (тесты виджетов) сервис
/// молча работает с системным языком.
///
/// Состояние — публичный [localeOverride] (`ValueNotifier<String?>`,
/// null = «как в системе»): `main.dart` пересобирает MaterialApp с
/// новым `locale`, экран настроек слушает тот же нотифаер — смена
/// языка мгновенная, без перезапуска приложения.
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

  final Future<Directory> Function() _documentsDirectory;

  /// Выбранный язык интерфейса: код из [kInterfaceLanguages] или
  /// null — «как в системе» (обычная резолв локали MaterialApp).
  final ValueNotifier<String?> localeOverride = ValueNotifier<String?>(null);

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
    } catch (e) {
      debugPrint('Settings: $fileName не прочитан ($e) — системный язык');
      localeOverride.value = null;
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

  /// Валидные значения: [systemLanguage] (→ null) или код из
  /// [kInterfaceLanguages]; устаревшее/кривое — «как в системе».
  String? _validated(Object? raw) {
    if (raw is! String || raw == systemLanguage) {
      return null;
    }
    return kInterfaceLanguages.any((l) => l.code == raw) ? raw : null;
  }

  String _encode(String? code) =>
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'version': 1,
        'interfaceLanguage': code ?? systemLanguage,
      });

  Future<File> _fileFor() async {
    final dir = await _documentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  /// Освободить слушателей; вызывается из `dispose` владельца в main.
  void dispose() => localeOverride.dispose();
}