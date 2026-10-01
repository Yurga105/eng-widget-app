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
  String get cancel => 'Cancel';
}
