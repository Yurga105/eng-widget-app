import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/word_entry.dart';
import '../../services/card_share_service.dart';
import '../../services/dictionary_service.dart';
import '../../services/favorite_service.dart';
import '../../services/pronunciation_service.dart';
import '../../services/quiz_service.dart';
import '../../services/word_image_service.dart';
import '../../services/word_of_day_service.dart';
import '../widgets/image_source_sheet.dart';
import '../widgets/platform_widgets.dart';
import '../widgets/share_poster.dart';
import '../widgets/word_card.dart';
import 'favorites_screen.dart';
import 'quiz_screen.dart';

/// «27 сентября 2026» / «27 September 2026» — локализованная дата.
/// Символы дат (включая русские месяцы в родительном падеже) берёт
/// `intl`; отдельного списка месяцев и сторонних пакетов не нужно.
String formatDate(DateTime date, Locale locale) =>
    DateFormat('d MMMM y', locale.toLanguageTag()).format(date);

/// Экран «Слово дня» — этап 6 (PLAN.md §1, §8): один экран с большой
/// карточкой [WordCard] слова выбранной даты; Material 3, светлая
/// зелёная тема (задаётся в `main.dart`), язык интерфейса — en/ru/id
/// по локали устройства (lib/l10n).
///
/// [widgetTapDate] — слушаемая дата из тапа по виджету (этап 4);
/// null → показываем сегодня. Дата приходит детерминированной формулой §5,
/// поэтому экран просто запрашивает слово для неё.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.widgetTapDate,
    this.quiz,
    this.quizOpenRequest,
  });

  final ValueNotifier<DateTime?>? widgetTapDate;

  /// Квиз-повторение (этап 14): сервис общий с `main.dart` (напоминания
  /// читают ту же историю) — передаётся снаружи; null (изолированные
  /// тесты) — экран создаёт свой.
  final QuizService? quiz;

  /// Сигнал «открой квиз» — тап по напоминанию (этап 14), владелец —
  /// `main.dart`; HomeScreen слушает и открывает экран квиза.
  final ValueNotifier<bool>? quizOpenRequest;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final DictionaryService _dictionary = DictionaryService();
  late final WordOfDayService _wordOfDay;

  /// Произношение слова дня системным TTS — этап 9 (PLAN.md §1).
  late final PronunciationService _pronunciation;

  /// Фото-ассоциации слов (этап 12, PLAN.md §1): выбор, хранение, удаление.
  final WordImageService _wordImages = WordImageService();

  /// Избранное (этап 13, идея B-002): один сервис на карточку дня,
  /// список избранного и карточку избранного слова — состояние общее.
  final FavoriteService _favorites = FavoriteService();

  /// Шеринг карточки картинкой (этап 15, идея B-001): постер → PNG →
  /// системный share sheet. Сервис без состояния — без dispose.
  final CardShareService _cardShare = CardShareService();

  /// Квиз-повторение (этап 14, идея B-006): общий с `main.dart` (если
  /// передан) — напоминание и экран квиза читают одну историю результатов.
  late final QuizService _quiz;

  /// Кэш future-ов «слово + фото» по дате (этап 12): FutureBuilder не
  /// перезапускает загрузку на каждом билде, а смена фото подменяет
  /// значение в кэше — карточка не мигает пустой секцией.
  final Map<DateTime, Future<_WordCardData>> _cardFutures = {};

  @override
  void initState() {
    super.initState();
    // Наблюдатель жизненного цикла — этап 9: уход в фон глушит речь.
    WidgetsBinding.instance.addObserver(this);
    _wordOfDay = WordOfDayService(_dictionary);
    _pronunciation = PronunciationService();
    _quiz = widget.quiz ?? QuizService();
    unawaited(_startPronunciation());
    widget.widgetTapDate?.addListener(_onTapDateChanged);
    widget.quizOpenRequest?.addListener(_onQuizOpenRequest);
    // Тап по напоминанию мог прийти до первого кадра (холодный старт):
    // ValueNotifier дёргает листенеры только изменениями, поэтому
    // стартовое значение проверяем сами.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onQuizOpenRequest());
  }

  @override
  void dispose() {
    widget.quizOpenRequest?.removeListener(_onQuizOpenRequest);
    widget.widgetTapDate?.removeListener(_onTapDateChanged);
    WidgetsBinding.instance.removeObserver(this);
    _pronunciation.dispose();
    _favorites.dispose();
    // Собственный сервис (не передан снаружи) — освобождаем сами.
    if (widget.quiz == null) {
      _quiz.dispose();
    }
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

  /// Слово дня + его фото-ассоциация одним future (этап 12): фото ищется
  /// по `entry.id` — ассоциация переживает ежегодные повторы слова.
  Future<_WordCardData> _cardDataFor(DateTime date) =>
      _cardFutures.putIfAbsent(date, () async {
        final entry = await _wordOfDay.wordForDate(date);
        final image = await _wordImages.imageFor(entry.id);
        return _WordCardData(entry, image?.path);
      });

  /// Этап 12: платформенный выбор источника (лист/экшн-щит) → съёмка или
  /// выбор из галереи → сохранение ассоциации. Отмена на любом шаге —
  /// молча; сбой плагина сервис глотает сам.
  Future<void> _pickWordImage(WordEntry entry) async {
    final camera = await showImageSourcePicker(context);
    if (camera == null || !mounted) {
      return;
    }
    final path = await _wordImages.capture(
      entry.id,
      camera ? WordImageSource.camera : WordImageSource.gallery,
    );
    if (!mounted || path == null) {
      return;
    }
    _replaceCardFuture(entry, path);
  }

  /// Этап 12: кнопка «убрать фото» — удалить ассоциацию записи.
  Future<void> _removeWordImage(WordEntry entry) async {
    await _wordImages.remove(entry.id);
    if (mounted) {
      _replaceCardFuture(entry, null);
    }
  }

  /// Подменяет кэш карточки текущей даты: фото изменилось — карточка
  /// перерисовывается без повторной загрузки слова.
  void _replaceCardFuture(WordEntry entry, String? imagePath) {
    setState(() {
      _cardFutures[widget.widgetTapDate?.value ?? _wordOfDay.today] =
          Future.value(_WordCardData(entry, imagePath));
    });
  }

  /// Этап 13: экран списка избранного. Сервисы передаются дальше —
  /// состояние и кэш едины с карточкой дня.
  Future<void> _openFavorites() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FavoritesScreen(
          dictionary: _dictionary,
          favorites: _favorites,
          pronunciation: _pronunciation,
          wordImages: _wordImages,
        ),
      ),
    );
  }

  /// Этап 14: сигнал из main.dart (тап по напоминанию) — открыть квиз.
  void _onQuizOpenRequest() {
    final request = widget.quizOpenRequest;
    if (request == null || !request.value) {
      return;
    }
    request.value = false; // сигнал обработан
    if (mounted) {
      unawaited(_openQuiz());
    }
  }

  /// Этап 14: экран квиза-повторения (идея B-006).
  Future<void> _openQuiz() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuizScreen(
          dictionary: _dictionary,
          favorites: _favorites,
          quiz: _quiz,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tappedDate = widget.widgetTapDate?.value;
    final date = tappedDate ?? _wordOfDay.today;

    return Scaffold(
      // Этап 11: навбар адаптивный — CupertinoNavigationBar на iOS;
      // этап 13: справа — вход в список избранного; этап 14 — квиз.
      appBar: PlatformAppBar(
        title: AppLocalizations.of(context).homeTitle,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PlatformIconActionButton(
              onPressed: _openQuiz,
              tooltip: AppLocalizations.of(context).quizTitle,
              materialIcon: Icons.quiz_rounded,
              cupertinoIcon: CupertinoIcons.question_circle,
            ),
            PlatformIconActionButton(
              onPressed: _openFavorites,
              tooltip: AppLocalizations.of(context).favoritesTitle,
              materialIcon: Icons.star_border_rounded,
              cupertinoIcon: CupertinoIcons.star,
            ),
          ],
        ),
      ),
      body: Center(
        // Этап 12: слово и фото-ассоциация грузятся одним future
        // (кэш по дате) — карточка не мигает пустой секцией фото.
        child: FutureBuilder<_WordCardData>(
          key: ValueKey<DateTime>(date),
          future: _cardDataFor(date),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _DictionaryError(error: snapshot.error);
            }
            if (!snapshot.hasData) {
              return const PlatformProgressIndicator();
            }
            final data = snapshot.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                // На планшете карточка не растягивается во всю ширину.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  // Этап 9: кнопка прослушивания перерисовывается по
                  // состоянию речи (динамик ↔ стоп); доступность проверяет
                  // сервис — недоступен голос, onListen == null и кнопки нет.
                  // Этап 13: звезда перерисовывается по состоянию
                  // избранного (тот же ValueNotifier слушает и список).
                  child: ValueListenableBuilder<List<Favorite>>(
                    valueListenable: _favorites.favorites,
                    builder: (context, favs, _) => ValueListenableBuilder<bool>(
                      valueListenable: _pronunciation.isSpeaking,
                      builder: (context, speaking, _) => WordCard(
                        entry: data.entry,
                        dateLabel: formatDate(
                          date,
                          Localizations.localeOf(context),
                        ),
                        fromWidget: tappedDate != null,
                        isListening: speaking,
                        isFavorite: favs.any((f) => f.id == data.entry.id),
                        onToggleFavorite: () =>
                            unawaited(_favorites.toggle(data.entry.id)),
                        onListen: _pronunciation.isAvailable
                            ? () => unawaited(
                                _pronunciation.toggle(data.entry.word),
                              )
                            : null,
                        // Этап 15: «поделиться» — постер карточки → PNG →
                        // системный share sheet (текст сопровождает картинку).
                        onShare: () => unawaited(
                            _cardShare.sharePoster(
                              context: context,
                              poster: (context) =>
                                  SharePoster(entry: data.entry),
                              text:
                                  '${data.entry.word} — ${data.entry.translation}',
                            ),
                          ),
                        // Этап 12: фото-ассоциация и её действия (ключ — id
                        // слова; замена/удаление подменяют future в кэше).
                        imagePath: data.imagePath,
                        onPickImage: () =>
                            unawaited(_pickWordImage(data.entry)),
                        onRemoveImage: data.imagePath == null
                            ? null
                            : () => unawaited(_removeWordImage(data.entry)),
                      ),
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

/// Слово дня + его фото-ассоциация — грузятся одним future (этап 12).
class _WordCardData {
  const _WordCardData(this.entry, this.imagePath);

  final WordEntry entry;
  final String? imagePath;
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
            platformErrorIcon(context),
            size: 48,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).dictionaryError,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '$error',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
