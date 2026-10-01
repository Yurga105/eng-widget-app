import 'package:flutter_test/flutter_test.dart';

import 'package:eng_widget_app/services/dictionary_service.dart';
import 'package:eng_widget_app/services/notification_service.dart';
import 'package:eng_widget_app/services/word_of_day_service.dart';
import 'package:eng_widget_app/services/widget_sync_service.dart';

/// Записывает вызовы бэкенда; поведение задаётся полями.
class FakeBackend implements NotificationsBackend {
  void Function(String payload)? tapHandler;
  bool permissionGranted = true;
  Object? scheduleError;

  /// Порядок вызовов по имени — проверяем «cancel до schedule».
  final List<String> calls = <String>[];

  final List<({
    int id,
    String title,
    String body,
    String channelName,
    String payload,
    DateTime at,
  })> scheduled = <({
    int id,
    String title,
    String body,
    String channelName,
    String payload,
    DateTime at,
  })>[];

  String? launchPayloadValue;
  bool launchPayloadThrows = false;

  @override
  Future<void> initialize({
    required void Function(String payload)? onNotificationTap,
  }) async {
    tapHandler = onNotificationTap;
    calls.add('initialize');
  }

  @override
  Future<bool> requestPermission() async {
    calls.add('requestPermission');
    return permissionGranted;
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
    if (scheduleError != null) {
      throw scheduleError!;
    }
    calls.add('schedule:$id');
    scheduled.add(
      (id: id, title: title, body: body, channelName: channelName,
       payload: payload, at: at),
    );
  }

  @override
  Future<void> cancel(int id) async => calls.add('cancel:$id');

  @override
  Future<String?> launchNotificationPayload() async {
    if (launchPayloadThrows) {
      throw Exception('нет плагина');
    }
    return launchPayloadValue;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // реальные ассеты

  group('nextDailyAt — ближайший будущий 09:00', () {
    test('до 09:00 — сегодня', () {
      expect(
        NotificationService.nextDailyAt(DateTime(2026, 9, 27, 8, 59, 59, 999)),
        DateTime(2026, 9, 27, 9),
      );
      expect(
        NotificationService.nextDailyAt(DateTime(2026, 9, 27, 0, 0)),
        DateTime(2026, 9, 27, 9),
      );
    });

    test('ровно в 09:00 и позже — завтра', () {
      expect(
        NotificationService.nextDailyAt(DateTime(2026, 9, 27, 9, 0, 0)),
        DateTime(2026, 9, 28, 9),
      );
      expect(
        NotificationService.nextDailyAt(DateTime(2026, 9, 27, 21, 30)),
        DateTime(2026, 9, 28, 9),
      );
    });

    test('переходы месяца и года', () {
      expect(
        NotificationService.nextDailyAt(DateTime(2026, 9, 30, 23, 0)),
        DateTime(2026, 10, 1, 9),
      );
      expect(
        NotificationService.nextDailyAt(DateTime(2026, 12, 31, 23, 59)),
        DateTime(2027, 1, 1, 9),
      );
    });
  });

  group('NotificationService — поведение', () {
    late DictionaryService dictionary;
    late FakeBackend backend;
    var fakeNow = DateTime(2026, 9, 27, 8, 0);
    final List<DateTime> openedDates = <DateTime>[];

    setUp(() {
      dictionary = DictionaryService();
      backend = FakeBackend();
      fakeNow = DateTime(2026, 9, 27, 8, 0);
      openedDates.clear();
    });

    NotificationService buildService() => NotificationService(
          wordOfDay: WordOfDayService(dictionary, clock: () => fakeNow),
          backend: backend,
          clock: () => fakeNow,
          onOpenWordCard: openedDates.add,
        );

    test('start: порядок — initialize, permission, cancel, schedule', () async {
      await buildService().start();
      expect(backend.calls, [
        'initialize',
        'requestPermission',
        'cancel:${NotificationService.notificationId}',
        'schedule:${NotificationService.notificationId}',
      ]);
    });

    test('утром до 09:00 — сегодняшнее слово и сегодняшняя дата (§7)', () async {
      await buildService().start();

      final words = await dictionary.load();
      final expected = words[127]; // 20260927 mod 160 = 127 → id 128
      expect(expected.id, 128);

      expect(backend.scheduled, hasLength(1));
      final s = backend.scheduled.single;
      expect(s.id, NotificationService.notificationId);
      expect(s.at, DateTime(2026, 9, 27, 9));
      // Тестовое окружение — локаль en: строки уведомления берутся из
      // AppLocalizations (заголовок и имя канала локализуются).
      expect(s.title, 'Word of Day — ${expected.word}');
      expect(s.channelName, 'Word of Day');
      expect(s.body, '${expected.transcription} — ${expected.translation}');
      expect(
        s.payload,
        WidgetSyncService.widgetUri(DateTime(2026, 9, 27)).toString(),
      );
      expect(s.payload, 'wordoftheday://word?date=2026-09-27');
    });

    test('после 09:00 — слово уже завтрашнего дня срабатывания', () async {
      fakeNow = DateTime(2026, 9, 27, 10, 0);
      await buildService().start();

      final words = await dictionary.load();
      final expected = words[128]; // 20260928 mod 160 = 128 → id 129
      expect(expected.id, 129);

      final s = backend.scheduled.single;
      expect(s.at, DateTime(2026, 9, 28, 9));
      expect(s.title, 'Word of Day — ${expected.word}');
      expect(s.payload, 'wordoftheday://word?date=2026-09-28');
    });

    test('отказ в разрешении — расписание всё равно ставится (§7)', () async {
      backend.permissionGranted = false;
      await buildService().start();
      expect(backend.scheduled, hasLength(1));
    });

    test('сбой бэкенда не роняет вызов (мягкая деградация)', () async {
      backend.scheduleError = Exception('нет плагина');
      await buildService().start(); // не бросает
      expect(backend.scheduled, isEmpty);
    });

    test('тап по уведомлению открывает карточку даты из payload', () async {
      await buildService().start();
      expect(backend.tapHandler, isNotNull);

      backend.tapHandler!('wordoftheday://word?date=2026-09-26');
      expect(openedDates, [DateTime(2026, 9, 26)]);

      // чужой/пустой payload — колбэк не зовётся, приложение просто открывается
      backend.tapHandler!('мусор');
      backend.tapHandler!('');
      expect(openedDates, hasLength(1));
    });

    test('reschedule заменяет предыдущее расписание (cancel + schedule)',
        () async {
      final service = buildService();
      await service.start();
      fakeNow = DateTime(2026, 9, 27, 21, 0);
      await service.rescheduleDailyNotification();

      expect(backend.scheduled, hasLength(2));
      expect(
        backend.scheduled.last.at,
        DateTime(2026, 9, 28, 9),
      );
    });

    test('payload холодного старта прокидывается из бэкенда', () async {
      backend.launchPayloadValue = 'wordoftheday://word?date=2026-09-25';
      expect(
        await buildService().launchNotificationPayload(),
        'wordoftheday://word?date=2026-09-25',
      );
    });

    test('payload холодного старта: сбой — тихий null', () async {
      backend.launchPayloadThrows = true;
      expect(await buildService().launchNotificationPayload(), isNull);
    });
  });
}

