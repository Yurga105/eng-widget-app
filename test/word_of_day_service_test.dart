import 'package:flutter_test/flutter_test.dart';

import 'package:eng_widget_app/services/dictionary_service.dart';
import 'package:eng_widget_app/services/word_of_day_service.dart';

/// Тест-векторы паритета Dart ↔ Kotlin (PLAN.md §5, риск №4 в §9).
///
/// ТАБЛИЦУ НУЖНО ПОСЛОВНО ПЕРЕНЕСТИ в Kotlin-тест `WordWidgetProviderTest`
/// (этап 5). Векторы посчитаны для текущего размера базы N = 160;
/// при изменении N пересчитать в обеих сторонах одновременно:
///
/// | дата       | seed     | index = seed % 160 | id записи |
/// |------------|----------|--------------------|----------|
/// | 1999-12-31 | 19991231 | 31                 | 32       |
/// | 2000-01-01 | 20000101 | 101                | 102      |
/// | 2024-02-29 | 20240229 | 69                 | 70       |
/// | 2025-06-15 | 20250615 | 55                 | 56       |
/// | 2026-09-26 | 20260926 | 126                | 127      |
/// | 2026-09-27 | 20260927 | 127                | 128      |
/// | 2026-12-31 | 20261231 | 111                | 112      |
/// | 2027-01-01 | 20270101 | 21                 | 22       |
void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // реальные ассеты

  group('Формула §5 — тест-векторы (паритет с Kotlin)', () {
    test('seed = yyyy * 10000 + MM * 100 + dd', () {
      expect(WordOfDayService.seedFor(DateTime(2026, 9, 26)), 20260926);
      expect(
        WordOfDayService.seedFor(DateTime(2024, 2, 29)), // високосный год
        20240229,
      );
      expect(WordOfDayService.seedFor(DateTime(2000, 1, 1)), 20000101);
    });

    test('index для фиксированных дат при N = 160', () {
      const n = 160;
      expect(WordOfDayService.indexFor(DateTime(1999, 12, 31), n), 31);
      expect(WordOfDayService.indexFor(DateTime(2000, 1, 1), n), 101);
      expect(WordOfDayService.indexFor(DateTime(2024, 2, 29), n), 69);
      expect(WordOfDayService.indexFor(DateTime(2025, 6, 15), n), 55);
      expect(WordOfDayService.indexFor(DateTime(2026, 9, 26), n), 126);
      expect(WordOfDayService.indexFor(DateTime(2026, 9, 27), n), 127);
      expect(WordOfDayService.indexFor(DateTime(2026, 12, 31), n), 111);
      expect(WordOfDayService.indexFor(DateTime(2027, 1, 1), n), 21);
    });

    test('index зависит от размера базы N', () {
      // 20270101 mod 100 = 1; 20260926 mod 7 = 0.
      expect(WordOfDayService.indexFor(DateTime(2027, 1, 1), 100), 1);
      expect(WordOfDayService.indexFor(DateTime(2026, 9, 26), 7), 0);
    });

    test('total <= 0 — ArgumentError', () {
      expect(
        () => WordOfDayService.indexFor(DateTime(2026, 9, 26), 0),
        throwsArgumentError,
      );
      expect(
        () => WordOfDayService.indexFor(DateTime(2026, 9, 26), -5),
        throwsArgumentError,
      );
    });
  });

  group('WordOfDayService — реальная база (N = 160)', () {
    late DictionaryService dictionary;
    var fakeNow = DateTime(2026, 9, 26, 13, 37);

    setUp(() {
      dictionary = DictionaryService();
      fakeNow = DateTime(2026, 9, 26, 13, 37);
    });

    WordOfDayService buildService() =>
        WordOfDayService(dictionary, clock: () => fakeNow);

    test('2026-09-26 → index 126 → запись id 127', () async {
      final service = buildService();
      final word = await service.todayWord;

      final words = await dictionary.load();
      expect(word, words[126]);
      expect(word.id, 127);
    });

    test('слово стабильно весь день: 00:01, 13:37, 23:59 — одна запись',
        () async {
      final service = buildService();
      final ids = <int>{};
      for (final moment in [
        DateTime(2026, 9, 26, 0, 1),
        DateTime(2026, 9, 26, 13, 37),
        DateTime(2026, 9, 26, 23, 59),
      ]) {
        fakeNow = moment;
        ids.add((await service.todayWord).id);
      }
      expect(ids, hasLength(1));
      expect(ids.first, 127);
    });

    test('на следующий день слово меняется: 2026-09-27 → id 128', () async {
      fakeNow = DateTime(2026, 9, 27, 8, 0);
      expect((await buildService().todayWord).id, 128);
    });

    test('смена года перемешивает последовательность: 2027-01-01 → id 22',
        () async {
      fakeNow = DateTime(2027, 1, 1, 9, 0);
      expect((await buildService().todayWord).id, 22);
    });

    test('today обнуляет время, оставляя дату', () {
      fakeNow = DateTime(2026, 12, 31, 23, 59, 59);
      expect(buildService().today, DateTime(2026, 12, 31));
    });

    test('wordForDate читает только дату (UTC-полночь от виджета)', () async {
      final utcMidnight = DateTime.utc(2026, 9, 26);
      expect((await buildService().wordForDate(utcMidnight)).id, 127);
    });
  });
}
