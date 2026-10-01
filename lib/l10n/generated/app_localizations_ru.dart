// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Word of Day';

  @override
  String get homeTitle => 'Слово дня';

  @override
  String get wordTypeWord => 'слово';

  @override
  String get wordTypeIdiom => 'идиома';

  @override
  String get wordTypePhrasalVerb => 'фразовый глагол';

  @override
  String get listen => 'Прослушать';

  @override
  String get stopPlayback => 'Остановить';

  @override
  String get fromWidgetChip => 'из виджета';

  @override
  String get dictionaryError => 'Не удалось загрузить словарь';

  @override
  String get notificationChannelName => 'Слово дня';

  @override
  String notificationChannelDescription(DateTime time) {
    final intl.DateFormat timeDateFormat = intl.DateFormat.jm(localeName);
    final String timeString = timeDateFormat.format(time);

    return 'Ежедневное уведомление со словом дня в $timeString';
  }

  @override
  String notificationTitle(String word) {
    return 'Слово дня — $word';
  }

  @override
  String notificationBody(String transcription, String translation) {
    return '$transcription — $translation';
  }
}
