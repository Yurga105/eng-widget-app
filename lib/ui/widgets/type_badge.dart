import 'package:flutter/material.dart';

import '../../models/word_entry.dart';

/// Бейдж типа единицы словаря — этап 6 (PLAN.md §1, §8).
///
/// Русские подписи и фиксированные цвета (одинаковы в светлой и тёмной
/// теме, чтобы тип читался как узнаваемая легенда):
///  - [WordType.word] — «слово», индиго;
///  - [WordType.idiom] — «идиома», янтарный;
///  - [WordType.phrasalVerb] — «фразовый глагол», бирюзовый (teal).
class TypeBadge extends StatelessWidget {
  const TypeBadge({super.key, required this.type});

  final WordType type;

  /// Русская подпись типа — единственное место, где она задаётся.
  static String labelFor(WordType type) => switch (type) {
        WordType.word => 'слово',
        WordType.idiom => 'идиома',
        WordType.phrasalVerb => 'фразовый глагол',
      };

  /// Цвет заливки бейджа.
  static Color backgroundFor(WordType type) => switch (type) {
        WordType.word => const Color(0xFF3F51B5), // indigo 500
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
        labelFor(type),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: foregroundFor(type),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
