import 'dart:async';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import 'l10n/generated/app_localizations.dart';
import 'services/notification_service.dart';
import 'services/quiz_service.dart';
import 'services/settings_service.dart';
import 'services/widget_sync_service.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/language_pick_screen.dart';
import 'ui/screens/welcome_screen.dart';

void main() {
  runApp(const WordOfTheDayApp());
}

/// Корневой виджет приложения «Слово дня» — этапы 4–7:
/// мост с виджетом и уведомления.
///
/// Здесь живёт «проводка» этапов 4–7 (PLAN.md §8):
///  - при старте и возврате на передний план — синхронизация слова дня
///    в виджет ([WidgetSyncService.syncToday]);
///  - таймер на локальную полуночь — смена слова, пока приложение живо
///    (полностью автономная смена — этап 5);
///  - приём тапов виджета: URI `wordoftheday://word?date=…` при холодном
///    старте ([HomeWidget.initiallyLaunchedFromHomeWidget]) и в тёплом
///    режиме (стрим [HomeWidget.widgetClicked]) → [HomeScreen] показывает
///    карточку этой даты;
///  - этап 7: старт [NotificationService] (разрешение спрашиваем один раз
///    за запуск, расписание уведомления в 09:00), перепланирование в
///    полночь и на резюме; тап по уведомлению — тот же URI-контракт,
///    что и у виджета (холодный старт — через payload запуска);
///  - этап 14: квиз-повторение — [QuizService] (один на приложение:
///    история результатов для напоминаний и экрана) и одноразовое
///    напоминание о квизе (перепланирование: старт/резюм/полночь и
///    завершение квиза; тап — payload `wordoftheday://quiz` — открывает
///    экран квиза сигналом [_quizOpenRequest]);
///  - этап 17 (идея B-009): preload-экран приветствия [WelcomeScreen]
///    на холодном старте обычного запуска (1,5 с, тап = пропуск);
///    старт по дееплинку (виджет/уведомление/квиз) приветствие
///    пропускает — до резолва стартового URI/payload первый кадр
///    пустой (фон нативного сплэша `#F1F8E9`, вспышки нет).
///
/// Темы Material 3 со seed-цветом «мягкий зелёный» (редизайн для аудитории
/// Индонезии: светлая природная палитра вместо индиго и тёмной темы),
/// локализация интерфейса en/ru/id/de/fr/es — системная локаль или
/// ручной выбор (см. `lib/l10n/`).
///
/// Этапы 18–19 (идея B-005; правка приёмки 05.10.2026): [SettingsService]
/// — единый язык приложения (интерфейс + переводы слов). Нотифаер
/// слушается в [build]: смена языка пересобирает MaterialApp с новым
/// `locale` мгновенно; «как в системе» — обычная резолв MaterialApp,
/// смену системного языка на лету доспанивает [didChangeLocales].
/// Системная локаль en/неподдержанная — один раз [LanguagePickScreen]
/// (гейт в [build]), затем обычный маршрут.
class WordOfTheDayApp extends StatefulWidget {
  const WordOfTheDayApp({super.key});

  @override
  State<WordOfTheDayApp> createState() => _WordOfTheDayAppState();
}

class _WordOfTheDayAppState extends State<WordOfTheDayApp>
    with WidgetsBindingObserver {
  final WidgetSyncService _widgetSync = WidgetSyncService();

  /// Уведомления «слово дня» — этап 7. Создаётся в [initState]:
  /// колбэк «открыть карточку» ссылается на `_widgetTapDate`, поэтому
  /// в инициализаторе поля его не построить.
  NotificationService? _notifications;

  /// Дата из последнего тапа по виджету или уведомлению;
  /// null — показываем сегодня.
  final ValueNotifier<DateTime?> _widgetTapDate = ValueNotifier<DateTime?>(
    null,
  );

  /// Этап 14: сигнал «открой квиз» — тап по напоминанию о квизе
  /// (тёплый старт через onOpenQuiz, холодный — через payload запуска).
  final ValueNotifier<bool> _quizOpenRequest = ValueNotifier<bool>(false);

  /// Квиз-повторение (этап 14): один экземпляр на приложение — история
  /// результатов (файл) едина для напоминаний и экрана квиза.
  QuizService? _quiz;

  /// Этап 18 (идея B-005, часть 1): настройки — ручной выбор языка
  /// интерфейса. Один экземпляр на приложение: его же получает
  /// [HomeScreen], в него пишет экран настроек.
  final SettingsService _settings = SettingsService();

  Timer? _midnightTimer;
  StreamSubscription<Uri?>? _tapSubscription;

  /// Этап 17 (идея B-009): показан ли preload-экран приветствия. Холодный
  /// старт открывает [WelcomeScreen], который сам вызывает колбэк, когда
  /// анимация доиграла или пользователь тапнул.
  bool _splashDone = false;

  /// Этап 17: резолвен ли стартовый запуск. Стартовые источники (URI
  /// виджета + payload уведомления) читаются асинхронно — до их ответа
  /// держим первый кадр пустым: тот же фон `#F1F8E9`, что у нативного
  /// сплэша и scaffold приложения, поэтому смены картинки не видно.
  bool _launchResolved = false;

  /// Этап 17: старт по дееплинку (тап по виджету/уведомлению/напоминанию
  /// квиза) — [WelcomeScreen] не показываем, сразу [HomeScreen].
  bool _launchedFromDeeplink = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_syncTodayQuietly());
    _startNotifications();
    _startQuiz();
    _scheduleMidnightSync();
    _listenToWidgetTaps();
    // Правка приёмки 05.10.2026: единый язык приложения — смена меняет
    // интерфейс (locale MaterialApp), переводы (карточка/избранное/квиз/
    // постер читают резолв в build), виджет и уведомление «слово дня».
    // Слушатель срабатывает и на стартовое чтение файла: сохранённый
    // выбор ≠ «system» доспанивает виджет и уведомление после загрузки.
    _settings.appLanguage.addListener(_onAppLanguageChanged);
    // Гейт онбординга языка ([LanguagePickScreen]) оценивается после
    // чтения settings.json: чтение не меняет нотифаер, если выбор
    // совпал с дефолтом, — пересобираем дерево явно.
    unawaited(_settings.load().then((_) {
      if (mounted) {
        setState(() {});
      }
    }));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    _tapSubscription?.cancel();
    _widgetTapDate.dispose();
    _quizOpenRequest.dispose();
    _quiz?.dispose();
    _settings.appLanguage.removeListener(_onAppLanguageChanged);
    _settings.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Возврат из «недавних»/с фона: время могло перевалить за полночь —
    // обновляем виджет (риск №2 в PLAN.md §9).
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncTodayQuietly());
      // Контент уведомления должен соответствовать ближайшему срабатыванию.
      unawaited(
        _notifications?.rescheduleDailyNotification(
          translationLanguage: _settings.effectiveTranslationLanguage,
        ),
      );
      // Этап 14: одноразовое напоминание квиза не повторяется нативно —
      // перепланируем под свежую историю (мог сработать в фоне).
      unawaited(_rescheduleQuizReminderQuietly());
      _scheduleMidnightSync();
    }
  }

  /// Правка приёмки 05.10.2026: единый язык приложения сменился —
  /// пересобираем дерево (locale MaterialApp и все читатели резолва
  /// переводов в build), сразу перерисовываем виджет (новый язык уходит
  /// в prefs — `widget.translation` + `widget.translation_lang`) и
  /// перепланируем «слово дня» с телом на новом языке. Слушатель
  /// срабатывает и на стартовое чтение файла: сохранённый выбор ≠
  /// «system» доспанивает виджет и уведомление после загрузки настроек.
  void _onAppLanguageChanged() {
    if (mounted) {
      setState(() {});
    }
    unawaited(_syncTodayQuietly());
    unawaited(
      _notifications?.rescheduleDailyNotification(
        translationLanguage: _settings.effectiveTranslationLanguage,
      ),
    );
  }

  /// Правка приёмки 05.10.2026: в режиме «как в системе» переводы
  /// следуют системной локали — пользователь сменил язык устройства
  /// на лету. Интерфейс перерисует MaterialApp сам; карточку, виджет
  /// и уведомление доспаниваем здесь (при ручном выборе системная
  /// смена ничего не меняет — выходим раньше).
  @override
  void didChangeLocales(List<Locale>? locales) {
    super.didChangeLocales(locales);
    if (locales == null ||
        locales.isEmpty ||
        _settings.appLanguage.value != SettingsService.systemLanguage) {
      return;
    }
    if (mounted) {
      setState(() {});
    }
    unawaited(_syncTodayQuietly());
    unawaited(
      _notifications?.rescheduleDailyNotification(
        translationLanguage: _settings.effectiveTranslationLanguage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Редизайн: мягкий зелёный (hijau) вместо индиго — природный оттенок,
    // ассоциирующийся с ростом и обучением. Фон экрана — светлый
    // светло-зелёный (#F1F8E9), карточка — тёплый айвори (#FFFDF5).
    const seedColor = Color(0xFF4CAF50);
    return MaterialApp(
      // Имя для ОС (переключатель задач) — локализуется вместе с UI.
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      // Интернационализация en/ru/id; неопознанная локаль → en (первая
      // в supportedLocales). Базовая резолюция MaterialApp справляется
      // сама, включая legacy-коды Android ('in' → 'id').
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Этапы 18–19 (правка приёмки 05.10.2026): единый язык приложения;
      // «как в системе» — системная резолв MaterialApp (включая
      // канонизацию legacy-кода «in» → «id»), неподдержанная системная
      // локаль → en-фолбэк локализации.
      locale: _settings.locale,
      // Правка приёмки 05.10.2026: template-фолбэк локализации — en.
      // gen-l10n отдаёт supportedLocales отсортированными (первая — de),
      // и стандартная резолв MaterialApp для неподдержанных системных
      // локалей (ko, kk…) выбирала бы немецкий. Резолвим сами: код из
      // [SettingsService.interfaceLanguageForSystemLocale] — системная
      // локаль, поддержанная приложением, либо en. Ручной выбор
      // (`locale` выше) идёт мимо этого колбэка.
      localeResolutionCallback: (deviceLocale, supportedLocales) => Locale(
        SettingsService.interfaceLanguageForSystemLocale(
          deviceLocale ?? const Locale('en'),
        ),
      ),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
        scaffoldBackgroundColor: const Color(0xFFF1F8E9),
        cardTheme: const CardThemeData(color: Color(0xFFFFFDF5)),
      ),
      // Тёмной темы нет: концепт «слово дня» должен вызывать позитивное
      // настроение и на устройствах с системной тёмной темой.
      themeMode: ThemeMode.light,
      home: _splashDone || _launchedFromDeeplink
          ? _settings.isLoaded && _settings.needsLanguagePrompt
              // Правка приёмки 05.10.2026: системная локаль en/не
              // поддержана — один раз спрашиваем язык приложения
              // (интерфейс + переводы), затем обычный маршрут.
              ? LanguagePickScreen(
                  settings: _settings,
                  onDone: () {
                    if (mounted) {
                      setState(() {});
                    }
                  },
                )
              : HomeScreen(
                  widgetTapDate: _widgetTapDate,
                  quiz: _quiz,
                  quizOpenRequest: _quizOpenRequest,
                  settings: _settings,
                )
          // Этап 17: до резолва стартовых источников (URI виджета,
          // payload уведомления — миллисекунды) держим кадр пустым на
          // фоне scaffold (#F1F8E9) — визуально продолжение нативного
          // сплэша, без вспышки. Дееплинк-старт пропускает приветствие
          // совсем, обычный — показывает [WelcomeScreen]; его колбэк
          // (анимация доиграла / тап) переключает на карточку дня.
          : !_launchResolved
              ? const Scaffold(body: SizedBox.shrink())
              : WelcomeScreen(
                  onFinished: () {
                    if (!_splashDone) {
                      setState(() => _splashDone = true);
                    }
                  },
                ),
    );
  }

  /// Синхронизация без падения UI: ошибки плагина (например, отсутствие
  /// платформенной реализации в тестах) логируем и глотаем.
  Future<void> _syncTodayQuietly() async {
    try {
      await _widgetSync.syncToday(
        translationLanguage: _settings.effectiveTranslationLanguage,
      );
    } catch (e) {
      debugPrint('WidgetSync: не удалось синхронизировать виджет: $e');
    }
  }

  /// Перезапускает таймер на следующую локальную полночь.
  void _scheduleMidnightSync() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    // Конструктор DateTime нормализует «32 января» → 1 февраля.
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now), () {
      unawaited(_syncTodayQuietly());
      // Наступил новый день — ближайшее срабатывание сегодня в 09:00,
      // обновляем слово и в уведомлении.
      unawaited(
        _notifications?.rescheduleDailyNotification(
          translationLanguage: _settings.effectiveTranslationLanguage,
        ),
      );
      // Этап 14: мог наступить день квиза — напоминание должно стоять.
      unawaited(_rescheduleQuizReminderQuietly());
      _scheduleMidnightSync();
    });
  }

  void _listenToWidgetTaps() {
    _tapSubscription = HomeWidget.widgetClicked.listen(
      _handleWidgetUri,
      onError: (Object error) =>
          debugPrint('WidgetSync: ошибка стрима тапов виджета: $error'),
    );
    // Этап 17: стартовый URI — ещё и вход гейта приветствия: резолв
    // (любой исход) отпирает первый кадр, валидная дата помечает запуск
    // дееплинком.
    HomeWidget.initiallyLaunchedFromHomeWidget()
        .then(_handleInitialLaunchUri)
        .catchError((Object error) {
          debugPrint('WidgetSync: не удалось прочитать стартовый URI: $error');
        })
        .whenComplete(_resolveLaunch);
  }

  void _handleWidgetUri(Uri? uri) {
    final date = WidgetSyncService.dateFromWidgetUri(uri);
    if (date != null) {
      _widgetTapDate.value = date;
    }
  }

  /// Этап 17: стартовый URI виджета — та же карточка даты, но запуск
  /// помечен дееплинком (приветствие пропускается).
  void _handleInitialLaunchUri(Uri? uri) {
    final date = WidgetSyncService.dateFromWidgetUri(uri);
    if (date != null) {
      _widgetTapDate.value = date;
      _launchedFromDeeplink = true;
    }
  }

  /// Этап 17: стартовые источники разобраны — гейт первого кадра
  /// отпирается. Вызывается по разу с каждого источника (виджет,
  /// уведомление); срабатывает второй.
  void _resolveLaunch() {
    if (_launchResolved) {
      return;
    }
    _launchResolved = true;
    if (mounted) {
      setState(() {});
    }
  }

  /// Этап 7: инициализация уведомлений (разрешение спрашиваем один раз
  /// за запуск, PLAN.md §7) и холодный старт тапом по уведомлению.
  /// Этап 14: колбэк onOpenQuiz — тёплый старт тапом по напоминанию квиза.
  void _startNotifications() {
    _notifications = NotificationService(
      onOpenWordCard: _openWordCard,
      onOpenQuiz: _openQuiz,
    );
    unawaited(
      _notifications!.start(
        translationLanguage: _settings.effectiveTranslationLanguage,
      ),
    );
    // Этап 17: резолв payload — второй вход гейта приветствия (ошибка
    // чтения не должна держать первый кадр вечно).
    _notifications!
        .launchNotificationPayload()
        .then(_handleLaunchPayload)
        .catchError((Object error) {
          debugPrint(
            'Notifications: не удалось прочитать payload запуска: $error',
          );
        })
        .whenComplete(_resolveLaunch);
  }

  /// Этап 14: квиз-сервис + стартовое перепланирование напоминания по
  /// сохранённой истории (после перезапуска расписание одноразовое могло
  /// сработать или пропасть — восстанавливаем).
  void _startQuiz() {
    _quiz = QuizService(
      // Квиз пройден → напоминание на +3 дня (QuizService.nextQuizDate).
      onQuizFinished: (nextQuizDate) =>
          unawaited(_notifications?.rescheduleQuizReminder(nextQuizDate)),
    );
    unawaited(_rescheduleQuizReminderQuietly());
  }

  /// Этап 14: перепланировать напоминание квиза, когда история загружена
  /// (null — квизов не было — метод просто снимет расписание).
  Future<void> _rescheduleQuizReminderQuietly() async {
    final quiz = _quiz;
    if (quiz == null) {
      return;
    }
    await quiz.load();
    await _notifications?.rescheduleQuizReminder(quiz.nextQuizDate);
  }

  void _openWordCard(DateTime date) => _widgetTapDate.value = date;

  /// Этап 14: открыть квиз (тап по напоминанию — тёплый старт).
  void _openQuiz() => _quizOpenRequest.value = true;

  /// Этап 17: payload запуска — общий разбор, плюс запуск помечается
  /// дееплинком: холодный старт по уведомлению/напоминанию квиза —
  /// без приветствия, сразу карточка/квиз.
  void _handleLaunchPayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return;
    }
    _launchedFromDeeplink = true;
    _handleNotificationPayload(payload);
  }

  /// Payload уведомления — тот же URI-контракт, что и у виджета.
  void _handleNotificationPayload(String? payload) {
    if (payload == null) {
      return;
    }
    // Холодный старт по напоминанию квиза (этап 14).
    if (payload == NotificationService.quizPayloadUri) {
      _openQuiz();
      return;
    }
    final date = WidgetSyncService.dateFromWidgetUri(Uri.tryParse(payload));
    if (date != null) {
      _widgetTapDate.value = date;
    }
  }
}
