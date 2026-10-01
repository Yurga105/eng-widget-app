import 'dart:io';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/word_entry.dart';
import 'platform_widgets.dart';
import 'type_badge.dart';

/// Большая карточка слова дня — этап 6 (PLAN.md §1, §3, §8),
/// произношение — этап 9.
///
/// Показывает все поля [WordEntry]: бейдж типа, слово, транскрипцию (IPA),
/// перевод, пример и его перевод. Виджет чистый и без состояния — данными
/// его обеспечивает экран ([HomeScreen] + FutureBuilder).
///
/// [dateLabel] — уже отформатированная локализованная дата («27 сентября
/// 2026» / «27 September 2026», см. [formatDate] в `home_screen.dart`);
/// [fromWidget] — карточка открыта тапом по виджету (появляется янтарная
/// метка «из виджета»).
///
/// Этап 9: [onListen] — произнести слово системным TTS; null — голос
/// недоступен, кнопки в карточке нет (мягкая деградация). [isListening] —
/// идёт воспроизведение: иконка динамика меняется на «стоп».
///
/// Этап 11: кнопка — адаптивная [PlatformIconActionButton]: на iOS это
/// CupertinoButton с иконкой SF Symbols, на Android — IconButton.
///
/// Этап 12: [imagePath] — фото-ассоциация записи (`documents/word_images/
/// {id}.jpg`, сервис `WordImageService`); [onPickImage] добавляет/заменяет
/// фото, [onRemoveImage] удаляет. null-параметры прячут соответствующие
/// элементы — карточка работает и без фото.
class WordCard extends StatelessWidget {
  const WordCard({
    super.key,
    required this.entry,
    this.dateLabel,
    this.fromWidget = false,
    this.onListen,
    this.isListening = false,
    this.imagePath,
    this.onPickImage,
    this.onRemoveImage,
  });

  final WordEntry entry;
  final String? dateLabel;
  final bool fromWidget;

  /// Произнести слово дня — этап 9 (PLAN.md §1 «Произношение»).
  /// null → системный TTS недоступен: кнопки в карточке нет.
  final VoidCallback? onListen;

  /// Идёт воспроизведение — кнопка показывает «стоп» вместо динамика.
  final bool isListening;

  /// Путь к фото-ассоциации записи (этап 12); null — фото нет.
  final String? imagePath;

  /// Открыть выбор источника фото: добавить (фото нет) или заменить.
  final VoidCallback? onPickImage;

  /// Удалить фото-ассоциацию; null — кнопки удаления нет.
  final VoidCallback? onRemoveImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        // SizedBox растягивает колонку на всю ширину карточки — иначе
        // короткое слово сузит карточку до содержимого.
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Wrap, а не Row: на узких экранах «фразовый глагол» +
              // дата + метка переносятся на новую строку без переполнения.
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TypeBadge(type: entry.type),
                  if (fromWidget) const _FromWidgetChip(),
                  if (dateLabel != null)
                    Text(
                      dateLabel!,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Этап 9: слово и кнопка прослушивания в одной строке —
              // Expanded разрешает длинным фразовым глаголам переноситься,
              // кнопка остаётся справа (критерий «влезает на 320×480»).
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      entry.word,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (onListen != null)
                    PlatformIconActionButton(
                      onPressed: onListen,
                      tooltip: isListening
                          ? l10n.stopPlayback
                          : l10n.listen,
                      color: theme.colorScheme.primary,
                      materialIcon: isListening
                          ? Icons.stop_rounded
                          : Icons.volume_up_rounded,
                      cupertinoIcon: isListening
                          ? CupertinoIcons.stop_fill
                          : CupertinoIcons.volume_up,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                entry.transcription,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              // Этап 12: фото-ассоциация — визуальный якорь слова; стоит
              // между транскрипцией и переводом, чтобы примеры (перевод
              // + два предложения) остались замыкающими блоками карточки.
              if (imagePath != null) ...[
                const SizedBox(height: 12),
                _WordImage(
                  path: imagePath!,
                  onReplace: onPickImage,
                  onRemove: onRemoveImage,
                ),
              ] else if (onPickImage != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onPickImage,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(l10n.wordImageAdd),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                entry.translation,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                entry.example,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 4),
              Text(
                entry.exampleRu,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Фото-ассоциация слова дня (этап 12): картинка 16:10 со скруглением и
/// строка действий под ней — «заменить» и «убрать» (адаптивные
/// [PlatformIconActionButton]). Битый/удалённый файл не роняет карточку —
/// errorBuilder показывает заглушку с платформенной иконкой ошибки.
class _WordImage extends StatelessWidget {
  const _WordImage({required this.path, this.onReplace, this.onRemove});

  final String path;
  final VoidCallback? onReplace;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: theme.colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: Icon(
                  platformErrorIcon(context),
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ),
        ),
        if (onReplace != null || onRemove != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onReplace != null)
                  PlatformIconActionButton(
                    onPressed: onReplace,
                    tooltip: l10n.wordImageReplace,
                    color: theme.colorScheme.onSurfaceVariant,
                    materialIcon: Icons.photo_camera_outlined,
                    cupertinoIcon: CupertinoIcons.camera,
                  ),
                if (onRemove != null)
                  PlatformIconActionButton(
                    onPressed: onRemove,
                    tooltip: l10n.wordImageRemove,
                    color: theme.colorScheme.onSurfaceVariant,
                    materialIcon: Icons.delete_outline_rounded,
                    cupertinoIcon: CupertinoIcons.trash,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Янтарная метка «из виджета» — второй (после бейджа идиомы) янтарный
/// акцент палитры §1. Цвета фиксированы и подобраны под обе темы.
class _FromWidgetChip extends StatelessWidget {
  const _FromWidgetChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        // ~18 % янтарного поверх фона (const вместо withOpacity).
        color: const Color(0x2EFFB300),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.widgets_rounded,
            size: 14,
            color: isDark ? const Color(0xFFFFD54F) : const Color(0xFF8A5A00),
          ),
          const SizedBox(width: 4),
          Text(
            AppLocalizations.of(context).fromWidgetChip,
            style: theme.textTheme.labelMedium?.copyWith(
              color: isDark ? const Color(0xFFFFD54F) : const Color(0xFF8A5A00),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
