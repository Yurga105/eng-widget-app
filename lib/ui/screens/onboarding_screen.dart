import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// Онбординг первого запуска (этап 20, идея B-011): три слайда ценности —
/// слово дня, виджет на домашнем экране (ключевой слайд), запоминание
/// (избранное + фото + квиз раз в 3 дня). «Пропустить» ([welcomeSkip])
/// доступна всегда; «Далее» листает вперёд и на последнем слайде
/// превращается в «Начать» ([onStart]) — по ней, а не при старте
/// приложения, запрашивается разрешение на уведомления: системный
/// диалог поверх знакомства отпугивает (решение этапа 20). Завершение
/// ([onDone], и по Skip, и по Start) — main.dart пишет `onboardingShown`
/// и показывает карточку дня; пропустившие получат запрос разрешения
/// при следующем запуске (обычный стартовый прогон).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onStart,
    required this.onDone,
  });

  /// «Начать» на последнем слайде — запросить разрешение на уведомления
  /// и поставить ежедневное расписание.
  final VoidCallback onStart;

  /// Знакомство завершено (Start или Skip) — перейти к карточке дня.
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _slideCount = 3;

  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _page == _slideCount - 1;

  void _next() {
    if (_isLast) {
      widget.onStart();
      widget.onDone();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final titles = <String>[
      l10n.onboardingTitle1,
      l10n.onboardingTitle2,
      l10n.onboardingTitle3,
    ];
    final bodies = <String>[
      l10n.onboardingBody1,
      l10n.onboardingBody2,
      l10n.onboardingBody3,
    ];
    final icons = <IconData>[
      Icons.today_rounded,
      Icons.widgets_rounded,
      Icons.style_rounded,
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: widget.onDone,
                child: Text(l10n.welcomeSkip),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slideCount,
                onPageChanged: (page) => setState(() => _page = page),
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        icons[index],
                        size: 72,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        titles[index],
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        // Страховка вёрстки: длинная строка переносится
                        // по центру (как в приветствии и пикере языка).
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Text(
                          bodies[index],
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (var i = 0; i < _slideCount; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(
                    _isLast ? l10n.onboardingStart : l10n.onboardingNext,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}