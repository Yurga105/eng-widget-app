import 'package:flutter_test/flutter_test.dart';

import 'package:eng_widget_app/services/dictionary_service.dart';
import 'package:eng_widget_app/services/word_of_day_service.dart';
import 'package:eng_widget_app/services/widget_sync_service.dart';

/// Мини-база на две записи: seed чётной даты → запись 1, нечётной → запись 2
/// (20260926 % 2 = 0, 20260927 % 2 = 1).
const String miniDbJson = '{"version":1,"words":['
    '{"id":1,"word":"alpha","transcription":"/ˈælfə/",'
    '"translation":"альфа","example":"Alpha example.",'
    '"example_ru":"Пример альфы.","type":"word"},'
    '{"id":2,"word":"beta hang out","transcription":"/ˈbiːtə/",'
    '"translation":"бета","example":"Beta example.",'
    '"example_ru":"Пример беты.","type":"idiom"}]}';

/// Пишет в память вместо плагина home_widget — записи и вызовы обновления.
class FakeHomeWidgetBackend implements HomeWidgetBackend {
  final Map<String, Object?> saved = <String, Object?>{};
  final List<String> savedKeys = <String>[];
  final List<String?> updatedProviders = <String?>[];

  @override
  Future<bool?> saveWidgetData<T>(String id, T? data) async {
    saved[id] = data;
    savedKeys.add(id);
    return true;
  }

  @override
  Future<bool?> updateWidget({String? name, String? androidName}) async {
    updatedProviders.add(androidName ?? name);
    return true;
  }
}

void main() {
  group('WidgetSyncService — поля слова дня в prefs + updateWidget', () {
    late FakeHomeWidgetBackend backend;

    WidgetSyncService buildService(DateTime Function() clock) {
      final dictionary =
          DictionaryService(assetLoader: (_) async => miniDbJson);
      return WidgetSyncService(
        wordOfDay: WordOfDayService(dictionary, clock: clock),
        backend: backend,
      );
    }

    setUp(() {
      backend = FakeHomeWidgetBackend();
    });

    test('syncToday: 2026-09-27 (нечётный seed) → запись «beta hang out»',
        () async {
      await buildService(() => DateTime(2026, 9, 27, 10, 0)).syncToday();

      expect(backend.saved[WidgetSyncService.keyDate], '2026-09-27');
      expect(backend.saved[WidgetSyncService.keyWord], 'beta hang out');
      expect(backend.saved[WidgetSyncService.keyTranscription], '/ˈbiːtə/');
      expect(backend.saved[WidgetSyncService.keyTranslation], 'бета');
      expect(backend.saved[WidgetSyncService.keyExample], 'Beta example.');
      expect(
        backend.updatedProviders,
        [WidgetSyncService.androidProviderName],
        reason: 'updateWidget должен зваться с именем WordWidgetProvider',
      );
    });

    test('syncForDate: другая дата → другая запись — виджет следует за датой',
        () async {
      await buildService(() => DateTime(2026, 9, 27))
          .syncForDate(DateTime(2026, 9, 26));

      expect(backend.saved[WidgetSyncService.keyDate], '2026-09-26');
      expect(backend.saved[WidgetSyncService.keyWord], 'alpha');
    });

    test('ровно шесть ключей — контракт с Kotlin не расползается', () async {
      await buildService(() => DateTime(2026, 9, 27)).syncToday();

      expect(
        backend.saved.keys,
        unorderedEquals(<String>[
          WidgetSyncService.keyDate,
          WidgetSyncService.keyWord,
          WidgetSyncService.keyTranscription,
          WidgetSyncService.keyTranslation,
          WidgetSyncService.keyExample,
          WidgetSyncService.keyDbJson,
        ]),
      );
    });

    test('word_db_json — исходный JSON базы целиком (этап 5)', () async {
      await buildService(() => DateTime(2026, 9, 27)).syncToday();

      expect(backend.saved[WidgetSyncService.keyDbJson], miniDbJson);
    });

    test('word_db_json пишется один раз на экземпляр сервиса', () async {
      final service = buildService(() => DateTime(2026, 9, 27));
      await service.syncToday();
      await service.syncForDate(DateTime(2026, 9, 26));

      expect(
        backend.savedKeys
            .where((key) => key == WidgetSyncService.keyDbJson)
            .length,
        1,
        reason: 'база ~70 КБ неизменна — повторная перезапись не нужна',
      );
      expect(backend.saved[WidgetSyncService.keyDate], '2026-09-26');
    });
  });

  group('isoDate / widgetUri / dateFromWidgetUri', () {
    test('isoDate дополняет месяц и день нулями', () {
      expect(WidgetSyncService.isoDate(DateTime(2026, 9, 5)), '2026-09-05');
      expect(WidgetSyncService.isoDate(DateTime(2027, 1, 1)), '2027-01-01');
      expect(WidgetSyncService.isoDate(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('widgetUri — схема и host из §6, дата в query', () {
      expect(
        WidgetSyncService.widgetUri(DateTime(2026, 9, 27)).toString(),
        'wordoftheday://word?date=2026-09-27',
      );
    });

    test('dateFromWidgetUri: валидный URI → дата', () {
      final date = WidgetSyncService.dateFromWidgetUri(
        Uri.parse('wordoftheday://word?date=2026-09-27'),
      );
      expect(date, DateTime(2026, 9, 27));
    });

    test('dateFromWidgetUri: null и пустой URI → null', () {
      expect(WidgetSyncService.dateFromWidgetUri(null), isNull);
      expect(WidgetSyncService.dateFromWidgetUri(Uri()), isNull);
    });

    test('dateFromWidgetUri: чужая схема или host → null', () {
      expect(
        WidgetSyncService.dateFromWidgetUri(
          Uri.parse('https://word?date=2026-09-27'),
        ),
        isNull,
      );
      expect(
        WidgetSyncService.dateFromWidgetUri(
          Uri.parse('wordoftheday://other?date=2026-09-27'),
        ),
        isNull,
      );
    });

    test('dateFromWidgetUri: нет или кривой параметр date → null', () {
      expect(
        WidgetSyncService.dateFromWidgetUri(Uri.parse('wordoftheday://word')),
        isNull,
      );
      expect(
        WidgetSyncService.dateFromWidgetUri(
          Uri.parse('wordoftheday://word?date=20260927'),
        ),
        isNull,
      );
      expect(
        WidgetSyncService.dateFromWidgetUri(
          Uri.parse('wordoftheday://word?date=2026-9-27'),
        ),
        isNull,
      );
    });

    test('dateFromWidgetUri: несуществующая дата (31 февраля, 13-й месяц) → null',
        () {
      expect(
        WidgetSyncService.dateFromWidgetUri(
          Uri.parse('wordoftheday://word?date=2026-02-31'),
        ),
        isNull,
      );
      expect(
        WidgetSyncService.dateFromWidgetUri(
          Uri.parse('wordoftheday://word?date=2026-13-01'),
        ),
        isNull,
      );
    });

    test('round-trip: widgetUri → dateFromWidgetUri → исходная дата', () {
      final original = DateTime(2024, 2, 29); // високосный день
      expect(
        WidgetSyncService.dateFromWidgetUri(
          WidgetSyncService.widgetUri(original),
        ),
        original,
      );
    });
  });
}
