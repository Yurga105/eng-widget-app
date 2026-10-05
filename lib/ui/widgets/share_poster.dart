import 'package:flutter/material.dart';

import '../../models/word_entry.dart';
import 'type_badge.dart';

/// Постер шеринга — этап 15 (идея B-001, PLAN.md §8).
///
/// Брендированная картинка 360×450 (4:5; при pixelRatio 3 → PNG 1080×1350 —
/// портретный формат соцсетей): бейдж типа, слово, транскрипция, перевод и
/// бренд «Word of Day» с глифом «W.» — тем же, что на иконке приложения
/// (этап 3). Пример предложения и фото-ассоциация на постер не идут:
/// личный контент в шеринге не нужен, а высота 4:5 ограничена.
///
/// Этап 19 (идея B-005, часть 2): [translationLanguage] — язык перевода
/// на постере; перевода на язык нет — фолбэк записи на русский.
///
/// Цвета — явные константы светлой палитры (редизайн этапа 10), НЕ Theme:
/// постер обязан выглядеть одинаково при любой теме окружения и в тестах;
/// приложение light-only, поэтому постер всегда светлый.
///
/// Рисуется сервисом [CardShareService] через корневой оверлей за правым
/// краем экрана и растеризуется `RepaintBoundary.toImage` в PNG.
class SharePoster extends StatelessWidget {
  const SharePoster({
    super.key,
    required this.entry,
    this.translationLanguage = 'ru',
  });

  final WordEntry entry;

  /// Код языка перевода на постере (этап 19); «ru» — поведение v1.
  final String translationLanguage;

  /// Логический размер постера: 360×450, соотношение 4:5. Публичная
  /// константа — по ней сервис позиционирует оверлей и считает pixelRatio.
  static const Size logicalSize = Size(360, 450);

  /// Фон сплэша приложения (green 50, этап 10).
  static const Color _kBackground = Color(0xFFF1F8E9);

  /// Основной текст — green 900, в тон seed-палитре.
  static const Color _kOnBackground = Color(0xFF1B5E20);

  /// Второстепенный текст (транскрипция) — спокойный зелёно-серый.
  static const Color _kMuted = Color(0xFF52705C);

  /// Акцент перевода и глифа бренда — green 800 (как бейдж «слово»).
  static const Color _kAccent = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: logicalSize.width,
      height: logicalSize.height,
      color: _kBackground,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Бейдж типа: контейнер и стиль свои ([TypeBadge] красит текст
          // из textTheme окружения), а подпись и цвета — те же статические
          // константы TypeBadge, легенда типов остаётся единой.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: TypeBadge.backgroundFor(entry.type),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              TypeBadge.labelFor(context, entry.type),
              style: TextStyle(
                color: TypeBadge.foregroundFor(entry.type),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          // FittedBox: длинный фразовый глагол ужимается одной строкой,
          // а не переносится и не обрезается — заголовок постера цельный.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              entry.word,
              style: const TextStyle(
                color: _kOnBackground,
                fontSize: 40,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            entry.transcription,
            style: const TextStyle(color: _kMuted, fontSize: 19),
          ),
          const SizedBox(height: 26),
          // Перевод может быть длинным («проводить время вместе…») —
          // четыре строки с ellipsis вместо выхода за границы постера.
          Text(
            entry.translationFor(translationLanguage),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _kAccent,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          const Spacer(),
          // Бренд: глиф «W» на зелёном круге (иконка приложения) + название.
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _kAccent,
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  'W',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Word of Day',
                style: TextStyle(
                  color: _kOnBackground,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
