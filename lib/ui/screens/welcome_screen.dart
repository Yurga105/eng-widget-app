import 'package:flutter/material.dart';

/// Пробный preload-экран приветствия — идея B-009, ветка
/// `trial/b-009-splash` (в main НЕ мерджится без решения владельца).
///
/// Композиция по рекомендации бизнес-анализа: центр — бренд приложения
/// (глиф «W.» как на иконке лаунчера, название, одна фраза «что это»),
/// низ — логотип студии кружком. Тап в любую точку пропускает сплэш —
/// он не должен быть барьером.
///
/// Строки пока по-русски: пробник смотрит владелец; при повышении до
/// этапа 17 — перевести в ARB en/ru/id (TODO(l10n)).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.onFinished});

  /// Сплэш закончился (анимация доиграла или тап) — показать HomeScreen.
  final VoidCallback onFinished;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinished();
      }
    });

  /// Появление центрального блока.
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.55, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _scale = Tween<double>(begin: 0.92, end: 1)
      .animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
        ),
      );

  /// Логотип студии проявляется позже основного блока — иерархия
  /// «сначала приложение, потом студия».
  late final Animation<double> _studioFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.45, 1, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      // Сплэш не задерживает: тап — сразу к слову дня.
      onTap: widget.onFinished,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    children: [
                      // Глиф «W.» — зеркало иконки лаунчера (этап 8/10).
                      Container(
                        width: 116,
                        height: 116,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'W.',
                          style: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Word of Day',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        // TODO(l10n): пробник; при повышении до этапа 17
                        // перевести в ARB en/ru/id.
                        'Слово дня с примером и произношением — офлайн',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Логотип студии кружком: даже фото-фон в круге с окантовкой
              // выглядит аккуратно (в идеале — прозрачный PNG от студии).
              FadeTransition(
                opacity: _studioFade,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.surface,
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(
                        alpha: 0.35,
                      ),
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/brand/logo.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
