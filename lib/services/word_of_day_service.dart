import '../models/word_entry.dart';
import 'dictionary_service.dart';

/// «Слово дня» — детерминированный выбор записи по дате (PLAN.md §5).
///
/// Единая формула для Dart и Kotlin (риск №4 в §9):
///
/// ```text
/// date  = локальная календарная дата (yyyy-MM-dd)
/// seed  = yyyy * 10000 + MM * 100 + dd
/// index = seed mod words.length
/// ```
///
/// Слово одно на весь календарный день и меняется после локальной полуночи;
/// год входит в seed, поэтому 1 января последовательность «перемешивается».
class WordOfDayService {
  WordOfDayService(this._dictionary, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final DictionaryService _dictionary;

  /// Инжектируемые часы: продакшн — [DateTime.now], тесты — фейковые.
  final DateTime Function() _clock;

  /// Сегодняшняя календарная дата по локальному времени (время обнуляется).
  DateTime get today {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  /// Слово дня для сегодня.
  Future<WordEntry> get todayWord => wordForDate(today);

  /// Слово для произвольной даты (тап по виджету, карточка дня из URI).
  ///
  /// Часовой пояс и время не важны: формула читает только год/месяц/день,
  /// таймзон-математики нет (§5).
  Future<WordEntry> wordForDate(DateTime date) async {
    final words = await _dictionary.load();
    return words[indexFor(date, words.length)];
  }

  /// `seed = yyyy * 10000 + MM * 100 + dd` — ровно та же арифметика,
  /// что будет в `WordWidgetProvider.kt` (этап 5). Годы нашей эры дают
  /// неотрицательный seed.
  static int seedFor(DateTime date) =>
      date.year * 10000 + date.month * 100 + date.day;

  /// `index = seed mod total`; результат всегда в `0..total-1`.
  ///
  /// Бросает [ArgumentError] при `total <= 0` — пустая база означает
  /// ошибку данных, а не «слово №0».
  static int indexFor(DateTime date, int total) {
    if (total <= 0) {
      throw ArgumentError.value(total, 'total', 'размер базы должен быть > 0');
    }
    return seedFor(date) % total;
  }
}
