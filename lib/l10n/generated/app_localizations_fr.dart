// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Word of Day';

  @override
  String get homeTitle => 'Mot du jour';

  @override
  String get wordTypeWord => 'mot';

  @override
  String get wordTypeIdiom => 'expression';

  @override
  String get wordTypePhrasalVerb => 'verbe à particule';

  @override
  String get listen => 'Écouter';

  @override
  String get stopPlayback => 'Arrêter';

  @override
  String get fromWidgetChip => 'depuis le widget';

  @override
  String get dictionaryError => 'Impossible de charger le dictionnaire';

  @override
  String get notificationChannelName => 'Mot du jour';

  @override
  String notificationChannelDescription(DateTime time) {
    final intl.DateFormat timeDateFormat = intl.DateFormat.jm(localeName);
    final String timeString = timeDateFormat.format(time);

    return 'Notification quotidienne avec le mot du jour à $timeString';
  }

  @override
  String notificationTitle(String word) {
    return 'Mot du jour — $word';
  }

  @override
  String notificationBody(String transcription, String translation) {
    return '$transcription — $translation';
  }

  @override
  String get wordImageAdd => 'Ajouter une photo d\'association';

  @override
  String get wordImageReplace => 'Changer la photo';

  @override
  String get wordImageRemove => 'Supprimer la photo';

  @override
  String get imageSourceTitle => 'Source de la photo';

  @override
  String get imageSourceCamera => 'Appareil photo';

  @override
  String get imageSourceGallery => 'Galerie';

  @override
  String get favoritesTitle => 'Favoris';

  @override
  String get favoritesEmpty =>
      'Aucun favori pour l\'instant — appuyez sur l\'étoile d\'une fiche pour enregistrer le mot';

  @override
  String get favoriteAdd => 'Ajouter aux favoris';

  @override
  String get favoriteRemove => 'Retirer des favoris';

  @override
  String get cancel => 'Annuler';

  @override
  String get quizTitle => 'Quiz';

  @override
  String quizProgress(int current, int total) {
    return 'Question $current sur $total';
  }

  @override
  String get quizResultTitle => 'Votre résultat';

  @override
  String quizResultScore(int correct, int total) {
    return '$correct bonnes réponses sur $total';
  }

  @override
  String get quizRepeatTitle => 'Mots à revoir';

  @override
  String get quizRetry => 'Réessayer';

  @override
  String get quizDone => 'Terminé';

  @override
  String quizNextAt(String date) {
    return 'Prochain quiz : $date';
  }

  @override
  String get quizNotEnoughWords =>
      'Pas encore assez de mots pour un quiz — enregistrez des mots avec l\'étoile';

  @override
  String get quizNotificationChannelName => 'Rappel de quiz';

  @override
  String get quizNotificationChannelDescription =>
      'Rappel pour revoir les mots enregistrés tous les 3 jours';

  @override
  String get quizNotificationTitle => 'C\'est l\'heure du quiz !';

  @override
  String get quizNotificationBody =>
      'Voyez à quel point vous vous souvenez de vos mots enregistrés';

  @override
  String get shareCard => 'Partager';

  @override
  String get userExampleSectionTitle => 'Votre exemple';

  @override
  String get userExampleAdd => 'Ajouter votre propre exemple';

  @override
  String get userExampleHint => 'Où avez-vous rencontré ce mot ?';

  @override
  String get userExampleSave => 'Enregistrer';

  @override
  String get userExampleEdit => 'Modifier l\'exemple';

  @override
  String get userExampleRemove => 'Supprimer l\'exemple';

  @override
  String get welcomeSkip => 'Passer';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get languagePickTitle => 'Choisissez votre langue';

  @override
  String get languagePickSubtitle =>
      'Toute l\'application — interface et traductions des mots — l\'utilisera';

  @override
  String get onboardingTitle1 => 'Un nouveau mot chaque jour';

  @override
  String get onboardingBody1 =>
      'Un mot anglais par jour — avec transcription, traduction et exemple. De petits pas, chaque jour.';

  @override
  String get onboardingTitle2 => 'Toujours sous les yeux';

  @override
  String get onboardingBody2 =>
      'Ajoutez le widget à votre écran d\'accueil — le mot du jour est visible sans ouvrir l\'application.';

  @override
  String get onboardingTitle3 => 'Mémoriser durablement';

  @override
  String get onboardingBody3 =>
      'Enregistrez des mots avec l\'étoile, ajoutez des associations photo et révisez-les en quiz tous les 3 jours.';

  @override
  String get onboardingNext => 'Suivant';

  @override
  String get onboardingStart => 'Commencer';
}
