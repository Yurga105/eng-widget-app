// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Word of Day';

  @override
  String get homeTitle => 'Palabra del día';

  @override
  String get wordTypeWord => 'palabra';

  @override
  String get wordTypeIdiom => 'modismo';

  @override
  String get wordTypePhrasalVerb => 'verbo compuesto';

  @override
  String get listen => 'Escuchar';

  @override
  String get stopPlayback => 'Detener';

  @override
  String get fromWidgetChip => 'desde el widget';

  @override
  String get dictionaryError => 'No se pudo cargar el diccionario';

  @override
  String get notificationChannelName => 'Palabra del día';

  @override
  String notificationChannelDescription(DateTime time) {
    final intl.DateFormat timeDateFormat = intl.DateFormat.jm(localeName);
    final String timeString = timeDateFormat.format(time);

    return 'Notificación diaria con la palabra del día a las $timeString';
  }

  @override
  String notificationTitle(String word) {
    return 'Palabra del día — $word';
  }

  @override
  String notificationBody(String transcription, String translation) {
    return '$transcription — $translation';
  }

  @override
  String get wordImageAdd => 'Añadir una foto de asociación';

  @override
  String get wordImageReplace => 'Cambiar foto';

  @override
  String get wordImageRemove => 'Eliminar foto';

  @override
  String get imageSourceTitle => 'Origen de la foto';

  @override
  String get imageSourceCamera => 'Cámara';

  @override
  String get imageSourceGallery => 'Galería';

  @override
  String get favoritesTitle => 'Favoritos';

  @override
  String get favoritesEmpty =>
      'Aún no hay favoritos — toca la estrella en la tarjeta para guardar la palabra';

  @override
  String get favoriteAdd => 'Añadir a favoritos';

  @override
  String get favoriteRemove => 'Quitar de favoritos';

  @override
  String get cancel => 'Cancelar';

  @override
  String get quizTitle => 'Cuestionario';

  @override
  String quizProgress(int current, int total) {
    return 'Pregunta $current de $total';
  }

  @override
  String get quizResultTitle => 'Tu resultado';

  @override
  String quizResultScore(int correct, int total) {
    return '$correct de $total correctas';
  }

  @override
  String get quizRepeatTitle => 'Palabras para repasar';

  @override
  String get quizRetry => 'Intentar de nuevo';

  @override
  String get quizDone => 'Listo';

  @override
  String quizNextAt(String date) {
    return 'Próximo cuestionario: $date';
  }

  @override
  String get quizNotEnoughWords =>
      'Aún no hay palabras suficientes para el cuestionario — guarda palabras con la estrella';

  @override
  String get quizNotificationChannelName => 'Recordatorio del cuestionario';

  @override
  String get quizNotificationChannelDescription =>
      'Recordatorio para repasar las palabras guardadas cada 3 días';

  @override
  String get quizNotificationTitle => '¡Es hora del cuestionario!';

  @override
  String get quizNotificationBody =>
      'Comprueba cuánto recuerdas tus palabras guardadas';

  @override
  String get shareCard => 'Compartir';

  @override
  String get userExampleSectionTitle => 'Tu ejemplo';

  @override
  String get userExampleAdd => 'Añadir tu propio ejemplo';

  @override
  String get userExampleHint => '¿Dónde te encontraste con esta palabra?';

  @override
  String get userExampleSave => 'Guardar';

  @override
  String get userExampleEdit => 'Editar ejemplo';

  @override
  String get userExampleRemove => 'Eliminar ejemplo';

  @override
  String get welcomeSkip => 'Omitir';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get languagePickTitle => 'Elige tu idioma';

  @override
  String get languagePickSubtitle =>
      'Toda la aplicación — interfaz y traducciones de palabras — la usará';

  @override
  String get onboardingTitle1 => 'Una palabra nueva cada día';

  @override
  String get onboardingBody1 =>
      'Una palabra inglesa al día — con transcripción, traducción y ejemplo. Pasos pequeños, cada día.';

  @override
  String get onboardingTitle2 => 'Siempre a la vista';

  @override
  String get onboardingBody2 =>
      'Añade el widget a tu pantalla de inicio: la palabra del día se ve sin abrir la aplicación.';

  @override
  String get onboardingTitle3 => 'Recordar para siempre';

  @override
  String get onboardingBody3 =>
      'Guarda palabras con la estrella, añade asociaciones con fotos y repítelas en un cuestionario cada 3 días.';

  @override
  String get onboardingNext => 'Siguiente';

  @override
  String get onboardingStart => 'Empezar';
}
