import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/settings_service.dart';

/// Онбординг-пикер языка (правка приёмки 05.10.2026, идея B-005):
/// показывается один раз при первом запуске, когда системная локаль —
/// английская или неподдержанная (интерфейс ушёл в en-фолбэк):
/// предлагаем выбрать язык приложения, он управляет и интерфейсом, и
/// переводами слов. Первая опция English с подписью «переводы слов:
/// Русский» — английских переводов в словаре нет.
///
/// Выбор обязателен: назад с экрана не выйти ([PopScope]), пока язык
/// не выбран; тап пишет выбор в [SettingsService] и закрывает экран
/// через [onDone] (main.dart пересобирает гейт — под ним уже обычный
/// маршрут). Локализация экрана при показе всегда en (иначе вопрос бы
/// не понадобился), но строки берутся обычным `AppLocalizations`.
class LanguagePickScreen extends StatelessWidget {
  const LanguagePickScreen({
    super.key,
    required this.settings,
    required this.onDone,
  });

  final SettingsService settings;

  /// Выбор сделан — main.dart пересобирает дерево, экран заменяется
  /// обычным маршрутом (карточка дня).
  final VoidCallback onDone;

  Future<void> _choose(String code) async {
    await settings.setAppLanguage(code);
    // Выбран конкретный язык — вопрос «какой язык нужен?» закрыт.
    await settings.markLanguagePromptShown();
    onDone();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return PopScope(
      // Выбор обязателен: без языка не ясно, на каком языке показывать
      // всё остальное — включая экраны «назад».
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.language_rounded,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.languagePickTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    // Страховка вёрстки: длинная строка переносится,
                    // а не тянется от края до края (как в приветствии).
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(
                      l10n.languagePickSubtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: <Widget>[
                        for (final language in kInterfaceLanguages)
                          ListTile(
                            title: Text(language.autonym),
                            subtitle: language.code ==
                                    SettingsService.englishLanguage
                                ? Text(
                                    l10n.settingsEnglishTranslations(
                                      kInterfaceLanguages
                                          .firstWhere(
                                            (l) =>
                                                l.code ==
                                                SettingsService
                                                    .defaultTranslationLanguage,
                                          )
                                          .autonym,
                                    ),
                                    style: theme.textTheme.bodySmall,
                                  )
                                : null,
                            onTap: () => unawaited(_choose(language.code)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}