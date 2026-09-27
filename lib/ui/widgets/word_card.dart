import 'package:flutter/material.dart';

import '../../models/word_entry.dart';
import 'type_badge.dart';

/// Большая карточка слова дня — этап 6 (PLAN.md §1, §3, §8),
/// произношение — этап 9.
///
/// Показывает все поля [WordEntry]: бейдж типа, слово, транскрипцию (IPA),
/// перевод, пример и его перевод. Виджет чистый и без состояния — данными
/// его обеспечивает экран ([HomeScreen] + FutureBuilder).
///
/// [dateLabel] — уже отформатированная русская дата («27 сентября 2026»,
/// см. [formatDateRu] в `home_screen.dart`); [fromWidget] — карточка
/// открыта тапом по виджету (появляется янтарная метка «из виджета»).
///
/// Этап 9: [onListen] — произнести слово системным TTS; null — голос
/// недоступен, кнопки в карточке нет (мягкая деградация). [isListening] —
/// идёт воспроизведение: иконка динамика меняется на «стоп».
class WordCard extends StatelessWidget {
  const WordCard({
    super.key,
    required this.entry,
    this.dateLabel,
    this.fromWidget = false,
    this.onListen,
    this.isListening = false,
  });

  final WordEntry entry;
  final String? dateLabel;
  final bool fromWidget;

  /// Произнести слово дня — этап 9 (PLAN.md §1 «Произношение»).
  /// null → системный TTS недоступен: кнопки в карточке нет.
  final VoidCallback? onListen;

  /// Идёт воспроизведение — кнопка показывает «стоп» вместо динамика.
  final bool isListening;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    IconButton(
                      onPressed: onListen,
                      tooltip: isListening ? 'Остановить' : 'Прослушать',
                      color: theme.colorScheme.primary,
                      icon: Icon(
                        isListening
                            ? Icons.stop_rounded
                            : Icons.volume_up_rounded,
                      ),
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
            'из виджета',
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
