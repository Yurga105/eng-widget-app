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

  @override
  String get wordImageAdd => 'Добавить фото-ассоциацию';

  @override
  String get wordImageReplace => 'Заменить фото';

  @override
  String get wordImageRemove => 'Убрать фото';

  @override
  String get imageSourceTitle => 'Источник фото';

  @override
  String get imageSourceCamera => 'Камера';

  @override
  String get imageSourceGallery => 'Галерея';

  @override
  String get favoritesTitle => 'Избранное';

  @override
  String get favoritesEmpty =>
      'Пока пусто — нажмите звёздочку на карточке слова, чтобы сохранить его';

  @override
  String get favoriteAdd => 'Добавить в избранное';

  @override
  String get favoriteRemove => 'Убрать из избранного';

  @override
  String get cancel => 'Отмена';

  @override
  String get quizTitle => 'Квиз';

  @override
  String quizProgress(int current, int total) {
    return 'Вопрос $current из $total';
  }

  @override
  String get quizResultTitle => 'Ваш результат';

  @override
  String quizResultScore(int correct, int total) {
    return 'Верно: $correct из $total';
  }

  @override
  String get quizRepeatTitle => 'Слова на повторение';

  @override
  String get quizRetry => 'Ещё раз';

  @override
  String get quizDone => 'Готово';

  @override
  String quizNextAt(String date) {
    return 'Следующий квиз: $date';
  }

  @override
  String get quizNotEnoughWords =>
      'Пока мало слов для квиза — сохраняйте их звёздочкой';

  @override
  String get quizNotificationChannelName => 'Напоминание о квизе';

  @override
  String get quizNotificationChannelDescription =>
      'Напоминание повторить сохранённые слова каждые 3 дня';

  @override
  String get quizNotificationTitle => 'Пора пройти квиз!';

  @override
  String get quizNotificationBody =>
      'Проверьте, как запомнились сохранённые слова';

  @override
  String get shareCard => 'Поделиться';

  @override
  String get userExampleSectionTitle => 'Свой пример';

  @override
  String get userExampleAdd => 'Добавить свой пример';

  @override
  String get userExampleHint => 'Где вы встретили это слово?';

  @override
  String get userExampleSave => 'Сохранить';

  @override
  String get userExampleEdit => 'Изменить пример';

  @override
  String get userExampleRemove => 'Удалить пример';

  @override
  String get welcomeSkip => 'Пропустить';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsLanguage => 'Язык';

  @override
  String get languagePickTitle => 'Выберите язык';

  @override
  String get languagePickSubtitle =>
      'Приложение целиком — интерфейс и переводы слов';

  @override
  String get onboardingTitle1 => 'Новое слово каждый день';

  @override
  String get onboardingBody1 =>
      'Одно английское слово в день — с транскрипцией, переводом и примером. Маленькие шаги каждый день.';

  @override
  String get onboardingTitle2 => 'Всегда перед глазами';

  @override
  String get onboardingBody2 =>
      'Добавьте виджет на домашний экран — слово дня видно, даже когда приложение не открыто.';

  @override
  String get onboardingTitle3 => 'Запоминать надолго';

  @override
  String get onboardingBody3 =>
      'Сохраняйте слова звёздочкой, добавляйте фото‑ассоциации и повторяйте их в квизе каждые 3 дня.';

  @override
  String get onboardingNext => 'Далее';

  @override
  String get onboardingStart => 'Начать';
}
