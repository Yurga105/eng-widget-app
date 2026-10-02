// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Word of Day';

  @override
  String get homeTitle => 'Word of Day';

  @override
  String get wordTypeWord => 'word';

  @override
  String get wordTypeIdiom => 'idiom';

  @override
  String get wordTypePhrasalVerb => 'phrasal verb';

  @override
  String get listen => 'Listen';

  @override
  String get stopPlayback => 'Stop';

  @override
  String get fromWidgetChip => 'from widget';

  @override
  String get dictionaryError => 'Could not load the dictionary';

  @override
  String get notificationChannelName => 'Word of Day';

  @override
  String notificationChannelDescription(DateTime time) {
    final intl.DateFormat timeDateFormat = intl.DateFormat.jm(localeName);
    final String timeString = timeDateFormat.format(time);

    return 'Daily word notification at $timeString';
  }

  @override
  String notificationTitle(String word) {
    return 'Word of Day — $word';
  }

  @override
  String notificationBody(String transcription, String translation) {
    return '$transcription — $translation';
  }

  @override
  String get wordImageAdd => 'Add a photo association';

  @override
  String get wordImageReplace => 'Change photo';

  @override
  String get wordImageRemove => 'Remove photo';

  @override
  String get imageSourceTitle => 'Photo source';

  @override
  String get imageSourceCamera => 'Camera';

  @override
  String get imageSourceGallery => 'Gallery';

  @override
  String get favoritesTitle => 'Favorites';

  @override
  String get favoritesEmpty =>
      'No favorite words yet — tap the star on a word card to save it';

  @override
  String get favoriteAdd => 'Add to favorites';

  @override
  String get favoriteRemove => 'Remove from favorites';

  @override
  String get cancel => 'Cancel';

  @override
  String get quizTitle => 'Quiz';

  @override
  String quizProgress(int current, int total) {
    return 'Question $current of $total';
  }

  @override
  String get quizResultTitle => 'Your result';

  @override
  String quizResultScore(int correct, int total) {
    return '$correct of $total correct';
  }

  @override
  String get quizRepeatTitle => 'Words to repeat';

  @override
  String get quizRetry => 'Try again';

  @override
  String get quizDone => 'Done';

  @override
  String quizNextAt(String date) {
    return 'Next quiz: $date';
  }

  @override
  String get quizNotEnoughWords =>
      'Not enough words for a quiz yet — save words with the star';

  @override
  String get quizNotificationChannelName => 'Quiz reminder';

  @override
  String get quizNotificationChannelDescription =>
      'Reminder to repeat saved words every 3 days';

  @override
  String get quizNotificationTitle => 'Time for a quiz!';

  @override
  String get quizNotificationBody =>
      'Check how well you remember your saved words';
}
