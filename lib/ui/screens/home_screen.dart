import 'package:flutter/material.dart';

import '../../models/word_entry.dart';
import '../../services/dictionary_service.dart';
import '../../services/word_of_day_service.dart';
import '../../services/widget_sync_service.dart';

/// Промежуточная карточка этапа 4: слово выбранной даты — проверка моста
/// «виджет ↔ приложение» (слово в виджете = слову на этом экране).
///
/// [widgetTapDate] — слушаемая дата из тапа по виджету; null → сегодня.
/// Полноценный UI (M3-карточка, бейджи типов) — этап 6 (PLAN.md §8).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.widgetTapDate});

  final ValueNotifier<DateTime?>? widgetTapDate;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DictionaryService _dictionary = DictionaryService();
  late final WordOfDayService _wordOfDay;

  @override
  void initState() {
    super.initState();
    _wordOfDay = WordOfDayService(_dictionary);
    widget.widgetTapDate?.addListener(_onTapDateChanged);
  }

  @override
  void dispose() {
    widget.widgetTapDate?.removeListener(_onTapDateChanged);
    super.dispose();
  }

  void _onTapDateChanged() {
    setState(() {
      // Перестраиваем карточку: пришла новая дата из виджета.
    });
  }

  @override
  Widget build(BuildContext context) {
    final tappedDate = widget.widgetTapDate?.value;
    final date = tappedDate ?? _wordOfDay.today;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Слово дня')),
      body: Center(
        child: FutureBuilder<WordEntry>(
          key: ValueKey<DateTime>(date),
          future: _wordOfDay.wordForDate(date),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Не удалось загрузить словарь:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              );
            }
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            }
            final word = snapshot.data!;
            final iso = WidgetSyncService.isoDate(date);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tappedDate == null
                        ? 'Дата: $iso'
                        : 'Дата: $iso — открыто из виджета',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    word.word,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    word.transcription,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    word.translation,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(word.example, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 4),
                  Text(
                    word.exampleRu,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Полноценная карточка слова — этап 6 (см. PLAN.md).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

