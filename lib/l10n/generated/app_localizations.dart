import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
    Locale('ru'),
  ];

  /// App title for the OS (task switcher, Android label)
  ///
  /// In en, this message translates to:
  /// **'Word of Day'**
  String get appTitle;

  /// Home screen AppBar title
  ///
  /// In en, this message translates to:
  /// **'Word of Day'**
  String get homeTitle;

  /// Type badge label for a single word
  ///
  /// In en, this message translates to:
  /// **'word'**
  String get wordTypeWord;

  /// Type badge label for an idiom
  ///
  /// In en, this message translates to:
  /// **'idiom'**
  String get wordTypeIdiom;

  /// Type badge label for a phrasal verb
  ///
  /// In en, this message translates to:
  /// **'phrasal verb'**
  String get wordTypePhrasalVerb;

  /// Tooltip of the TTS play button
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get listen;

  /// Tooltip of the TTS stop button while speaking
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopPlayback;

  /// Amber chip shown when the card was opened from the home-screen widget
  ///
  /// In en, this message translates to:
  /// **'from widget'**
  String get fromWidgetChip;

  /// Error message when the dictionary asset fails to load
  ///
  /// In en, this message translates to:
  /// **'Could not load the dictionary'**
  String get dictionaryError;

  /// Android notification channel name
  ///
  /// In en, this message translates to:
  /// **'Word of Day'**
  String get notificationChannelName;

  /// Android notification channel description; {time} is formatted per locale from NotificationService.notifyHour
  ///
  /// In en, this message translates to:
  /// **'Daily word notification at {time}'**
  String notificationChannelDescription(DateTime time);

  /// Title of the daily notification
  ///
  /// In en, this message translates to:
  /// **'Word of Day — {word}'**
  String notificationTitle(String word);

  /// Body of the daily notification
  ///
  /// In en, this message translates to:
  /// **'{transcription} — {translation}'**
  String notificationBody(String transcription, String translation);

  /// Outlined button to attach a personal photo association to the word of the day (stage 12)
  ///
  /// In en, this message translates to:
  /// **'Add a photo association'**
  String get wordImageAdd;

  /// Tooltip of the replace-photo action under the word image
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get wordImageReplace;

  /// Tooltip of the remove-photo action under the word image
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get wordImageRemove;

  /// Title of the photo source picker (camera or gallery)
  ///
  /// In en, this message translates to:
  /// **'Photo source'**
  String get imageSourceTitle;

  /// Pick the word photo with the device camera
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get imageSourceCamera;

  /// Pick the word photo from the gallery
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get imageSourceGallery;

  /// Favorites screen AppBar title (stage 13)
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favoritesTitle;

  /// Empty state of the favorites list (stage 13)
  ///
  /// In en, this message translates to:
  /// **'No favorite words yet — tap the star on a word card to save it'**
  String get favoritesEmpty;

  /// Tooltip of the outlined star button on a word card (stage 13)
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get favoriteAdd;

  /// Tooltip of the filled amber star button on a word card (stage 13)
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get favoriteRemove;

  /// Generic cancel action (photo source picker)
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
