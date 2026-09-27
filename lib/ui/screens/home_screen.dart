import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/word_entry.dart';
import '../../services/dictionary_service.dart';
import '../../services/pronunciation_service.dart';
import '../../services/word_of_day_service.dart';
import '../widgets/word_card.dart';

/// Русские месяцы в родительном падеже для [formatDateRu].
const List<String> _monthsGenitive = <String>[
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

/// «27 сентября 2026» — русская дата без зависимости от intl
/// (PLAN.md §2: внешних пакетов сверх необходимых не берём).
String formatDateRu(DateTime date) =>
    '${date.day} ${_monthsGenitive[date.month - 1]} ${date.year}';

/// Экран «Слово дня» — этап 6 (PLAN.md §1, §8): один экран с большой
/// карточкой [WordCard] слова выбранной даты; Material 3, тема следует
/// системной (задаётся в `main.dart`), язык интерфейса — русский.
///
/// [widgetTapDate] — слушаемая дата из тапа по виджету (этап 4);
/// null → показываем сегодня. Дата приходит детерминированной формулой §5,
/// поэтому экран просто запрашивает слово для неё.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.widgetTapDate});

  final ValueNotifier<DateTime?>? widgetTapDate;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final DictionaryService _dictionary = DictionaryService();
  late final WordOfDayService _wordOfDay;

  /// Произношение слова дня системным TTS — этап 9 (PLAN.md §1).
  late final PronunciationService _pronunciation;

  @override
  void initState() {
    super.initState();
    // Наблюдатель жизненного цикла — этап 9: уход в фон глушит речь.
    WidgetsBinding.instance.addObserver(this);
    _wordOfDay = WordOfDayService(_dictionary);
    _pronunciation = PronunciationService();
    unawaited(_startPronunciation());
    widget.widgetTapDate?.addListener(_onTapDateChanged);
  }

  @override
  void dispose() {
    widget.widgetTapDate?.removeListener(_onTapDateChanged);
    WidgetsBinding.instance.removeObserver(this);
    _pronunciation.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Ушли в фон/на другой экран — речь глушим: слово дня не должно
    // проигрываться «само по себе» в кармане (этап 9).
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(_pronunciation.stop());
    }
  }

  void _onTapDateChanged() {
    // Пришла новая дата из тапа по виджету — перестраиваем карточку
    // и глушим речь предыдущего слова (этап 9).
    unawaited(_pronunciation.stop());
    setState(() {});
  }

  /// Этап 9: настройка TTS. После проверки доступности языка экран
  /// перестраивается — кнопка появляется только при живом en-US-голосе.
  Future<void> _startPronunciation() async {
    await _pronunciation.start();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final tappedDate = widget.widgetTapDate?.value;
    final date = tappedDate ?? _wordOfDay.today;

    return Scaffold(
      appBar: AppBar(title: const Text('Слово дня')),
      body: Center(
        child: FutureBuilder<WordEntry>(
          key: ValueKey<DateTime>(date),
          future: _wordOfDay.wordForDate(date),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _DictionaryError(error: snapshot.error);
            }
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                // На планшете карточка не растягивается во всю ширину.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  // Этап 9: кнопка прослушивания перерисовывается по
                  // состоянию речи (динамик ↔ стоп); доступность проверяет
                  // сервис — недоступен голос, onListen == null и кнопки нет.
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _pronunciation.isSpeaking,
                    builder: (context, speaking, _) => WordCard(
                      entry: snapshot.data!,
                      dateLabel: formatDateRu(date),
                      fromWidget: tappedDate != null,
                      isListening: speaking,
                      onListen: _pronunciation.isAvailable
                          ? () => unawaited(
                                _pronunciation.toggle(snapshot.data!.word),
                              )
                          : null,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Ошибка загрузки словаря (битый ассет и т.п.): сообщаем честно,
/// без падения экрана — виджет продолжает слушать тапы и темы.
class _DictionaryError extends StatelessWidget {
  const _DictionaryError({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(
            'Не удалось загрузить словарь',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '$error',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}


