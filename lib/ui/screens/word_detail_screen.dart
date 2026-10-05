import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/word_entry.dart';
import '../../services/card_share_service.dart';
import '../../services/favorite_service.dart';
import '../../services/pronunciation_service.dart';
import '../../services/user_example_service.dart';
import '../../services/word_image_service.dart';
import '../widgets/platform_widgets.dart';
import '../widgets/share_poster.dart';
import '../widgets/word_card.dart';
import 'home_screen.dart';

/// Полная карточка избранного слова — этап 13: та же [WordCard], что и
/// слово дня (TTS-кнопка, фото-ассоциация, звезда), но дата в подписи —
/// дата добавления в избранное. Фото показывается, если оно уже есть у
/// записи (снять/заменить можно из карточки дня; здесь — просмотр).
///
/// Этап 16 (идея B-003): под карточкой — секция «Свой пример»
/// ([_UserExampleSection]): личная ассоциация к слову. На карточке дня
/// и виджете секции нет (контракт §6).
///
/// Сервисы приходят снаружи и остаются общими с HomeScreen — одна речь
/// и один кэш на приложение. [StatefulWidget]: держит Future фото и
/// глушит речь при уходе с экрана (паттерн этапа 9).
class WordDetailScreen extends StatefulWidget {
  const WordDetailScreen({
    super.key,
    required this.entry,
    required this.added,
    required this.favorites,
    required this.pronunciation,
    required this.wordImages,
    required this.userExamples,
    this.translationLanguage = 'ru',
  });

  final WordEntry entry;

  /// Дата добавления в избранное — подпись карточки.
  final DateTime added;

  final FavoriteService favorites;
  final PronunciationService pronunciation;
  final WordImageService wordImages;

  /// Свои примеры употребления (этап 16, идея B-003) — общий с HomeScreen
  /// экземпляр: секция под карточкой читает и меняет его состояние.
  final UserExampleService userExamples;

  /// Язык переводов карточки и постера (этап 19, идея B-005) — общий
  /// с HomeScreen выбор; «ru» — поведение v1.
  final String translationLanguage;

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  late final Future<String?> _image;

  /// Шеринг карточки избранного слова (этап 15) — тот же постер, что и у
  /// карточки дня; сервис без состояния — без dispose.
  final CardShareService _cardShare = CardShareService();

  @override
  void initState() {
    super.initState();
    // Фото ищется по id записи (этап 12) — переживёт годовые повторы.
    _image = widget.wordImages
        .imageFor(widget.entry.id)
        .then((file) => file?.path);
  }

  @override
  void dispose() {
    // Ушли с экрана слова — догоняющую речь глушим (как при смене слова
    // из виджета, этап 9).
    unawaited(widget.pronunciation.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PlatformAppBar(title: widget.entry.word),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          // На планшете контент не растягивается во всю ширину.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Карточку показываем сразу, секция фото подсветится по
                // готовности future — слово не ждёт диск.
                FutureBuilder<String?>(
                  future: _image,
                  builder: (context, snapshot) =>
                      ValueListenableBuilder<List<Favorite>>(
                        valueListenable: widget.favorites.favorites,
                        builder: (context, favs, _) => ValueListenableBuilder<bool>(
                          valueListenable: widget.pronunciation.isSpeaking,
                          builder: (context, speaking, _) => WordCard(
                            entry: widget.entry,
                            translationLanguage: widget.translationLanguage,
                            dateLabel: formatDate(
                              widget.added,
                              Localizations.localeOf(context),
                            ),
                            fromWidget: false,
                            isListening: speaking,
                            isFavorite: favs.any(
                              (f) => f.id == widget.entry.id,
                            ),
                            onToggleFavorite: () => unawaited(
                              widget.favorites.toggle(widget.entry.id),
                            ),
                            onListen: widget.pronunciation.isAvailable
                                ? () => unawaited(
                                    widget.pronunciation.toggle(
                                      widget.entry.word,
                                    ),
                                  )
                                : null,
                            // Этап 15: «поделиться» — как в карточке дня.
                            onShare: () => unawaited(
                              _cardShare.sharePoster(
                                context: context,
                                poster: (context) => SharePoster(
                                  entry: widget.entry,
                                  translationLanguage:
                                      widget.translationLanguage,
                                ),
                                text: '${widget.entry.word} — '
                                    '${widget.entry.translationFor(widget.translationLanguage)}',
                              ),
                            ),
                            imagePath: snapshot.data,
                          ),
                        ),
                      ),
                ),
                // Этап 16 (идея B-003): личная ассоциация живёт только в
                // избранном — карточка дня и виджет не меняются (§6).
                const SizedBox(height: 16),
                _UserExampleSection(
                  wordId: widget.entry.id,
                  service: widget.userExamples,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Секция «Свой пример» под карточкой избранного слова — этап 16 (идея
/// B-003 из `docs/ideas/BACKLOG.md`): личная ассоциация «где я встретил
/// это слово» цепляет сильнее словарного примера.
///
/// Показ: примера нет — кнопка добавления; есть — текст и кнопки
/// «изменить»/«удалить» (адаптивные [PlatformIconActionButton], паттерн
/// фото-ассоциации этапа 12). Ввод — inline: многострочное поле с
/// лимитом [UserExampleService.maxLength] и кнопками «Сохранить»/
/// «Отмена»; пустой ввод — то же, что удаление. Оформление повторяет
/// [WordCard]: `Card.filled` без полей — карточка и секция читаются как
/// один стек контента.
class _UserExampleSection extends StatefulWidget {
  const _UserExampleSection({required this.wordId, required this.service});

  /// id записи словаря — ключ хранения ([UserExampleService]).
  final int wordId;

  final UserExampleService service;

  @override
  State<_UserExampleSection> createState() => _UserExampleSectionState();
}

class _UserExampleSectionState extends State<_UserExampleSection> {
  /// Контроллер поля ввода; null — режим просмотра (нет примера или
  /// показываем сохранённый).
  TextEditingController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Открыть редактор: [initial] — сохранённый текст (редактирование)
  /// или пустая строка (новый пример).
  void _startEditing(String initial) {
    setState(() {
      _controller?.dispose();
      _controller = TextEditingController(text: initial);
    });
  }

  void _stopEditing() {
    setState(() {
      _controller?.dispose();
      _controller = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final controller = _controller;
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.userExampleSectionTitle,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              if (controller != null) ...[
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 5,
                  minLines: 2,
                  maxLength: UserExampleService.maxLength,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.userExampleHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _stopEditing,
                      child: Text(l10n.cancel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        // Пустой ввод сервис трактует как удаление —
                        // кнопка всегда валидна.
                        unawaited(
                          widget.service.save(widget.wordId, controller.text),
                        );
                        _stopEditing();
                      },
                      child: Text(l10n.userExampleSave),
                    ),
                  ],
                ),
              ] else
                ValueListenableBuilder<Map<int, String>>(
                  valueListenable: widget.service.examples,
                  builder: (context, examples, _) {
                    final text = examples[widget.wordId];
                    if (text == null) {
                      return OutlinedButton.icon(
                        onPressed: () => _startEditing(''),
                        icon: const Icon(Icons.edit_note_outlined),
                        label: Text(l10n.userExampleAdd),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          text,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.4,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            PlatformIconActionButton(
                              onPressed: () => _startEditing(text),
                              tooltip: l10n.userExampleEdit,
                              color: theme.colorScheme.onSurfaceVariant,
                              materialIcon: Icons.edit_outlined,
                              cupertinoIcon: CupertinoIcons.pencil,
                            ),
                            PlatformIconActionButton(
                              onPressed: () => unawaited(
                                widget.service.remove(widget.wordId),
                              ),
                              tooltip: l10n.userExampleRemove,
                              color: theme.colorScheme.onSurfaceVariant,
                              materialIcon: Icons.delete_outline_rounded,
                              cupertinoIcon: CupertinoIcons.trash,
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
