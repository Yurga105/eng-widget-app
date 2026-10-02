import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/word_entry.dart';
import '../../services/favorite_service.dart';
import '../../services/pronunciation_service.dart';
import '../../services/word_image_service.dart';
import '../widgets/platform_widgets.dart';
import '../widgets/word_card.dart';
import 'home_screen.dart';

/// Полная карточка избранного слова — этап 13: та же [WordCard], что и
/// слово дня (TTS-кнопка, фото-ассоциация, звезда), но дата в подписи —
/// дата добавления в избранное. Фото показывается, если оно уже есть у
/// записи (снять/заменить можно из карточки дня; здесь — просмотр).
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
  });

  final WordEntry entry;

  /// Дата добавления в избранное — подпись карточки.
  final DateTime added;

  final FavoriteService favorites;
  final PronunciationService pronunciation;
  final WordImageService wordImages;

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  late final Future<String?> _image;

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
          // На планшете карточка не растягивается во всю ширину.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            // Карточку показываем сразу, секция фото подсветится по
            // готовности future — слово не ждёт диск.
            child: FutureBuilder<String?>(
              future: _image,
              builder: (context, snapshot) =>
                  ValueListenableBuilder<List<Favorite>>(
                valueListenable: widget.favorites.favorites,
                builder: (context, favs, _) => ValueListenableBuilder<bool>(
                  valueListenable: widget.pronunciation.isSpeaking,
                  builder: (context, speaking, _) => WordCard(
                    entry: widget.entry,
                    dateLabel: formatDate(
                      widget.added,
                      Localizations.localeOf(context),
                    ),
                    fromWidget: false,
                    isListening: speaking,
                    isFavorite: favs.any((f) => f.id == widget.entry.id),
                    onToggleFavorite: () => unawaited(
                      widget.favorites.toggle(widget.entry.id),
                    ),
                    onListen: widget.pronunciation.isAvailable
                        ? () => unawaited(
                              widget.pronunciation.toggle(widget.entry.word),
                            )
                        : null,
                    imagePath: snapshot.data,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
