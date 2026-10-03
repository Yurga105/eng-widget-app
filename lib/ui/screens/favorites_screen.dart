import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/word_entry.dart';
import '../../services/dictionary_service.dart';
import '../../services/favorite_service.dart';
import '../../services/pronunciation_service.dart';
import '../../services/user_example_service.dart';
import '../../services/word_image_service.dart';
import '../widgets/platform_widgets.dart';
import '../widgets/type_badge.dart';
import 'word_detail_screen.dart';

/// Список избранного — этап 13 (идея B-002 из `docs/ideas/BACKLOG.md`):
/// свежие добавления сверху, тап — полная карточка слова
/// ([WordDetailScreen]), свайп влево — убрать из избранного.
///
/// Stateless: словарь грузится [FutureBuilder]-ом, изменения коллекции
/// приходят из [FavoriteService.favorites] (ValueListenableBuilder) —
/// экран живой без собственного состояния.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({
    super.key,
    required this.dictionary,
    required this.favorites,
    required this.pronunciation,
    required this.wordImages,
    required this.userExamples,
  });

  /// Словарь — общий с HomeScreen экземпляр (кэш слов).
  final DictionaryService dictionary;

  /// Сервис избранного — общий с HomeScreen (живая синхронизация звезды).
  final FavoriteService favorites;

  /// TTS — общий с HomeScreen: одна речь на приложение.
  final PronunciationService pronunciation;

  /// Фото-ассоциации — общий с HomeScreen экземпляр.
  final WordImageService wordImages;

  /// Свои примеры употребления (этап 16, идея B-003) — общий с HomeScreen
  /// экземпляр: карточка избранного слова редактирует свою ассоциацию.
  final UserExampleService userExamples;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: PlatformAppBar(title: l10n.favoritesTitle),
      body: FutureBuilder<List<WordEntry>>(
        future: dictionary.load(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _FavoritesError(error: snapshot.error);
          }
          if (!snapshot.hasData) {
            return const Center(child: PlatformProgressIndicator());
          }
          final byId = <int, WordEntry>{
            for (final entry in snapshot.data!) entry.id: entry,
          };
          return ValueListenableBuilder<List<Favorite>>(
            valueListenable: favorites.favorites,
            builder: (context, list, _) {
              if (list.isEmpty) {
                return const _EmptyFavorites();
              }
              // Свежие — сверху: файл хранит порядок «старые → новые».
              final ordered = list.reversed
                  .where((favorite) => byId.containsKey(favorite.id))
                  .toList(growable: false);
              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: ordered.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final favorite = ordered[index];
                  final entry = byId[favorite.id]!;
                  return Dismissible(
                    key: ValueKey<int>(favorite.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      color: theme.colorScheme.errorContainer,
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    onDismissed: (_) =>
                        unawaited(favorites.remove(favorite.id)),
                    child: ListTile(
                      title: Text(
                        entry.word,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        entry.translation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: TypeBadge(type: entry.type),
                      onTap: () =>
                          unawaited(_openDetail(context, entry, favorite)),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  /// Полная карточка избранного слова.
  Future<void> _openDetail(
    BuildContext context,
    WordEntry entry,
    Favorite favorite,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WordDetailScreen(
          entry: entry,
          added: favorite.added,
          favorites: favorites,
          pronunciation: pronunciation,
          wordImages: wordImages,
          userExamples: userExamples,
        ),
      ),
    );
  }
}

/// Пустое избранное: звезда-заглушка и подсказка, как собирать список.
class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAppleStyle(context)
                  ? CupertinoIcons.star
                  : Icons.star_outline_rounded,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).favoritesEmpty,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Ошибка загрузки словаря (как на HomeScreen — битый ассет и т.п.).
class _FavoritesError extends StatelessWidget {
  const _FavoritesError({required this.error});

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
