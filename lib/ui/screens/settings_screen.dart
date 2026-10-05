import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/settings_service.dart';
import '../widgets/platform_widgets.dart';

/// Экран настроек (этап 18, идея B-005): одна секция — язык интерфейса.
/// Опции: «Как в системе» (сброс ручного выбора, подпись показывает,
/// что реально дала бы системная локаль) и языки из
/// [kInterfaceLanguages] — каждый подписан аутонимом («Русский»,
/// «Deutsch»): название языка не переводится.
///
/// Экран не держит состояния: текущий выбор — нотифаер сервиса,
/// тап сразу пишет его через [SettingsService.setInterfaceLanguage];
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
              l10n.settingsInterfaceLanguage,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: ValueListenableBuilder<String?>(
              valueListenable: settings.localeOverride,
              builder: (context, selected, _) => Column(
                children: <Widget>[
                  _LanguageTile(
                    title: l10n.languageSystem,
                    subtitle: _systemLanguageName(context),
                    selected: selected == null,
                    onTap: () =>
                        unawaited(settings.setInterfaceLanguage(null)),
                  ),
                  for (final language in kInterfaceLanguages)
                    _LanguageTile(
                      title: language.autonym,
                      selected: selected == language.code,
                      onTap: () => unawaited(
                        settings.setInterfaceLanguage(language.code),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Что дала бы системная локаль — подпись опции «Как в системе»:
  /// аутоним поддержанного языка («Deutsch») или «English» — фактический
  /// фолбэк локализации для неподдержанных. По platformDispatcher,
  /// а не Localizations: тот уже отражает ручной выбор.
  String _systemLanguageName(BuildContext context) {
    // В проде view.locale == platformDispatcher.locale (одна цепочка);
    // читаем platformDispatcher — в тестах переопределяется вместе со
    // списком локалей.
    final system = WidgetsBinding.instance.platformDispatcher.locale;
    for (final language in kInterfaceLanguages) {
      if (language.code == system.languageCode) {
        return language.autonym;
      }
    }
    return 'English';
  }
}

/// Строка пикера: название языка и галочка у выбранного.
class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
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
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
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