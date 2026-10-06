import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/settings_service.dart';
import '../widgets/platform_widgets.dart';

/// Экран настроек (этапы 18–19, идея B-005; правки приёмки 05.10 и
/// 06.10.2026): одна секция «Язык» — единый язык приложения управляет
/// и интерфейсом, и переводами слов. Опции — 5 языков с переводами в
/// словаре ([kInterfaceLanguages] с `selectable: true`); «как в
/// системе» и English — под капотом, их в списке нет. Галочка стоит
/// у эффективного языка ([SettingsService.effectiveInterfaceLanguage]):
/// режим «как в системе» отмечает язык системной локали, en-фолбэк и
/// легаси-«en» не отмечают ничего — English пользователь не видит.
/// Название языка не переводится.
///
/// Экран не держит состояния: текущий выбор — нотифаер сервиса,
/// тап сразу пишет его через [SettingsService.setAppLanguage];
/// перерисовку опций и всего приложения (включая этот экран) делает
/// слушатель в `main.dart` — смена мгновенная.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});

  final SettingsService settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: PlatformAppBar(title: l10n.settingsTitle),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Text(
              l10n.settingsLanguage,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: ValueListenableBuilder<String>(
              valueListenable: settings.appLanguage,
              // Правка приёмки 06.10.2026: «как в системе» и English —
              // под капотом, в списке только выбираемые языки; галочка —
              // у эффективного языка (system-режим отмечает язык
              // системной локали, en-фолбэк не отмечает ничего).
              builder: (context, _, _) {
                final effective = settings.effectiveInterfaceLanguage;
                return Column(
                  children: <Widget>[
                    for (final language in kInterfaceLanguages)
                      if (language.selectable)
                        _LanguageTile(
                          title: language.autonym,
                          selected: effective == language.code,
                          onTap: () => unawaited(
                            settings.setAppLanguage(language.code),
                          ),
                        ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

}

/// Строка пикера: название языка и галочка у выбранного.
class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: selected
            ? TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              )
            : null,
      ),
      trailing: selected
          ? Icon(
              Icons.check_rounded,
              color: Theme.of(context).colorScheme.primary,
              semanticLabel: title,
            )
          : null,
      onTap: onTap,
    );
  }
}