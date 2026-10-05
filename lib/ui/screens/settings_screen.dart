import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/settings_service.dart';
import '../widgets/platform_widgets.dart';

/// Экран настроек (этапы 18–19, идея B-005; правка приёмки 05.10.2026):
/// одна секция «Язык» вместо двух — единый язык приложения управляет
/// и интерфейсом, и переводами слов. Опции: «Как в системе» (сброс
/// ручного выбора; подпись показывает, что реально дала бы системная
/// локаль — язык интерфейса и язык переводов) и языки из
/// [kInterfaceLanguages]; у English подпись «переводы слов: Русский» —
/// английских переводов в словаре нет. Название языка не переводится.
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
              builder: (context, selected, _) => Column(
                children: <Widget>[
                  _LanguageTile(
                    title: l10n.languageSystem,
                    subtitle: _systemLanguageDetails(context),
                    selected: selected == SettingsService.systemLanguage,
                    onTap: () => unawaited(
                      settings.setAppLanguage(SettingsService.systemLanguage),
                    ),
                  ),
                  for (final language in kInterfaceLanguages)
                    _LanguageTile(
                      title: language.autonym,
                      // Правка приёмки 05.10.2026: English — опция;
                      // английских переводов в словаре нет, подпись
                      // честно говорит, что переводы останутся русскими.
                      subtitle:
                          language.code == SettingsService.englishLanguage
                              ? l10n.settingsEnglishTranslations(_autonymOf(
                                  SettingsService
                                      .defaultTranslationLanguage))
                              : null,
                      selected: selected == language.code,
                      onTap: () => unawaited(
                        settings.setAppLanguage(language.code),
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

  String _autonymOf(String code) => kInterfaceLanguages
      .firstWhere((language) => language.code == code)
      .autonym;

  /// Что дала бы системная локаль — подпись опции «Как в системе»:
  /// язык интерфейса (аутоним поддержанного или «English»-фолбэк) и
  /// язык переводов (en/неподдержанная → русский дефолт словаря).
  /// По platformDispatcher, а не Localizations: тот уже отражает
  /// ручной выбор; в тестах переопределяется вместе со списком локалей.
  String _systemLanguageDetails(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final system = WidgetsBinding.instance.platformDispatcher.locale;
    final interface = SettingsService.interfaceLanguageForSystemLocale(system);
    final translations = SettingsService.resolveTranslationLanguage(
      SettingsService.systemLanguage,
      system,
    );
    return l10n.settingsLanguageSystemDetails(
      _autonymOf(interface),
      _autonymOf(translations),
    );
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