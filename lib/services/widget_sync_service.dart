import 'package:home_widget/home_widget.dart';

import 'dictionary_service.dart';
import 'word_of_day_service.dart';

/// Тонкая обёртка над плагином `home_widget` — только то, что нужно виджету.
///
/// Статика [HomeWidget] плохо поддаётся подмене в тестах, поэтому сервис
/// работает через этот интерфейс (продакшн — [PluginHomeWidgetBackend]).
abstract class HomeWidgetBackend {
  /// Сохраняет значение в хранилище виджета
  /// (Android: SharedPreferences «HomeWidgetPreferences»).
  Future<bool?> saveWidgetData<T>(String id, T? data);

  /// Просит систему обновить виджет; [androidName] — имя класса провайдера.
  Future<bool?> updateWidget({String? name, String? androidName});
}

/// Продакшн-реализация поверх плагина home_widget.
class PluginHomeWidgetBackend implements HomeWidgetBackend {
  const PluginHomeWidgetBackend();

  @override
  Future<bool?> saveWidgetData<T>(String id, T? data) =>
      HomeWidget.saveWidgetData<T>(id, data);

  @override
  Future<bool?> updateWidget({String? name, String? androidName}) =>
      HomeWidget.updateWidget(name: name, androidName: androidName);
}

/// Мост «Flutter ↔ нативный виджет» — этап 4 (PLAN.md §6, §8).
///
/// Сохраняет поля слова дня в хранилище виджета и просит систему
/// перерисовать [WordWidgetProvider]. Нативная сторона читает те же ключи
/// (см. `WordWidgetProvider.kt`) — это общий контракт, менять только
/// синхронно.
///
/// Триггеры вызова [syncToday] живут в `main.dart`: старт приложения,
/// возврат на передний план и полуночный таймер.
class WidgetSyncService {
  WidgetSyncService({WordOfDayService? wordOfDay, HomeWidgetBackend? backend})
      : _wordOfDay = wordOfDay ?? WordOfDayService(DictionaryService()),
        _backend = backend ?? const PluginHomeWidgetBackend();

  final WordOfDayService _wordOfDay;
  final HomeWidgetBackend _backend;

  /// Имя класса провайдера для [HomeWidgetBackend.updateWidget].
  static const String androidProviderName = 'WordWidgetProvider';

  // Контракт с WordWidgetProvider.kt — менять только вместе.
  static const String keyDate = 'widget.date';
  static const String keyWord = 'widget.word';
  static const String keyTranscription = 'widget.transcription';
  static const String keyTranslation = 'widget.translation';
  static const String keyExample = 'widget.example';

  /// Схема URI тапа по виджету (PLAN.md §6).
  static const String uriScheme = 'wordoftheday';
  static const String uriHost = 'word';
  static const String uriDateParam = 'date';

  /// Сохраняет слово сегодняшего дня и обновляет виджет.
  Future<void> syncToday() => syncForDate(_wordOfDay.today);

  /// Сохраняет слово дня для [date] и обновляет виджет.
  Future<void> syncForDate(DateTime date) async {
    final word = await _wordOfDay.wordForDate(date);
    await _backend.saveWidgetData<String>(keyDate, isoDate(date));
    await _backend.saveWidgetData<String>(keyWord, word.word);
    await _backend.saveWidgetData<String>(keyTranscription, word.transcription);
    await _backend.saveWidgetData<String>(keyTranslation, word.translation);
    await _backend.saveWidgetData<String>(keyExample, word.example);
    await _backend.updateWidget(androidName: androidProviderName);
  }

  /// `yyyy-MM-dd` с ведущими нулями (без зависимости от intl).
  static String isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// URI, который нативная сторона кладёт в PendingIntent тапа.
  static Uri widgetUri(DateTime date) => Uri(
        scheme: uriScheme,
        host: uriHost,
        queryParameters: {uriDateParam: isoDate(date)},
      );

  /// Обратное преобразование; null, если URI чужой или дата невалидна
  /// (в том числе «31 февраля» — проверяется round-trip через [DateTime]).
  static DateTime? dateFromWidgetUri(Uri? uri) {
    if (uri == null || uri.scheme != uriScheme || uri.host != uriHost) {
      return null;
    }
    final raw = uri.queryParameters[uriDateParam];
    if (raw == null) {
      return null;
    }
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
    if (match == null) {
      return null;
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final candidate = DateTime(year, month, day);
    if (candidate.year != year ||
        candidate.month != month ||
        candidate.day != day) {
      return null;
    }
    return candidate;
  }
}
