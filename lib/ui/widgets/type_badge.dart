import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/word_entry.dart';

/// Бейдж типа единицы словаря — этап 6 (PLAN.md §1, §8).
///
/// Локализованные подписи (en/ru/id, lib/l10n) и фиксированные цвета
/// (одинаковы в светлой и тёмной теме, чтобы тип читался как узнаваемая
/// легенда):
///  - [WordType.word] — «слово»/«word»/«kata», зелёный;
///  - [WordType.idiom] — «идиома»/«idiom», янтарный;
///  - [WordType.phrasalVerb] — «фразовый глагол»/«phrasal verb»/
///    «frasa kata kerja», бирюзовый (teal).
class TypeBadge extends StatelessWidget {
  const TypeBadge({super.key, required this.type});

  final WordType type;

  /// Локализованная подпись типа — единственное место, где она задаётся.
  static String labelFor(BuildContext context, WordType type) =>
      switch (type) {
        WordType.word => AppLocalizations.of(context).wordTypeWord,
        WordType.idiom => AppLocalizations.of(context).wordTypeIdiom,
        WordType.phrasalVerb =>
          AppLocalizations.of(context).wordTypePhrasalVerb,
      };

  /// Цвет заливки бейджа. Редизайн: «слово» — зелёный (green 800,
  /// в тон новому seed-цвету приложения) вместо индиго.
  static Color backgroundFor(WordType type) => switch (type) {
        WordType.word => const Color(0xFF2E7D32), // green 800
        WordType.idiom => const Color(0xFFFFB300), // amber 600
        WordType.phrasalVerb => const Color(0xFF00796B), // teal 700
      };

  /// Цвет подписи: на янтарном — тёмный (контраст), на остальных — белый.
  static Color foregroundFor(WordType type) => switch (type) {
        WordType.idiom => const Color(0xFF3E2723), // brown 900
        WordType.word => Colors.white,
        WordType.phrasalVerb => Colors.white,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundFor(type),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        labelFor(context, type),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: foregroundFor(type),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
