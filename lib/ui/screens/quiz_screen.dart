import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/word_entry.dart';
import '../../services/dictionary_service.dart';
import '../../services/favorite_service.dart';
import '../../services/quiz_service.dart';
import '../widgets/platform_widgets.dart';
import '../widgets/type_badge.dart';
import 'home_screen.dart' show formatDate;

/// Фазы экрана квиза (этап 14).
enum _QuizPhase { loading, questions, result, empty }

/// Экран квиза-повторения — этап 14 (идея B-006 из BACKLOG.md): 5 вопросов
/// «слово → перевод из 4 вариантов», материал — избранное с добором из
/// словаря ([QuizService.generate]).
///
/// Ответ подсвечивается (верно — зелёным, ошибка — красным + верный
/// вариант), через паузу — следующий вопрос. В финале: счёт, «слова на
/// повторение» и дата следующего квиза (+3 дня); результат пишется в
/// [QuizService] (файл + напоминание через колбэк main.dart).
///
/// Сервисы приходят снаружи и остаются общими с HomeScreen; [StatefulWidget]
/// держит прогресс прохода и таймер паузы (отменяется в dispose).
class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.dictionary,
    required this.favorites,
    required this.quiz,
    this.translationLanguage = 'ru',
  });

  /// Словарь — общий с HomeScreen экземпляр (кэш слов).
  final DictionaryService dictionary;

  /// Избранное — материал вопросов (этап 13).
  final FavoriteService favorites;

  /// Сервис результатов и цикла «каждые 3 дня».
  final QuizService quiz;

  /// Язык переводов вариантов и списка «слова на повторение» (этап 19,
  /// идея B-005) — общий с HomeScreen выбор; «ru» — поведение v1.
  final String translationLanguage;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  /// Пауза с подсветкой ответа до следующего вопроса.
  static const Duration _answerPause = Duration(milliseconds: 900);

  Timer? _advanceTimer;

  _QuizPhase _phase = _QuizPhase.loading;
  List<QuizQuestion> _questions = const <QuizQuestion>[];
  int _index = 0;
  int _correct = 0;

  /// Записи с ошибками — «слова на повторение» на экране результата.
  final List<WordEntry> _wrongEntries = <WordEntry>[];

  /// Индекс выбранного варианта текущего вопроса; null — не отвечен.
  int? _chosen;

  @override
  void initState() {
    super.initState();
    unawaited(_startQuiz());
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  /// Собрать новый квиз: словарь + избранное → вопросы. Ошибка словаря или
  /// «мало слов» — пустое состояние (мягкая деградация: экран не падает).
  Future<void> _startQuiz() async {
    setState(() => _phase = _QuizPhase.loading);
    try {
      final entries = await widget.dictionary.load();
      final byId = <int, WordEntry>{
        for (final entry in entries) entry.id: entry,
      };
      // Материал — избранное, свежие первыми; при нехватке generate доберёт
      // случайными записями словаря (карточка B-006).
      final favoriteEntries = <WordEntry>[
        for (final favorite in widget.favorites.favorites.value.reversed)
          if (byId.containsKey(favorite.id)) byId[favorite.id]!,
      ];
      final questions = QuizService.generate(
        questionPool: favoriteEntries,
        dictionary: entries,
        translationLanguage: widget.translationLanguage,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _questions = questions;
        _index = 0;
        _correct = 0;
        _wrongEntries.clear();
        _chosen = null;
        _phase = questions.isEmpty ? _QuizPhase.empty : _QuizPhase.questions;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _phase = _QuizPhase.empty);
      }
    }
  }

  /// Ответ на вариант: зафиксировать выбор, посчитать и через паузу —
  /// дальше. Повторный тап (по подсвеченным кнопкам) игнорируется.
  void _answer(int optionIndex) {
    if (_phase != _QuizPhase.questions || _chosen != null) {
      return;
    }
    final question = _questions[_index];
    if (question.isCorrect(optionIndex)) {
      _correct++;
    } else {
      _wrongEntries.add(question.entry);
    }
    setState(() => _chosen = optionIndex);
    _advanceTimer = Timer(_answerPause, _advance);
  }

  /// Пауза истекла: следующий вопрос или результат.
  void _advance() {
    if (!mounted) {
      return;
    }
    if (_index + 1 < _questions.length) {
      setState(() {
        _index++;
        _chosen = null;
      });
      return;
    }
    unawaited(_finish());
  }

  /// Записать результат (файл + напоминание через onQuizFinished) и
  /// показать финальный экран.
  Future<void> _finish() async {
    await widget.quiz.recordResult(
      total: _questions.length,
      correct: _correct,
      wrongIds: <int>[for (final e in _wrongEntries) e.id],
    );
    if (mounted) {
      setState(() => _phase = _QuizPhase.result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: PlatformAppBar(title: l10n.quizTitle),
      body: Center(
        // На планшете контент не растягивается во всю ширину.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: switch (_phase) {
            _QuizPhase.loading => const PlatformProgressIndicator(),
            _QuizPhase.questions => _QuestionsView(state: this),
            _QuizPhase.result => _ResultView(state: this),
            _QuizPhase.empty => _EmptyQuiz(),
          },
        ),
      ),
    );
  }
}

/// Вопрос, прогресс и варианты ответа — вынесено в виджет, чтобы `switch`
/// билда оставался плоским.
class _QuestionsView extends StatelessWidget {
  const _QuestionsView({required this.state});

  final _QuizScreenState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final question = state._questions[state._index];
    final answered = state._chosen != null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          l10n.quizProgress(state._index + 1, state._questions.length),
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: state._questions.isEmpty
              ? null
              : state._index / state._questions.length,
        ),
        const SizedBox(height: 24),
        Card.filled(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                TypeBadge(type: question.entry.type),
                const SizedBox(height: 12),
                Text(
                  question.entry.word,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < question.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OptionButton(
              label: question.options[i],
              // После ответа кнопки блокируются — тапы не меняют выбор.
              onPressed: answered ? null : () => state._answer(i),
              correct: question.isCorrect(i),
              revealed: answered,
              chosen: state._chosen == i,
            ),
          ),
      ],
    );
  }
}

/// Кнопка варианта: нейтральная → после ответа верный подсвечен зелёным,
/// выбранная ошибка — красным, остальные гаснут.
class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.onPressed,
    required this.correct,
    required this.revealed,
    required this.chosen,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Верный ли это вариант.
  final bool correct;

  /// Ответ уже дан (подсветка включена).
  final bool revealed;

  /// Это выбранный пользователем вариант.
  final bool chosen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlight = revealed && (correct || chosen);
    final wrong = revealed && chosen && !correct;
    return FilledButton.tonal(
      onPressed: onPressed,
      style: highlight
          ? FilledButton.styleFrom(
              backgroundColor: wrong
                  ? theme.colorScheme.errorContainer
                  : theme.colorScheme.primaryContainer,
              foregroundColor: wrong
                  ? theme.colorScheme.onErrorContainer
                  : theme.colorScheme.onPrimaryContainer,
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (revealed && correct) const Icon(Icons.check_rounded),
          if (wrong) const Icon(Icons.close_rounded),
          if (revealed && (correct || wrong)) const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Финал: счёт, дата следующего квиза (+3 дня), «слова на повторение»,
/// «Ещё раз» (новый квиз) и «Готово» (закрыть экран).
class _ResultView extends StatelessWidget {
  const _ResultView({required this.state});

  final _QuizScreenState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final next = state.widget.quiz.nextQuizDate;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const SizedBox(height: 8),
        Text(
          l10n.quizResultTitle,
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.quizResultScore(state._correct, state._questions.length),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        ),
        if (next != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            l10n.quizNextAt(formatDate(next, Localizations.localeOf(context))),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (state._wrongEntries.isNotEmpty) ...<Widget>[
          const SizedBox(height: 24),
          Text(
            l10n.quizRepeatTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card.filled(
            child: Column(
              children: <Widget>[
                for (final entry in state._wrongEntries)
                  ListTile(
                    dense: true,
                    title: Text(entry.word),
                    subtitle: Text(
                      entry.translationFor(
                        state.widget.translationLanguage,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: TypeBadge(type: entry.type),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => state._startQuiz(),
          child: Text(l10n.quizRetry),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.quizDone),
        ),
      ],
    );
  }
}

/// Мало слов (крошечный словарь/ошибка чтения): заглушка с подсказкой.
class _EmptyQuiz extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isAppleStyle(context)
                ? CupertinoIcons.question_circle
                : Icons.quiz_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).quizNotEnoughWords,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
