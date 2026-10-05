import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:path_provider/path_provider.dart';

/// Язык приложения, который пользователь может выбрать вручную
/// (этапы 18–19, идея B-005). [autonym] — название «на самом языке»
/// («Русский», «Deutsch»): аутонимы не переводятся, поэтому живут
/// в коде, а не в ARB-файлах — одинаковые в любой локали.
class InterfaceLanguage {
  const InterfaceLanguage(this.code, this.autonym);

  /// Код локали: ключ `settings.json` и [Locale.languageCode].
  final String code;

  /// Название для пикеров (одинаковое во всех локалях).
  final String autonym;
}

/// Языки приложения — единственная точка расширения: новый язык =
/// ARB-файл `app_xx.arb` (+ нативные строки по образцу существующих),
/// переводы в словаре v2 и одна строка здесь; валидация, пикеры и
/// тесты читают этот список. en в списке есть (правка приёмки
/// 05.10.2026): он template-фолбэк локализации (неподдержанная
/// системная локаль → en, `l10n.yaml`) и выбирается онбордингом/
/// настройками; английских переводов слов в словаре нет (приложение
/// учит английскому), поэтому для «en» переводы остаются русскими —
/// см. [SettingsService.resolveTranslationLanguage].
const List<InterfaceLanguage> kInterfaceLanguages = <InterfaceLanguage>[
  InterfaceLanguage('en', 'English'),
  InterfaceLanguage('ru', 'Русский'),
  InterfaceLanguage('id', 'Bahasa Indonesia'),
  InterfaceLanguage('de', 'Deutsch'),
  InterfaceLanguage('fr', 'Français'),
  InterfaceLanguage('es', 'Español'),
];

/// Настройки приложения (этапы 18–19, идея B-005; правка приёмки
/// 05.10.2026): единый язык приложения — интерфейс, переводы слов,
/// виджет и уведомление (schema v3).
///
/// Правка приёмки 05.10.2026 (репорт этапа 19): вместо двух независимых
/// настроек (язык интерфейса v1 + язык переводов v2) — одна: код из
/// [kInterfaceLanguages] или [systemLanguage] — «как в системе», когда
/// интерфейс и переводы следуют системной локали устройства. Системная
/// en/неподдержанная локаль: интерфейс — English, а онбординг один раз
/// предлагает выбрать язык ([languagePromptShown],
/// `language_pick_screen.dart`). Ручной «en» — интерфейс English с
/// русскими переводами слов.
///
/// Хранение — JSON-файл `documents/settings.json` по паттерну
/// `FavoriteService` (этап 13): инжектируемый каталог documents, после
/// его резолва — синхронный файловый IO (детерминирован в fake-async
/// тестах), «тихие» ошибки — смена языка не должна ронять приложение.
/// Файлы v1/v2 (две настройки) читаются с миграцией: старые настройки
/// схлопываются в [appLanguage] (приоритет — выбору интерфейса),
/// онбординги считаются показанными — приложением уже пользовались.
///
/// Состояние — нотифаер [appLanguage] (`ValueNotifier<String>`):
/// `main.dart` пересобирает MaterialApp и перепланирует виджет/
/// уведомление, экран настроек и онбординг-пикер слушают его — смена
/// языка мгновенная, без перезапуска.
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

  /// Код английского: фолбэк локализации интерфейса; выбирается
  /// онбордингом/настройками, переводов слов для него в словаре нет.
  static const String englishLanguage = 'en';

  /// Язык переводов по умолчанию: он есть у каждой записи словаря v2.
  static const String defaultTranslationLanguage = 'ru';

  /// Коды языков с переводами в словаре v2 (этап 19): все языки
  /// приложения, кроме английского.
  static const Set<String> translationLanguageCodes = <String>{
    'ru', 'id', 'de', 'fr', 'es',
  };

  final Future<Directory> Function() _documentsDirectory;

  /// Единый язык приложения: код из [kInterfaceLanguages] или
  /// [systemLanguage] — «как в системе» (интерфейс — обычная резолв
  /// MaterialApp, переводы — [resolveTranslationLanguage]).
  final ValueNotifier<String> appLanguage =
      ValueNotifier<String>(systemLanguage);

  /// Онбординг-пикер языка уже показывался: выбор сделан или системная
  /// локаль поддержана переводами — вопрос не нужен.
  bool languagePromptShown = false;

  /// Знакомство с функционалом (этап 20) уже показывалось.
  bool onboardingShown = false;

  /// Стартовое чтение: выполняется один раз; повторные вызовы [load]
  /// ждут тот же future (детерминизм в тестах).
  Future<void>? _loading;

  bool _loaded = false;

  /// Стартовое чтение завершилось (файл прочитан или тихий дефолт):
  /// гейты онбордингов в main.dart смотрят сюда, чтобы не спрашивать
  /// до того, как файл прочитан.
  bool get isLoaded => _loaded;

  /// Локаль для `MaterialApp.locale`: null — системная резолюция
  /// (включая канонизацию legacy-кода Android «in» → «id»), иначе
  /// выбранный язык приложения.
  Locale? get locale {
    final code = appLanguage.value;
    if (code == systemLanguage) {
      return null;
    }
    return Locale(code);
  }

  /// Язык приложения из системной локали: канонизация legacy-кода
  /// Android «in» → «id»; неподдержанная → «en» (template-фолбэк
  /// локализации, `l10n.yaml`).
  static String interfaceLanguageForSystemLocale(Locale locale) {
    final code = locale.languageCode == 'in' ? 'id' : locale.languageCode;
    for (final language in kInterfaceLanguages) {
      if (language.code == code) {
        return language.code;
      }
    }
    return englishLanguage;
  }

  /// Чистый резолв языка переводов (тестируется без платформы).
  /// Ручной выбор — он сам, «en» → [defaultTranslationLanguage]
  /// (английских переводов в словаре нет). «system» — язык системной
  /// локали, если словарь его переводит, иначе русский дефолт.
  static String resolveTranslationLanguage(
    String appLanguage,
    Locale systemLocale,
  ) {
    if (appLanguage != systemLanguage) {
      return appLanguage == englishLanguage
          ? defaultTranslationLanguage
          : appLanguage;
    }
    final system = interfaceLanguageForSystemLocale(systemLocale);
    return translationLanguageCodes.contains(system)
        ? system
        : defaultTranslationLanguage;
  }

  /// Чистый предикат гейта онбординга языка: язык ещё не спрашивали,
  /// режим «как в системе», системная локаль не поддержана переводами
  /// (интерфейс ушёл в en-фолбэк).
  static bool shouldPromptLanguage({
    required bool promptShown,
    required String appLanguage,
    required Locale systemLocale,
  }) {
    if (promptShown || appLanguage != systemLanguage) {
      return false;
    }
    final system = interfaceLanguageForSystemLocale(systemLocale);
    return !translationLanguageCodes.contains(system);
  }

  /// Язык переводов слов/примеров сейчас: ручной выбор или системная
  /// локаль в режиме «как в системе». Читатели в build (карточка,
  /// избранное, квиз, постер) и проводка виджета/уведомления в main.
  String get effectiveTranslationLanguage => resolveTranslationLanguage(
        appLanguage.value,
        WidgetsBinding.instance.platformDispatcher.locale,
      );

  /// Нужен ли онбординг-пикер языка — см. [shouldPromptLanguage].
  bool get needsLanguagePrompt => shouldPromptLanguage(
        promptShown: languagePromptShown,
        appLanguage: appLanguage.value,
        systemLocale: WidgetsBinding.instance.platformDispatcher.locale,
      );

  /// Прочитать сохранённый выбор (перезапуск приложения). Битый файл,
  /// ошибки плагина — тихие дефолты (мягкая деградация, §9).
  Future<void> load() => _loading ??= _loadFromFile();

  Future<void> _loadFromFile() async {
    try {
      final file = await _fileFor();
      if (!file.existsSync()) {
        return; // первый запуск — дефолты («system», онбординги впереди)
      }
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('верхний уровень — не объект');
      }
      _decode(decoded);
    } catch (e) {
      debugPrint(
          'Settings: $fileName не прочитан ($e) — значения по умолчанию');
      appLanguage.value = systemLanguage;
      languagePromptShown = false;
      onboardingShown = false;
    } finally {
      _loaded = true;
    }
  }

  /// Мигрирующее чтение: v3 — как есть; v1/v2 — старые настройки
  /// схлопываются в [appLanguage] (приоритет — выбору интерфейса),
  /// онбординги считаются показанными: приложением уже пользовались.
  void _decode(Map<String, dynamic> decoded) {
    final version = (decoded['version'] as num?)?.toInt() ?? 1;
    if (version >= 3) {
      appLanguage.value = _validatedAppLanguage(decoded['appLanguage']);
      languagePromptShown = decoded['languagePromptShown'] == true;
      onboardingShown = decoded['onboardingShown'] == true;
      return;
    }
    final interface = _validatedAppLanguage(decoded['interfaceLanguage']);
    if (interface != systemLanguage) {
      appLanguage.value = interface;
    } else if (version >= 2) {
      final translations = decoded['translationLanguage'];
      if (translations is String &&
          translationLanguageCodes.contains(translations) &&
          translations != defaultTranslationLanguage) {
        appLanguage.value = translations;
      }
    }
    languagePromptShown = true;
    onboardingShown = true;
  }

  /// Валидные значения: [systemLanguage] или код из [kInterfaceLanguages];
  /// устаревшее/кривое — «как в системе».
  String _validatedAppLanguage(Object? raw) {
    if (raw is! String) {
      return systemLanguage;
    }
    return raw == systemLanguage ||
            kInterfaceLanguages.any((language) => language.code == raw)
        ? raw
        : systemLanguage;
  }

  /// Выбрать язык приложения (экран настроек / онбординг-пикер).
  /// [systemLanguage] — «как в системе»; неизвестный код тихо
  /// превращается в «как в системе» (та же валидация, что при чтении).
  /// Нотифаер обновляется сразу — UI отзывчив; при сбое записи файл
  /// отстанет от выбора (после перезапуска вернёмся к последней
  /// успешной записи).
  Future<void> setAppLanguage(String code) async {
    await load(); // стартовое чтение завершилось до первой записи
    final normalized = _validatedAppLanguage(code);
    appLanguage.value = normalized;
    await _persist();
  }

  /// Запомнить, что онбординг-пикер языка показан (выбор сделан или
  /// системная локаль поддержана переводами — вопрос не понадобился).
  /// Флаг ставится сразу (до записи) — гейты перестают спрашивать
  /// детерминированно, даже до завершения файлового IO.
  Future<void> markLanguagePromptShown() async {
    languagePromptShown = true;
    await load();
    await _persist();
  }

  /// Запомнить, что знакомство с функционалом показано (этап 20).
  /// Флаг ставится сразу — гейт в main.dart закрывается мгновенно.
  Future<void> markOnboardingShown() async {
    onboardingShown = true;
    await load();
    await _persist();
  }

  /// Записать файл; сбой тихий — состояние нотифаера уже верное.
  Future<void> _persist() async {
    try {
      final file = await _fileFor();
      file.writeAsStringSync(_encode(), flush: true);
    } catch (e) {
      debugPrint('Settings: $fileName не записан ($e)');
    }
  }

  /// Schema v3 (правка приёмки 05.10.2026): один язык приложения и
  /// флаги онбордингов. Файлы v1/v2 читаются с миграцией ([_decode]),
  /// любая запись после чтения пишет v3.
  String _encode() =>
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'version': 3,
        'appLanguage': appLanguage.value,
        'languagePromptShown': languagePromptShown,
        'onboardingShown': onboardingShown,
      });

  Future<File> _fileFor() async {
    final dir = await _documentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  /// Освободить слушателей; вызывается из `dispose` владельца в main.
  void dispose() {
    appLanguage.dispose();
  }
}