// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Word of Day';

  @override
  String get homeTitle => 'Wort des Tages';

  @override
  String get wordTypeWord => 'Wort';

  @override
  String get wordTypeIdiom => 'Idiom';

  @override
  String get wordTypePhrasalVerb => 'Phrasalverb';

  @override
  String get listen => 'Anhören';

  @override
  String get stopPlayback => 'Stoppen';

  @override
  String get fromWidgetChip => 'aus dem Widget';

  @override
  String get dictionaryError => 'Wörterbuch konnte nicht geladen werden';

  @override
  String get notificationChannelName => 'Wort des Tages';

  @override
  String notificationChannelDescription(DateTime time) {
    final intl.DateFormat timeDateFormat = intl.DateFormat.jm(localeName);
    final String timeString = timeDateFormat.format(time);

    return 'Tägliche Benachrichtigung mit dem Wort des Tages um $timeString';
  }

  @override
  String notificationTitle(String word) {
    return 'Wort des Tages — $word';
  }

  @override
  String notificationBody(String transcription, String translation) {
    return '$transcription — $translation';
  }

  @override
  String get wordImageAdd => 'Foto-Assoziation hinzufügen';

  @override
  String get wordImageReplace => 'Foto ändern';

  @override
  String get wordImageRemove => 'Foto entfernen';

  @override
  String get imageSourceTitle => 'Fotoquelle';

  @override
  String get imageSourceCamera => 'Kamera';

  @override
  String get imageSourceGallery => 'Galerie';

  @override
  String get favoritesTitle => 'Favoriten';

  @override
  String get favoritesEmpty =>
      'Noch keine Favoriten — tippe auf den Stern einer Wortkarte, um das Wort zu speichern';

  @override
  String get favoriteAdd => 'Zu Favoriten hinzufügen';

  @override
  String get favoriteRemove => 'Aus Favoriten entfernen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get quizTitle => 'Quiz';

  @override
  String quizProgress(int current, int total) {
    return 'Frage $current von $total';
  }

  @override
  String get quizResultTitle => 'Dein Ergebnis';

  @override
  String quizResultScore(int correct, int total) {
    return '$correct von $total richtig';
  }

  @override
  String get quizRepeatTitle => 'Wörter zum Wiederholen';

  @override
  String get quizRetry => 'Nochmal versuchen';

  @override
  String get quizDone => 'Fertig';

  @override
  String quizNextAt(String date) {
    return 'Nächstes Quiz: $date';
  }

  @override
  String get quizNotEnoughWords =>
      'Noch zu wenig Wörter für ein Quiz — speichere Wörter mit dem Stern';

  @override
  String get quizNotificationChannelName => 'Quiz-Erinnerung';

  @override
  String get quizNotificationChannelDescription =>
      'Erinnerung, gespeicherte Wörter alle 3 Tage zu wiederholen';

  @override
  String get quizNotificationTitle => 'Zeit für ein Quiz!';

  @override
  String get quizNotificationBody =>
      'Prüfe, wie gut du dir die gespeicherten Wörter gemerkt hast';

  @override
  String get shareCard => 'Teilen';

  @override
  String get userExampleSectionTitle => 'Dein Beispiel';

  @override
  String get userExampleAdd => 'Eigenes Beispiel hinzufügen';

  @override
  String get userExampleHint => 'Wo bist du auf dieses Wort gestoßen?';

  @override
  String get userExampleSave => 'Speichern';

  @override
  String get userExampleEdit => 'Beispiel bearbeiten';

  @override
  String get userExampleRemove => 'Beispiel löschen';

  @override
  String get welcomeSkip => 'Überspringen';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get languageSystem => 'Wie das System';

  @override
  String settingsLanguageSystemDetails(String interface, String translations) {
    return 'Oberfläche: $interface · Übersetzungen: $translations';
  }

  @override
  String settingsEnglishTranslations(String language) {
    return 'Wortübersetzungen: $language';
  }

  @override
  String get languagePickTitle => 'Wähle deine Sprache';

  @override
  String get languagePickSubtitle =>
      'Die ganze App — Oberfläche und Wortübersetzungen — verwendet sie';
}
