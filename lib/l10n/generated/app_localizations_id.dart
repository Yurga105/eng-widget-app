// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appTitle => 'Word of Day';

  @override
  String get homeTitle => 'Kata Hari Ini';

  @override
  String get wordTypeWord => 'kata';

  @override
  String get wordTypeIdiom => 'idiom';

  @override
  String get wordTypePhrasalVerb => 'frasa kata kerja';

  @override
  String get listen => 'Dengarkan';

  @override
  String get stopPlayback => 'Hentikan';

  @override
  String get fromWidgetChip => 'dari widget';

  @override
  String get dictionaryError => 'Gagal memuat kamus';

  @override
  String get notificationChannelName => 'Kata Hari Ini';

  @override
  String notificationChannelDescription(DateTime time) {
    final intl.DateFormat timeDateFormat = intl.DateFormat.jm(localeName);
    final String timeString = timeDateFormat.format(time);

    return 'Pemberitahuan kata harian pada pukul $timeString';
  }

  @override
  String notificationTitle(String word) {
    return 'Kata Hari Ini — $word';
  }

  @override
  String notificationBody(String transcription, String translation) {
    return '$transcription — $translation';
  }
}
