import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

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
  Future<void> scheduleDailyWord({
    required int id,
    required String title,
    required String body,
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
      ),
      onDidReceiveNotificationResponse: onNotificationTap == null
          ? null
          : (NotificationResponse response) =>
              onNotificationTap(response.payload ?? ''),
    );
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> scheduleDailyWord({
    required int id,
    required String title,
    required String body,
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
          NotificationService.channelName,
          channelDescription: NotificationService.channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      // Без SCHEDULE_EXACT_ALARM (PLAN.md §6): «примерно в срок», но
      // срабатывает и в Doze. Натив ставит следующий день сам.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
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
      debugPrint('Notifications: flutter_timezone недоступен ($e), '
          'переходим к запасному варианту');
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
  })  : _wordOfDay = wordOfDay ?? WordOfDayService(DictionaryService()),
        _backend = backend ?? FlutterNotificationsBackend(),
        _clock = clock ?? DateTime.now,
        _openCard = onOpenWordCard;

  final WordOfDayService _wordOfDay;
  final NotificationsBackend _backend;
  final DateTime Function() _clock;
  final void Function(DateTime date)? _openCard;

  /// Один id на все перепланирования: новое расписание заменяет старое.
  static const int notificationId = 1;

  static const String channelId = 'word_of_day';
  static const String channelName = 'Слово дня';
  static const String channelDescription =
      'Ежедневное уведомление со словом дня в 9:00 (PLAN.md §7)';

  /// Час срабатывания — константа v1 (PLAN.md §1: настроек в v1 нет).
  static const int notifyHour = 9;

  /// Стартовый прогон: плагин + разрешение + расписание.
  ///
  /// Разрешение спрашиваем один раз за запуск (повторный запрос — не
  /// раньше следующего запуска, PLAN.md §7); отказ — мягкая деградация:
  /// расписание всё равно ставится, виджет от уведомлений не зависит
  /// (риск №5 в §9).
  Future<void> start() => _quietly('start', () async {
        await _backend.initialize(onNotificationTap: _handleNotificationTap);
        await _backend.requestPermission();
        await rescheduleDailyNotification();
      });

  /// Переписывает расписание под ближайшее будущее 09:00.
  Future<void> rescheduleDailyNotification() =>
      _quietly('reschedule', () async {
        final fireAt = nextDailyAt(_clock());
        final word = await _wordOfDay.wordForDate(fireAt);
        await _backend.cancel(notificationId);
        await _backend.scheduleDailyWord(
          id: notificationId,
          title: 'Слово дня — ${word.word}',
          body: '${word.transcription} — ${word.translation}',
          payload: WidgetSyncService.widgetUri(fireAt).toString(),
          at: fireAt,
        );
      });

  /// Payload холодного старта (запуск тапом по уведомлению) для main.dart.
  Future<String?> launchNotificationPayload() =>
      _quietly<String?>('launchPayload', _backend.launchNotificationPayload,
          orElse: null);

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

