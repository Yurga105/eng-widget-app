import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/date_symbol_data_local.dart' as intl_dates;
import 'package:intl/intl.dart' show Intl;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/generated/app_localizations.dart';
import 'dictionary_service.dart';
import 'widget_sync_service.dart';
import 'word_of_day_service.dart';

/// Тонкая обёртка над плагином `flutter_local_notifications` — только то,
/// что нужно уведомлению «слово дня» (этап 7, PLAN.md §7).
///
/// Как и `HomeWidgetBackend` (этап 4), продакшн-плагин скрыт за
/// интерфейсом: сервис тестируется на фейке, UI про каналы не знает.
abstract class NotificationsBackend {
  /// Инициализация плагина; [onNotificationTap] вызывается при тапе по
  /// уведомлению, пока приложение живо (payload — строка из расписания).
  Future<void> initialize({
    required void Function(String payload)? onNotificationTap,
  });

  /// Запрос `POST_NOTIFICATIONS` (Android 13+); на старых версиях — no-op.
  /// Возвращает, разрешены ли уведомления.
  Future<bool> requestPermission();

  /// Ежедневное уведомление канала «Слово дня» на [at] по локальным часам.
  ///
  /// [channelName]/[channelDescription] локализованы вызывающей стороной:
  /// Android разрешает переименовать существующий канал повторным
  /// `createNotificationChannel` с тем же id (имя и описание — изменяемые
  /// поля канала), поэтому смена языка устройства подхватывается при
  /// следующем запуске без пересоздания канала.
  Future<void> scheduleDailyWord({
    required int id,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
    required String payload,
    required DateTime at,
  });

  /// Одноразовое уведомление канала [channelId] в момент [at] — без
  /// ежедневного повтора (этап 14: напоминание о квизе; следующее
  /// расписание ставит приложение после прохождения квиза).
  Future<void> scheduleOneShot({
    required int id,
    required String channelId,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
    required String payload,
    required DateTime at,
  });

  /// Снимает запланированное уведомление [id].
  Future<void> cancel(int id);

  /// Payload уведомления, запустившего приложение (холодный старт),
  /// или null, если запуск был не по уведомлению.
  Future<String?> launchNotificationPayload();
}

/// Продакшн-реализация поверх `flutter_local_notifications`.
class FlutterNotificationsBackend implements NotificationsBackend {
  /// Маленькая иконка статусной строки; до отдельного PNG-ассета
  /// (этап 8, PLAN.md §8) — лаунчер приложения.
  /// Малая (статусбарная) иконка уведомления. Обязана быть
  /// alpha-only drawable (белый глиф без фона) — этап 8:
  /// `@mipmap/ic_launcher` давал бы серый квадрат на Android 5+.
  FlutterNotificationsBackend({this.defaultIcon = '@drawable/ic_stat_word'});

  final String defaultIcon;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// База зон инициализируется один раз на экземпляр.
  bool _timeZoneReady = false;

  @override
  Future<void> initialize({
    required void Function(String payload)? onNotificationTap,
  }) async {
    await _plugin.initialize(
      settings: InitializationSettings(
        android: AndroidInitializationSettings(defaultIcon),
        // Этап 11 (iOS): маленькая статусбарная иконка не нужна — система
        // показывает иконку приложения. Запросы разрешений внутри initialize
        // отключены (дефолты Darwin* — true), чтобы системный диалог
        // показывался ровно один раз — из [requestPermission], как на Android.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: onNotificationTap == null
          ? null
          : (NotificationResponse response) =>
                onNotificationTap(response.payload ?? ''),
    );
  }

  @override
  Future<bool> requestPermission() async {
    // Этап 11: iOS запрашивает alert/sound отдельным вызовом (в initialize
    // запрос отключён). Бейдж не просим — приложение их не показывает.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(alert: true, sound: true) ?? false;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> scheduleDailyWord({
    required int id,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
    required String payload,
    required DateTime at,
  }) async {
    await _ensureTimeZone();
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      payload: payload,
      // Мгновенное время [at] в локальной зоне: нативная сторона берёт
      // имя зоны из TZDateTime.location и пересчитывает ежедневный повтор
      // по настенным часам именно этой зоны (java.time, DST-aware).
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationService.channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        // Этап 11 (iOS): каналов-аналогов нет; баннер и звук показываем
        // даже на переднем плане, бейдж не ставим.
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
      // Без SCHEDULE_EXACT_ALARM (PLAN.md §6): «примерно в срок», но
      // срабатывает и в Doze. Натив ставит следующий день сам.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Одноразовое уведомление (этап 14): то же, что ежедневное, но без
  /// `matchDateTimeComponents` — сработает один раз; следующее расписание
  /// ставит приложение (триггеры в `main.dart` + завершение квиза).
  @override
  Future<void> scheduleOneShot({
    required int id,
    required String channelId,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
    required String payload,
    required DateTime at,
  }) async {
    await _ensureTimeZone();
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      payload: payload,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<String?> launchNotificationPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      return details?.notificationResponse?.payload;
    }
    return null;
  }

  /// Инициализирует базу зон `timezone` и назначает `tz.local`.
  ///
  /// Зона обязана быть настоящим IANA-ID: `zonedSchedule` отправляет её
  /// нативной стороне, и ежедневный повтор считается по настенным часам
  /// этой зоны. Цепочка запасных вариантов: `flutter_timezone` →
  /// строка вида «GMT+3» из `DateTime` (зоны Etc с обратным знаком) →
  /// UTC (аварийный минимум: уведомление остаётся ежедневным,
  /// но в 09:00 UTC — деградация зафиксирована в KNOWLEDGE_BASE §8).
  Future<void> _ensureTimeZone() async {
    if (_timeZoneReady) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(await _resolveTimeZoneName()));
    _timeZoneReady = true;
  }

  Future<String> _resolveTimeZoneName() async {
    try {
      return (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (e) {
      debugPrint(
        'Notifications: flutter_timezone недоступен ($e), '
        'переходим к запасному варианту',
      );
    }
    // Dart на Android отдаёт что-то вроде «GMT+03:00»; зоны Etc/GMT
    // покрывают только целые часы, и их знак инвертирован: Etc/GMT-3 = UTC+3.
    final match = RegExp(r'^GMT([+-])(\d{1,2})(?::00)?$')
        .firstMatch(DateTime.now().timeZoneName);
    if (match != null) {
      final sign = match.group(1) == '+' ? '-' : '+';
      final candidate = 'Etc/GMT$sign${int.parse(match.group(2)!)}';
      try {
        tz.getLocation(candidate);
        return candidate;
      } catch (_) {
        // дробное смещение или зоны нет в базе — остаёмся на UTC
      }
    }
    return 'UTC';
  }
}

/// Ежедневное уведомление «Слово дня» — этап 7 (PLAN.md §7, §8).
///
/// Одно уведомление ([notificationId]) на канале `word_of_day`
/// в [notifyHour]:00 локального времени. Расписание самоподдерживается
/// нативно (`matchDateTimeComponents: time`): после срабатывания плагин
/// сам ставит следующий день, доставка не требует запуска приложения.
///
/// Контент — слово дня ДНЯ СРАБАТЫВАНИЯ (не дня запуска): запуск в 10:00
/// планирует завтрашнее уведомление со завтрашним словом. Поэтому
/// [rescheduleDailyNotification] зовут триггеры в `main.dart` (старт,
/// резюм, полуночный таймер) — перезапись освежает заголовок/тело/payload
/// под ближайшее срабатывание, а «застарелое» расписание всё равно
/// приходит ежедневно и остаётся самосогласованным (тап открывает
/// карточку того слова, что показано в теле).
///
/// Тап несёт тот же URI-контракт, что и виджет
/// ([WidgetSyncService.widgetUri]) — один парсер `dateFromWidgetUri`
/// обслуживает оба входа.
class NotificationService {
  NotificationService({
    WordOfDayService? wordOfDay,
    NotificationsBackend? backend,
    DateTime Function()? clock,
    void Function(DateTime date)? onOpenWordCard,
    void Function()? onOpenQuiz,
    Future<AppLocalizations> Function()? localizations,
  }) : _wordOfDay = wordOfDay ?? WordOfDayService(DictionaryService()),
       _backend = backend ?? FlutterNotificationsBackend(),
       _clock = clock ?? DateTime.now,
       _openCard = onOpenWordCard,
       _openQuiz = onOpenQuiz,
       _localizationsLoader =
           localizations ?? NotificationService._loadDeviceLocalizations;

  final WordOfDayService _wordOfDay;
  final NotificationsBackend _backend;
  final DateTime Function() _clock;
  final void Function(DateTime date)? _openCard;

  /// Тап по напоминанию квиза (этап 14) — открыть экран квиза.
  final void Function()? _openQuiz;

  final Future<AppLocalizations> Function() _localizationsLoader;

  /// Локализация кэшируется на первый запуск: расписание переписывается
  /// многократно за сессию, а делегат — синхронный и дешёвый.
  AppLocalizations? _localizations;

  /// Один id на все перепланирования: новое расписание заменяет старое.
  static const int notificationId = 1;

  /// Id канала неизменяем после создания — поэтому он константа, а вот
  /// имя и описание локализуются при каждом перепланировании (Android
  /// разрешает обновлять эти поля существующего канала).
  static const String channelId = 'word_of_day';

  /// Час срабатывания — константа v1 (PLAN.md §1: настроек в v1 нет).
  static const int notifyHour = 9;

  /// «Час:минута» для локализованного описания канала: единственный
  /// источник времени — [notifyHour]; формат по локали делает intl
  /// (placeholder {time} в ARB: «9:00 AM» en / «9:00» ru / «09.00» id).
  static final DateTime channelTime = DateTime(2024, 1, 1, notifyHour);

  /// Id напоминания квиза (этап 14): свой id — независимое перепланирование
  /// без отмены ежедневного «слова дня».
  static const int quizNotificationId = 2;

  /// Канал напоминаний квиза (имя/описание локализуются, id неизменяем).
  static const String quizChannelId = 'quiz';

  /// Час напоминания квиза — на час позже слова дня, чтобы напоминания
  /// не конкурировали в 09:00.
  static const int quizNotifyHour = 10;

  /// Payload напоминания квиза: тот же URI-контракт `wordoftheday://`, но
  /// без параметров — парсер даты его честно не поймает, ветка квиза
  /// проверяется первой (тап → `main.dart` открывает экран квиза).
  static const String quizPayloadUri = 'wordoftheday://quiz';

  /// Стартовый прогон: плагин + разрешение + расписание.
  ///
  /// Разрешение спрашиваем один раз за запуск (повторный запрос — не
  /// раньше следующего запуска, PLAN.md §7); отказ — мягкая деградация:
  /// расписание всё равно ставится, виджет от уведомлений не зависит
  /// (риск №5 в §9).
  Future<void> start({String translationLanguage = 'ru'}) =>
      _quietly('start', () async {
        await _backend.initialize(onNotificationTap: _handleNotificationTap);
        await _backend.requestPermission();
        await rescheduleDailyNotification(
          translationLanguage: translationLanguage,
        );
      });

  /// Переписывает расписание под ближайшее будущее 09:00.
  ///
  /// [translationLanguage] (этап 19, идея B-005) — язык перевода в теле
  /// уведомления: словарь v2 даёт id/de/fr/es, фолбэк записи — русский.
  /// Смена языка в настройках → перепланирование (слушатель в main.dart).
  Future<void> rescheduleDailyNotification({
    String translationLanguage = 'ru',
  }) =>
      _quietly('reschedule', () async {
        final fireAt = nextDailyAt(_clock());
        final word = await _wordOfDay.wordForDate(fireAt);
        final l10n = await _resolveLocalizations();
        await _backend.cancel(notificationId);
        await _backend.scheduleDailyWord(
          id: notificationId,
          title: l10n.notificationTitle(word.word),
          body: l10n.notificationBody(
            word.transcription,
            word.translationFor(translationLanguage),
          ),
          channelName: l10n.notificationChannelName,
          channelDescription: l10n.notificationChannelDescription(channelTime),
          payload: WidgetSyncService.widgetUri(fireAt).toString(),
          at: fireAt,
        );
      });

  /// Напоминание о квизе (этап 14, идея B-006): одноразовое уведомление на
  /// дату следующего квиза в [quizNotifyHour]:00.
  ///
  /// [nextQuizDate] == null (квиз ни разу не проходили) — только отмена:
  /// напоминать до первого прохождения нечего, вход — по иконке. Дата в
  /// прошлом (приложение не открывалось) — ближайшее будущее
  /// [quizNotifyHour]:00: сегодня, если ещё рано, иначе завтра.
  ///
  /// Расписание не повторяется нативно (в отличие от «слова дня»), поэтому
  /// метод зовут все триггеры перепланирования: старт, резюм, полночь и
  /// завершение квиза (колбэк `QuizService.onQuizFinished`).
  Future<void> rescheduleQuizReminder(DateTime? nextQuizDate) =>
      _quietly('rescheduleQuiz', () async {
        await _backend.cancel(quizNotificationId);
        if (nextQuizDate == null) {
          return;
        }
        var fireAt = DateTime(
          nextQuizDate.year,
          nextQuizDate.month,
          nextQuizDate.day,
          quizNotifyHour,
        );
        final now = _clock();
        if (!fireAt.isAfter(now)) {
          final today = DateTime(
            now.year,
            now.month,
            now.day + (now.hour < quizNotifyHour ? 0 : 1),
            quizNotifyHour,
          );
          fireAt = today;
        }
        final l10n = await _resolveLocalizations();
        await _backend.scheduleOneShot(
          id: quizNotificationId,
          channelId: quizChannelId,
          title: l10n.quizNotificationTitle,
          body: l10n.quizNotificationBody,
          channelName: l10n.quizNotificationChannelName,
          channelDescription: l10n.quizNotificationChannelDescription,
          payload: quizPayloadUri,
          at: fireAt,
        );
      });

  /// Локализованные строки уведомления: контекст здесь недоступен (сервис
  /// стартует до отрисовки UI), поэтому грузим делегат по локали
  /// устройства. Поддержанная локаль отсутствует → en (первая в
  /// `supportedLocales`).
  Future<AppLocalizations> _resolveLocalizations() async =>
      _localizations ??= await _localizationsLoader();

  static Future<AppLocalizations> _loadDeviceLocalizations() async {
    final deviceLocale = PlatformDispatcher.instance.locale;
    // Android может отдать устаревший ISO-код ('in' вместо 'id' для
    // индонезийского) — intl каноникализирует ('in' → 'id', 'iw' → 'he').
    final canonical = Intl.canonicalizedLocale(deviceLocale.toString())
        .split('_')
        .first;
    final locale = AppLocalizations.supportedLocales.firstWhere(
      (locale) => locale.languageCode == canonical,
      orElse: () => AppLocalizations.supportedLocales.first,
    );
    // DateTime-плейсхолдеры ARB ({time} в описании канала) форматируются
    // через DateFormat — intl требует инициализированных символов дат
    // локали. В UI их грузит GlobalMaterialLocalizations, но сервис живёт
    // без MaterialApp (стартует до первого кадра) — инициализируем сами;
    // вызов идемпотентен и дешёв.
    await intl_dates.initializeDateFormatting(locale.toString());
    return AppLocalizations.delegate.load(locale);
  }

  /// Payload холодного старта (запуск тапом по уведомлению) для main.dart.
  Future<String?> launchNotificationPayload() => _quietly<String?>(
    'launchPayload',
    _backend.launchNotificationPayload,
    orElse: null,
  );

  /// Ближайший будущий 09:00 по локальным часам: сегодня, если ещё рано,
  /// иначе завтра. Ровно в 09:00 — уже завтра (сегодняшнее сработало).
  /// Конструктор [DateTime] нормализует «32 января» сам.
  static DateTime nextDailyAt(DateTime now) {
    final today = DateTime(now.year, now.month, now.day, notifyHour);
    if (now.isBefore(today)) {
      return today;
    }
    return DateTime(now.year, now.month, now.day + 1, notifyHour);
  }

  void _handleNotificationTap(String payload) {
    // Этап 14: напоминание квиза — свой payload без даты.
    if (payload == quizPayloadUri) {
      _openQuiz?.call();
      return;
    }
    final date = WidgetSyncService.dateFromWidgetUri(Uri.tryParse(payload));
    if (date != null) {
      _openCard?.call(date);
    }
  }

  /// Все операции уведомлений не должны ронять UI: ошибки плагина
  /// (в том числе отсутствие платформенной реализации в тестах)
  /// логируем и глотаем — как `_syncTodayQuietly` в main.dart.
  Future<T?> _quietly<T>(
    String what,
    Future<T> Function() action, {
    T? orElse,
  }) async {
    try {
      return await action();
    } catch (e) {
      debugPrint('Notifications: $what не удался: $e');
      return orElse;
    }
  }
}
