# Структура проекта «Слово дня» (eng_widget_app)

> Карта каталогов и файлов: что где лежит, зачем нужно и как части связаны.
> Актуально на 05.10.2026 (состояние после правки приёмки этапа 19 — единый язык приложения; бэклог бизнес-идей `docs/ideas/`).
> Термины и определения — в `docs/KNOWLEDGE_BASE.md`; план и статусы этапов — в `PLAN.md`.

## 1. Вид сверху

```text
eng_widget_app/                 корень репозитория
├─ lib/                         весь Dart-код приложения (Flutter)
│  ├─ main.dart                 входная точка: темы M3 (зелёный seed, light-only), l10n, синк виджета, приём тапов, гейт приветствия (этап 17) + гейт онбординга языка (правка 05.10.2026)
│  ├─ l10n/                     ARB-переводы en/ru/id + generated/ (этап 10)
│  ├─ models/                   модели данных (WordEntry, WordType)
│  ├─ services/                 логика: словарь, формула слова дня, мост к виджету
│  ├─ ui/screens/               экраны приложения
│  └─ ui/widgets/               переиспользуемые виджеты (карточка, бейдж, адаптивные platform-виджеты — этап 11)
├─ assets/
│  ├─ words_db.json             офлайн-словарь: 160 записей (единственный источник данных)
│  └─ brand/                    бренд-ассеты: логотип студии logo.jpg для preload-экрана (этап 17)
├─ android/                     нативная часть: Kotlin (провайдер, калькулятор, boot-ресивер), ресурсы виджета, сборка Gradle
├─ ios/                         каркас iOS (этап 11): Runner (Info.plist, иконка, сплэш), локализации ru/id, SPM без CocoaPods
├─ test/                        тесты (зеркалят структуру lib/)
├─ docs/                        документация: База знаний, QA-чек-лист, политика конфиденциальности стора (store/privacy.html) + этот файл
│  └─ ideas/                    бэклог бизнес-идей v1.1+: README.md (процесс) + BACKLOG.md (идеи)
├─ PLAN.md                      главный план: решения, этапы 0–8, риски, DoD
├─ pubspec.yaml / pubspec.lock  зависимости Flutter и их фиксация
├─ l10n.yaml                    конфиг gen-l10n: ARB, шаблон en, output-dir (этап 10)
├─ analysis_options.yaml        правила линтера (flutter_lints)
└─ README.md                    витрина репозитория: возможности, сборка, ссылки на доки
```

Принцип деления: `lib` — приложение, `android` — платформенная надстройка, `assets` — данные, `test` — зеркало `lib`. Служебные и не-в-git файлы — в разделе 7.

## 2. Поток данных: от JSON до виджета

```text
assets/words_db.json (160 записей, UTF-8)
      │ rootBundle.loadString — DictionaryService (кэш в памяти)
      ▼
   List<WordEntry>
      ▼ WordOfDayService.wordForDate(date)
      │   seed = yyyy*10000 + MM*100 + dd;   index = seed mod 160
      ▼
   WordEntry дня
      ▼ WidgetSyncService.syncForDate(date)
      │   HomeWidget.saveWidgetData ×5 + word_db_json (вся база,
      │   один раз на инстанс сервиса — этап 5)
      │   HomeWidget.updateWidget(androidName: 'WordWidgetProvider')
      ▼
SharedPreferences «HomeWidgetPreferences»
      │ ключи widget.date / widget.word / widget.transcription /
      │       widget.translation / widget.example / word_db_json (контракт)
      ▼
WordWidgetProvider.onUpdate
      │ автономно: WordOfDayCalculator.entryFor(word_db_json, сегодня)
      │ (формула §5; fallback: 5 ключей widget.* → плейсхолдер §9-7)
      ▼
RemoteViews(word_widget.xml)
      ▼
Виджет 4×2 на домашнем экране

Триггеры onUpdate: приложение (updateWidget) · система каждые 30 мин
(updatePeriodMillis — гарантия смены слова после полуночи, §9-2) ·
BootCompletedReceiver сразу после перезагрузки.
```

## 3. Поток управления: тап по виджету → карточка дня

```text
тап по виджету
      │ PendingIntent = HomeWidgetLaunchIntent
      │ uri = wordoftheday://word?date=yyyy-MM-dd
      ├─ холодный старт (процесс убит): MainActivity стартует,
      │    URI читает HomeWidget.initiallyLaunchedFromHomeWidget()
      └─ тёплый старт (singleTop, приложение живо):
           URI приходит стримом HomeWidget.widgetClicked
                     ▼
        main.dart: WidgetSyncService.dateFromWidgetUri(uri)
                     ▼
        ValueNotifier<DateTime?> (дата тапа)
                     ▼
        HomeScreen: WordCard слова этой даты + янтарная метка «из виджета»
```

Оба потока сходятся на контракте «6 ключей + URI» — его части живут в `lib/services/widget_sync_service.dart` и `WordWidgetProvider.kt`, менять только синхронно.

## 4. lib/ — Dart-часть

| Файл | Роль | Зачем существует |
|---|---|---|
| `main.dart` | `main()` + `WordOfTheDayApp` | «Проводка» этапов 4–7: синк слова в виджет при старте, на `resumed` и в полночь (пере-планируемый Timer); подписка на тапы (`initiallyLaunchedFromHomeWidget` + `widgetClicked`) → `ValueNotifier`; этап 7 — старт `NotificationService` (разрешение 1 раз за запуск + расписание), перепланирование на резюме/в полночь, тап по уведомлению (тёплый — колбэк, холодный — payload запуска) → тот же `ValueNotifier`; этап 10 — темы Material 3 (seed — зелёный `#4CAF50`, только светлая: `ThemeMode.light`), `localizationsDelegates` + `supportedLocales` (en/ru/id/de/fr/es), `onGenerateTitle`; этап 17 — гейт preload-экрана приветствия: до резолва стартовых источников (URI виджета + payload уведомления, `catchError`+`whenComplete` — ошибка плагина не держит гейт вечно) `home:` — пустой scaffold на фоне `#F1F8E9`, дееплинк-старт помечается флагом и минует `WelcomeScreen`; этапы 18–19 (правка приёмки 05.10.2026) — `SettingsService` (один на приложение) + `locale:` в MaterialApp от нотифаера `appLanguage` — смена языка мгновенная, `system` = системная локаль; `localeResolutionCallback` — честный en-фолбэк (gen-l10n сортирует supportedLocales, дефолтная резолв давала бы немецкий); `didChangeLocales` — в режиме «как в системе» смена системного языка доспанивает карточку/виджет/уведомление на лету; гейт онбординга языка — `isLoaded && needsLanguagePrompt` → `LanguagePickScreen` после приветствия; слушатель `_onAppLanguageChanged` — setState + re-sync виджета + перепланирование уведомления; этап 20 (B-010) — гейт онбординга знакомства (`isLoaded && !onboardingShown` → `OnboardingScreen` после пикера языка), запрос разрешения на уведомления перенесён из initState в кнопку «Начать» (`_startDailyNotificationAfterOnboarding`; для видевших онбординг — стартовый прогон сразу после загрузки настроек) |
| `models/word_entry.dart` | `WordEntry`, `WordType` | модель записи словаря: `fromJson`/`toJson`, валидация `type`, полное равенство полей — основа тестов |
| `services/dictionary_service.dart` | `DictionaryService` | чтение и парсинг `words_db.json` через `rootBundle` (UTF-8), кэш в памяти; `loadRawJson()` — исходный текст для `word_db_json` (этап 5); загрузчик подменяем в тестах |
| `services/word_of_day_service.dart` | `WordOfDayService` | формула §5 (`seedFor`/`indexFor`) — зеркально в `WordOfDayCalculator.kt` (этап 5); `databaseJson` — исходный JSON для предзагрузки виджета; часы инжектируются (фейк в тестах) |
| `services/widget_sync_service.dart` | `WidgetSyncService`, `HomeWidgetBackend` | мост к виджету: 6 ключей `widget.*` (этап 19: `widget.translation` — уже перевод выбранного языка, `widget.translation_lang` — код для автономного пересчёта Kotlin) + `word_db_json` (база целиком, 1 раз на инстанс — этап 5) + `updateWidget`; `isoDate`/`widgetUri`/`dateFromWidgetUri`; интерфейс бэкенда введён ради тестируемости; этап 11: `iosAppGroupId` — App Group `group.com.english.widget.engWidgetApp` (задел под WidgetKit; бэкенд применяет `setAppGroupId` лениво, 1 раз; на Android игнорируется) |
| `services/notification_service.dart` | `NotificationService`, `FlutterNotificationsBackend` | уведомление этапа 7: канал `word_of_day`, ежедневно в 09:00 (`nextDailyAt` — чистая функция, час — константа `notifyHour`); контент — слово дня ДНЯ срабатывания; payload = URI-контракт виджета; разрешение спрашивается 1 раз за запуск, отказ не блокирует; все вызовы плагина «тихие» (`_quietly`); бэкенд держит `tz.local` (flutter_timezone → `Etc/GMT±` → UTC) и `matchDateTimeComponents: time` — повтор натив сам переставляет и восстанавливает после ребута; этап 10: заголовок/тело/имя и описание канала локализованы (AppLocalizations по локали устройства, каноникализация `in`→`id`); описание канала — `{time}` из `notifyHour` (`DateFormat.jm` по локали, символы дат инициализирует сам сервис); этап 11 (iOS): `DarwinInitializationSettings`/`DarwinNotificationDetails` — баннер+звук без бейджа, разрешение alert/sound через `requestPermissions` (запрос внутри initialize отключён — диалог 1 раз, как на Android) |
| `services/pronunciation_service.dart` | `PronunciationService`, `TtsBackend`, `FlutterTtsBackend` | произношение этапа 9: системный TTS-движок (`flutter_tts`), язык фиксированный `en-US`, `awaitSpeakCompletion(true)`; `isAvailable` — есть ли en-US-голос (нет → кнопки в карточке нет, риск §9-13), `isSpeaking` ValueNotifier — кнопка динамик↔«стоп»; `toggle`/`stop`/`dispose`; ошибки плагина глотаются `_quietly` (паттерн этапа 7) |
| `services/word_image_service.dart` | `WordImageService`, `ImagePickerBackend` | фото-ассоциации этапа 12: камера/галерея через `image_picker` (сжатие maxWidth 1600 / quality 85), хранение `documents/word_images/{id}.jpg` — ключ `id` записи (переживает годовые повторы слова); `imageFor`/`capture`/`remove`; файловый IO синхронный (детерминирован в fake-async тестах), ошибки тихие; `path_provider` даёт documents-каталог (инжектится для тестов) |
| `services/favorite_service.dart` | `FavoriteService`, `Favorite` | избранное этапа 13 (идея B-002): JSON-файл `documents/favorites.json` (запись — `id` словаря + дата добавления, порядок «старые → новые»; синхронный IO и тихие ошибки — паттерн этапа 12); состояние — `ValueNotifier<List<Favorite>>` (звезда карточки и список синхронны); стартовое чтение в конструкторе, `load()` мемоизирован; `isFavorite`/`add`/`remove`/`toggle` |
| `services/quiz_service.dart` | `QuizService`, `QuizQuestion`, `QuizResult` | квиз этапа 14 (идея B-006): файл `documents/quiz_results.json` (история прохождений, `lastResult`-нотифаер, `nextQuizDate` = +3 дня, `isDue` — цикл напоминаний; паттерн этапа 13) + чистая статика `generate` (пул вопросов = избранное с добором из словаря, 4 варианта: верный + дистракторы того же типа, инжектируемый Random; этап 19: `generate(translationLanguage: …)` — варианты и correctIndex на языке переводов, фолбэк записи — русский); колбэк `onQuizFinished` → main.dart перепланирует напоминание; не зависит от словаря/избранного — один экземпляр в `main.dart` передаётся в HomeScreen/QuizScreen |
| `services/card_share_service.dart` | `CardShareService`, `ShareBackend`, `SharePlusBackend` | шеринг карточки этапа 15 (идея B-001): `sharePoster` — рендер постера за правым краем экрана (`OverlayEntry` + `RepaintBoundary`, `endOfFrame`, `toImage` @3x → PNG 1080×1350) → `temp/wordofday_card.png` (sync-IO паттерна этапа 12) → системный share sheet через `share_plus` (`SharePlus.instance.share(ShareParams(...))`; FileProvider мержит плагин, прав нет); `ShareBackend`-паттерн этапа 9 + инъекция `renderer` (движковое `toImage` — реальный async, в fake-async тестах подменяется); тихие ошибки `_quietly`; состояния не держит — экраны создают поле без dispose |
| `services/user_example_service.dart` | `UserExampleService` | свой пример к избранному слову этапа 16 (идея B-003): `documents/user_examples.json` — `id` записи → текст ≤ 300 (`save` тримит и обрезает, пустое = удаление); ключ id — как у фото этапа 12, пример переживает unfavorite/refavorite, схему `favorites.json` не трогаем; состояние `ValueNotifier<Map<int, String>>` + `textFor`/`remove`; паттерн этапа 13 (мемоизированный `load`, синхронный IO, тихие ошибки, `dispose`) |
| `services/settings_service.dart` | `SettingsService`, `kInterfaceLanguages` | единый язык приложения (этапы 18–19, идея B-005; правки приёмки 05.10 и 06.10.2026) — `documents/settings.json` v3: `appLanguage` (`system`|`en|ru|id|de|fr|es`) + флаги онбордингов `languagePromptShown`/`onboardingShown`; паттерн этапа 13 (инжектируемый documents, мемоизированный `load`, синхронный IO, тихие ошибки, `dispose`); состояние — `ValueNotifier<String> appLanguage` + `isLoaded`; миграция v1/v2 при чтении (приоритет выбору интерфейса, затем translationLanguage ≠ ru; онбординги → показанные), запись всегда v3; чистые статики — `interfaceLanguageForSystemLocale` (`in`→`id`, неподдержанная → `en`), `resolveInterfaceLanguage` (system → язык системной локали), `resolveTranslationLanguage` (`en`→`ru` — английских переводов в словаре нет; `system` → язык системной локали, если словарь его переводит, иначе `ru`), `shouldPromptLanguage` (гейт пикера языка); инстанс-геттеры `effectiveInterfaceLanguage`/`effectiveTranslationLanguage`/`needsLanguagePrompt` (по platformDispatcher); `setAppLanguage` / `markLanguagePromptShown` / `markOnboardingShown`; `kInterfaceLanguages` (код + аутоним + флаг `selectable`: en скрыт, выбираемые = 5 кодов словаря) — единственная точка расширения |
| `ui/screens/home_screen.dart` | `HomeScreen` + `formatDate` | экран этапа 6: FutureBuilder → `WordCard` выбранной даты (из тапа по виджету или сегодня); локализованная дата (intl `d MMMM y`, этап 10), maxWidth 600 на планшетах, аккуратный экран ошибки словаря; этап 9: владеет `PronunciationService` (старт в initState, dispose), `ValueListenableBuilder` над `isSpeaking` перерисовывает кнопку прослушивания, `WidgetsBindingObserver` — стоп речи в фоне и при смене даты из тапа по виджету; этап 11: адаптивные `PlatformAppBar`/`PlatformProgressIndicator`/`platformErrorIcon` (`platform_widgets.dart`); этап 12: кэш future-ов «слово+фото» по дате (`_WordCardData`), платформенный пикер источника → `WordImageService.capture`; этап 13: владеет `FavoriteService` (один инстанс на карточку дня, список и карточку избранного слова), звезда в `ValueListenableBuilder` избранного, иконка-звезда в AppBar (`PlatformIconActionButton`) → `FavoritesScreen`; этап 16: владеет `UserExampleService` (один на приложение) → `FavoritesScreen` → `WordDetailScreen` |
| `ui/screens/favorites_screen.dart` | `FavoritesScreen` | список избранного этапа 13: свежие сверху, запись — слово/перевод/дата добавления; тап → `WordDetailScreen`; удаление свайпом (Dismissible) и контекстным меню; пустое состояние — звезда-заглушка + локализованная подсказка; сервисы приходят из `HomeScreen` (состояние общее); этап 19: подзаголовок строки — перевод выбранного языка (параметр `translationLanguage` из HomeScreen) |
| `ui/screens/word_detail_screen.dart` | `WordDetailScreen` | полная карточка избранного слова этапа 13: `WordCard` со всеми секциями (TTS-кнопка, фото-ассоциация) + звезда снятия с избранного; закрывается назад в список; этап 16: под карточкой секция «Свой пример» (`_UserExampleSection` — inline-редактор ≤ 300, добавить/изменить/удалить; `UserExampleService` приходит из HomeScreen); этап 19: карточка, постер и share-текст — на языке переводов из HomeScreen |
| `ui/screens/settings_screen.dart` | `SettingsScreen` | экран настроек (этапы 18–19; правки приёмки 05.10.2026 — одна секция «Язык» вместо двух; 06.10.2026 — «как в системе»/English под капот): 5 выбираемых языков `kInterfaceLanguages` аутонимами без подписей, галочка `Icons.check_rounded` у эффективного языка (`effectiveInterfaceLanguage`: system-режим отмечает язык системной локали, en-фолбэк — ничего); stateless — тап сразу пишет `setAppLanguage`; сервис приходит из HomeScreen (владелец — main.dart) |
| `ui/screens/language_pick_screen.dart` | `LanguagePickScreen` | онбординг-пикер языка (правки приёмки 05.10 и 06.10.2026 — опции те же 5 выбираемых языков, без English): один раз при первом запуске, когда системная локаль en/неподдержанная (`needsLanguagePrompt`), после `WelcomeScreen` (гейт в main.dart); `PopScope(canPop: false)` — выбор обязателен; тап = `setAppLanguage` + `markLanguagePromptShown` + `onDone` (пересборка гейта); при показе локализуется по en (иначе вопрос не понадобился бы) |
| `ui/screens/onboarding_screen.dart` | `OnboardingScreen` | онбординг первого запуска (этап 20, идея B-010): PageView из 3 слайдов ценности — слово дня → виджет (ключевой) → запоминание; точки-индикаторы, «Пропустить» (`welcomeSkip`) всегда, «Далее» → «Начать» на последнем; `onStart` — запрос разрешения на уведомления, `onDone` (Skip/Start) — завершение (main.dart пишет `onboardingShown` и уходит в карточку дня) |
| `ui/screens/quiz_screen.dart` | `QuizScreen` | квиз этапа 14: фазы loading/questions/result/empty; вопрос = слово + бейдж типа + 4 варианта (`FilledButton.tonal`; после ответа верный — primaryContainer с галочкой, выбранная ошибка — errorContainer с крестиком, кнопки блокируются), пауза 900 мс → следующий; результат: счёт, «слова на повторение», дата следующего квиза, «Ещё раз»/«Готово»; `recordResult` пишет историю и дёргает напоминание; вход — иконка в AppBar HomeScreen и тап по напоминанию (`_quizOpenRequest`); этап 19: варианты и «слова на повторение» — на языке переводов из HomeScreen |
| `ui/screens/welcome_screen.dart` | `WelcomeScreen` | preload-экран приветствия этапа 17 (идея B-009): центр — глиф «W.» и бренд «Word of Day» системным serif (правка приёмки: «словарная» серьёзность; `letterSpacing` на бренде) + короткий английский теглайн «A new English word every day» (не переводим, как бренд; без офлайна/произношения; за `ConstrainedBox(maxWidth: 320)` — перенос по центру, не растягивается на весь экран); композиция — на колонке во всю ширину (`SizedBox(width: double.infinity)`, иначе `Column` сжимается по детям и весь центр уезжает влево), низ — логотип студии `assets/brand/logo.jpg` кружком; анимация 2,5 с одним `AnimationController` — растянута с 1,5 с по правке приёмки 05.10.2026 (fade+scale блока, отдельный fade логотипа), доигрывание или тап в любую точку → `onFinished` (в `main.dart` — переключение на карточку дня); зона тапа подписана `Semantics` (`welcomeSkip`, button); логотип за `errorBuilder` — битый/недоступный ассет тихо пуст; показывается только на холодном старте обычного запуска — гейт дееплинков живёт в `main.dart` |
| `ui/widgets/word_card.dart` | `WordCard` | большая M3-карточка (`Card.filled`): Wrap-заголовок (бейдж типа, янтарная метка «из виджета», дата), слово, IPA, перевод, пример + перевод; чистый stateless — данными кормит экран; этап 9: строка слова — `Row` с `Expanded` (длинные фразы переносятся; одиночное слово — всегда одной строкой: длинное жмётся `FittedBox` scaleDown, как у постера — правка приёмки 05.10.2026, репорт «passionate») и опциональной кнопкой-динамиком `onListen`/`isListening` (динамик ↔ «стоп»; `onListen == null` — кнопки нет); этап 11: кнопка — `PlatformIconActionButton` (на iOS `CupertinoButton` + SF-иконка); этап 12: секция фото-ассоциации между транскрипцией и переводом (нет фото — OutlinedButton добавления; есть — картинка 16:10 + адаптивные «заменить»/«убрать», errorBuilder на битый файл); этап 13: звезда избранного в заголовке рядом с динамиком (`isFavorite`/`onToggleFavorite`; контурная ↔ янтарная заливка; null колбэка — звезды нет; iOS — CupertinoButton + SF-иконка, цвет глифа M3 задаётся через `IconButton.color`); этап 15: «поделиться» — крайняя правая кнопка строки (`onShare`, null → кнопки нет); этап 19: `translationLanguage` — перевод и пример через `translationFor`/`exampleTranslationFor` (фолбэк — русские поля v1) |
| `ui/widgets/type_badge.dart` | `TypeBadge` | бейдж типа: «слово»/«идиома»/«фразовый глагол», фиксированные цвета (green 800 `#2E7D32` — этап 10 / янтарь `#FFB300` / teal `#00796B`), подписи локализованы (`labelFor(context, type)`); публичные `labelFor`/`backgroundFor` — для тестов и переиспользования |
| `ui/widgets/share_poster.dart` | `SharePoster` | постер шеринга этапа 15: 360×450 (4:5; @3x → PNG 1080×1350) — бейдж типа, слово (`FittedBox` ужимает длинные фразы), IPA, перевод (`maxLines 4`), бренд «W»+«Word of Day»; цвета — явные константы светлой палитры (не Theme — постер одинаков при любой теме и в тестах); рендерится сервисом `CardShareService` в оверлее за экраном; этап 19: `translationLanguage` — перевод постера на выбранном языке (фолбэк — русский) |
| `ui/widgets/platform_widgets.dart` | адаптивные хелперы (этап 11) | `isAppleStyle` — ветвление по `Theme.of(context).platform` (не dart:io — iOS-ветки тестируются через `ThemeData(platform:)`); `PlatformAppBar` (CupertinoNavigationBar/AppBar), `PlatformProgressIndicator` (CupertinoActivityIndicator/спиннер), `PlatformIconActionButton` (CupertinoButton 44×44/IconButton+tooltip), `platformErrorIcon` |
| `ui/widgets/image_source_sheet.dart` | `showImageSourcePicker` | платформенный выбор источника фото (этап 12): iOS — `CupertinoActionSheet` (HIG), Android — `showModalBottomSheet` (Material); true — камера, false — галерея, null — отмена |
| `l10n/` (ARB + `generated/`) | `AppLocalizations` | локализация этапа 10, с этапа 18 — en/ru/id/de/fr/es: шаблон `app_en.arb`, переводы `app_ru.arb` / `app_id.arb` / `app_de.arb` / `app_fr.arb` / `app_es.arb`; `flutter gen-l10n` (конфиг `l10n.yaml`) генерирует типобезопасные классы в `l10n/generated/` — генерат коммитится; неподержанная локаль → en |

Принцип: модели не знают про UI; вся логика — в сервисах (тестируются без интерфейса); экраны тонкие. Новый код: сервис → `services/`, экран → `ui/screens/`, переиспользуемый виджет UI → `ui/widgets/`.

## 5. test/ — тесты (182 Flutter + 7 Kotlin JVM, все зелёные)

| Файл | Что покрывает |
|---|---|
| `word_entry_test.dart` | модель: заполнение полей, round-trip `toJson`/`fromJson`, маппинг `type` (word / idiom / phrasal_verb), `ArgumentError` на неизвестный тип |
| `dictionary_service_test.dart` | чтение ассета, повторный вызов из кэша, `loadRawJson` (исходный текст и его ошибки), ошибки: битый JSON, отсутствие массива `words` |
| `word_of_day_service_test.dart` | формула: `seed = yyyy*10000 + MM*100 + dd`, фиксированные даты при N=160, зависимость индекса от размера базы, `ArgumentError` при `total <= 0`, смена года перемешивает последовательность (2027-01-01 → id 22) |
| `widget_sync_service_test.dart` (15) | мост на фейк-бэкенде: контракт 7 ключей — 5 полей + `word_db_json` (пишется 1 раз) + `widget.translation_lang` (этап 19, +2 теста: v2-мини-база — перевод выбранного языка в `widget.translation` с фолбэком и код языка в prefs), `isoDate` с ведущими нулями, `widgetUri`/`dateFromWidgetUri` round-trip, отбраковка чужих схем и дат вида «31 февраля» |
| `notification_service_test.dart` (12) | этап 7 на фейк-бэкенде: `nextDailyAt` (граница 09:00 ровно, переходы месяца/года), порядок `start` (initialize → permission → cancel → schedule), контент = слово дня срабатывания (до/после 09:00), payload-URI, отказ разрешения не отменяет расписание, сбои бэкенда глотаются, тап по payload → карточка даты (чужой payload игнорируется), reschedule заменяет расписание, холодный старт payload (успех/сбой) |
| `pronunciation_service_test.dart` (9) | этап 9 на фейк-бэкенде (speak не завершается сам — Completer, имитация awaitSpeakCompletion): `start` → initialize→available(en-US), нет голоса/сбой движка — мягкая деградация (кнопки нет); `speak`/`toggle` во время речи → `stop`; ошибки бэкенда и поздние платформенные колбэки не роняют сервис; `dispose` глушит речь |
| `widget_test.dart` | приложение целиком, 3 `testWidgets`: e2e-сценарии (запуск + слово дня по формуле §5, звезда избранного этапа 13, список, квиз, настройки): мок-хелпер `mockAppChannels()` — `home_widget` ×2 + `path_provider` → temp-папка (`addTearDown`) + предзапись settings.json v3 с флагами онбордингов (правка приёмки 05.10.2026 — гейт пикера языка не перехватывает прежние маршруты; параметр `withSavedLanguageChoice: false` — свежая установка); спиннер карточки и списка снимается циклом `runAsync`+pump; сценарии объединены не случайно — платформенный ответ канала `flutter/assets` живёт только в первом тесте файла (БЗ §15); уведомления/TTS без плагина тихо деградируют; демонтаж приложения в конце; этап 17 — сценарий начинается с гейта приветствия, тап пропускает; правка приёмки 05.10.2026 — настройки: единая секция «Language» из 7 тайлов, тап Deutsch мгновенно даёт немецкий UI; +e2e холодного старта с en-локалью без сохранённого выбора: `WelcomeScreen` → пикер языка → «Русский» → онбординг знакомства (этап 20) → «Пропустить» → русский UI, вопросы не повторяются |
| `welcome_screen_test.dart` (5) | этап 17: первый тест файла — гейт на целом приложении (моки `mockAppChannels` + стартовый URI виджета отдаёт дату → дееплинк: `WelcomeScreen` нет, сразу `HomeScreen`); далее `WelcomeScreen` автономно — бренд и теглайн (en) в дереве с первого кадра, доигрывание 2,5 с зовёт `onFinished` один раз, тап = мгновенный пропуск (+демонтаж до конца анимации безопасен), `Semantics` «Skip» (handle закрыт в теле теста — проверки фреймворка раньше teardown), теглайн ru + бренд не переводим; логотип — через `errorBuilder`: ассет-канал после первого теста молчит (БЗ §15); правка приёмки 05.10.2026: в моках первого теста предзаписан settings.json (флаги онбордингов) — гейт пикера языка не перехватывает дееплинк-маршрут |
| `onboarding_screen_test.dart` (3) | этап 20: слайд 1 — заголовок, Skip и «Next» на месте, колбэки молчат; «Next» листает до слайда 3, превращается в «Get started» (листание само не завершает), тап → `onStart` + `onDone`; Skip → только `onDone` (разрешение на уведомления попросят при следующем запуске) |
| `word_card_test.dart` (23) | UI этапа 6: все поля карточки + дата и бейдж, тёмная тема, метка «из виджета» только при открытии с виджета, бейджи трёх типов (подпись + цвет), влезание карточки с фразовым глаголом на экран 320×480; этап 19 (+1): перевод и пример на de/es, фолбэк fr → русские поля v1; правка приёмки 05.10.2026 (+2): «passionate» — одна строка на 320×480 с тремя кнопками (отрисованная ширина после scaleDown не шире строки), самая длинная идиома БД (29 симв.) переносится ≥2 строками, а не жмётся; этап 9 (+4): тап по динамику зовёт `onListen`, кнопки нет при `onListen == null` (TTS недоступен), иконка «стоп» во время речи, влезание 320×480 проверено с кнопкой; этап 10 — ожидания переведены на en (делегаты l10n в пумпе, подписи бейджей из AppLocalizations); этап 11 (+1): на iOS кнопка прослушивания — `CupertinoButton` с SF-иконкой (платформа темы — параметр пумпа); этап 12 (+4): кнопка добавления фото без фото, фото + «заменить»/«убрать» (`ensureVisible` — карточка выше экрана), битый путь файла — errorBuilder без падения (реальный 1×1 PNG и createTempSync: async-IO в fake-async виснет); этап 13 (+3): звезда — нет колбэка → нет звезды, переключение контур ↔ залитая янтарная (цвет через `IconButton.color` — M3 красит глиф сам, не IconTheme) с вызовом колбэка, на iOS — CupertinoButton со SF-иконкой; этап 15 (+3): «поделиться» — нет колбэка → нет кнопки, тултип («Share») и тап зовут колбэк, на iOS — SF-иконка (отдельный тест: смена платформы темы между pumpWidget не подхватывается — БЗ/platform_widgets_test) |
| `card_share_service_test.dart` (5) | этап 15: unit — `sharePngBytes` пишет байты в temp-файл и бэкенд получает путь+текст; постер — бейдж/слово/IPA/перевод/бренд на месте и длинный фразовый глагол не переполняет макет (`FittedBox`); полный пайплайн на фейк-рендерере (движковое `toImage` — реальный async, в fake-async виснет) — билдер вызван, файл записан, бэкенд получил путь; растеризация `renderPosterPng` отдельно через `tester.runAsync` — настоящий PNG (подпись 89 50 4E 47, > 1000 байт) |
| `platform_widgets_test.dart` (6) | этап 11: iOS — навбар/индикатор/кнопка Cupertino и Material-иконки не дублируются; Android — AppBar/спиннер/IconButton c tooltip; тап срабатывает на обеих; `platformErrorIcon` по платформе (каждая платформа — свой тест: смена платформы темы между pumpWidget в одном тесте не подхватывается переиспользуемым элементом) |
| `word_image_service_test.dart` (9) | этап 12 на фейк-пикере + временном каталоге: копия в `word_images/{id}.jpg` с удалением кэша, источник передаётся как есть, отмена → null без файлов, сбой плагина → тихий null, `imageFor` до/после, `remove` (повтор — не ошибка), замена перезаписывает тот же путь, ключ — id записи (разные записи → разные файлы), недоступное хранилище → тихий null |
| `image_source_sheet_test.dart` (2) | этап 12: Android — bottom sheet (камера true, галерея false, тап мимо — null); iOS — CupertinoActionSheet (те же + кнопка Cancel) |
| `favorite_service_test.dart` (9) | этап 13 на временном каталоге: стартовое чтение при создании, пустой/отсутствующий файл → пусто, битый JSON → тихо пусто, add/remove/toggle меняют список (порядок «старые → новые», дубли no-op), мутации пишут файл (round-trip), повторный `load` ждёт тот же future, `dispose` гасит нотифаер |
| `favorites_screen_test.dart` (5) | этап 13: пустое избранное — звезда-заглушка и подсказка; список свежими сверху (слово/перевод/дата); свайп удаляет запись; тап открывает `WordDetailScreen` с полной карточкой; на iOS — CupertinoActivityIndicator (wait-цикл обоих индикаторов) |
| `user_example_service_test.dart` (11) | этап 16 на временном каталоге: пустой load без файла (файл не создаётся), save тримит и обрезает до 300, пустой текст = удаление, remove отсутствующего — no-op, нотифаер оповещает слушателей, round-trip в новый экземпляр сервиса, файл независим от `favorites.json`, битый JSON → тихо пусто, мусорные элементы/дубли id фильтруются, сбой documents → мутации не роняют |
| `word_detail_screen_test.dart` (6) | этап 16, секция «Свой пример» в карточке избранного: без примера — заголовок и кнопка добавления; ввод и «Сохранить» пишут файл; «Отмена» не сохраняет; редактирование открывается со старым текстом; удаление возвращает кнопку; стартовое чтение файла показывает пример сразу |

Тесты зеркалят `lib/`: новый файл в `lib/` → парный в `test/` с суффиксом `_test`.

Нативные JVM-тесты: `android/app/src/test/kotlin/…/WordOfDayCalculatorTest.kt` — 7 тестов формулы §5 и `entryFor` на ОБЩИХ тест-векторах с Dart (риск §9-4). Запуск: `cd android; gradlew :app:testDebugUnitTest` (нужен JAVA_HOME → JBR Android Studio, см. Базу знаний §11).

## 6. android/ — нативная часть

```text
android/
├─ build.gradle.kts / settings.gradle.kts / gradle.properties   обвязка сборки (Kotlin DSL)
├─ gradle/wrapper/ + gradlew(.bat)                              Gradle Wrapper — фиксированная версия сборщика
├─ local.properties          локальные пути SDK — НЕ в git
├─ .gradle/                  локальный кэш Gradle — НЕ в git
└─ app/
   ├─ build.gradle.kts       id com.english.widget.eng_widget_app; core library desugaring
   │                         (требование flutter_local_notifications); junit + org.json
   │                         для JVM-тестов (testImplementation, этап 5); релиз — подпись
   │                         upload-ключом через android/key.properties (keystore вне репо;
   │                         без файла release-сборка роняется гардом — план публикации
   │                         в Google Play, фаза 0, 29.10.2026)
   └─ src/
      ├─ main/               основная конфигурация и код (таблица ниже)
      ├─ test/kotlin/…       JVM-тесты нативной логики (WordOfDayCalculatorTest, этап 5)
      ├─ debug/ + profile/   технические манифесты-оверлеи Flutter
      └─ java/.../GeneratedPluginRegistrant.java   генерируется Flutter, не редактировать
```

`app/src/main/`:

| Путь | Роль |
|---|---|
| `AndroidManifest.xml` | `MainActivity` (`singleTop`, лаунчер) + `<receiver .WordWidgetProvider>` (`exported="false"`, `APPWIDGET_UPDATE`, meta-data → `word_widget_info`) + `<receiver .BootCompletedReceiver>` (`BOOT_COMPLETED`, этап 5); право `RECEIVE_BOOT_COMPLETED`; `<queries>`: `PROCESS_TEXT` + `TTS_SERVICE` (этап 9 — видимость TTS-движка на Android 11+, не право); сетевых прав нет |
| `kotlin/.../MainActivity.kt` | пустая `FlutterActivity` — точка входа, сюда доезжают интенты тапа |
| `kotlin/.../WordWidgetProvider.kt` | провайдер виджета (этап 5): `word_db_json` → `WordOfDayCalculator` → `RemoteViews`; fallback: 5 ключей `widget.*` → плейсхолдер (§9-7); тап → URI показанной даты |
| `kotlin/.../WordOfDayCalculator.kt` | чистая формула §5 + парсинг `word_db_json` (`org.json`) — паритет с Dart, JVM-тестируется без Android |
| `kotlin/.../BootCompletedReceiver.kt` | после BOOT_COMPLETED просит систему вызвать `onUpdate` провайдера (§9-2); приложение не запускается |
| `res/layout/word_widget.xml` | RemoteViews-макет 4×2: слово (20sp) → транскрипция (12sp) → перевод (14sp) → пример (12sp, до 2 строк), фон `widget_bg` |
| `res/xml/word_widget_info.xml` | дескриптор виджета: `targetCell 4×2` (API 31+), `minWidth/Height 250×110dp`, `updatePeriodMillis` 30 мин, `resizeMode=none`; превью: `previewImage` (PNG для лаунчеров API<31) + `previewLayout` (живой макет, API 31+) |
| `res/values/strings.xml` | default-локаль en (этап 10): `app_name` «Word of Day» (бренд), имя/описание виджета, заглушки-превью (запись №1; перевод записи русский до schema v2), плейсхолдер; переводы — `values-ru/`, `values-id/` (legacy-код «in» на «id» маппит сам Android) |
| `res/values/widget_colors.xml` + `res/values-night/widget_colors.xml` | палитры виджета: светлая — зелёная (этап 10; фон `#F1F8E9` = scaffold приложения), ночная — тёмно-зелёная; менять только парой; `launch_bg_color` — фон сплэша (светлый и в ночной теме — приложение light-only) |
| `res/values/styles.xml` + `res/values-night/styles.xml` | темы окна и сплэша; с этапа 10 ночная тоже светлая (`launch_bg_color`) — приложение light-only |
| `res/values/ic_launcher_colors.xml` | фон адаптивной иконки — зелёный green 500 `#4CAF50` (этап 10) |
| `res/drawable/widget_bg.xml` | скруглённый фон виджета (16dp) |
| `res/drawable/ic_launcher_foreground.xml` | вектор-глиф «W.» иконки (safe zone 108dp) |
| `res/drawable/ic_stat_word.xml` | alpha-only вектор 24dp для строки уведомления: белая «W.» с янтарной точкой; `defaultIcon` в `notification_service.dart` (этап 8) |
| `res/drawable-nodpi/widget_preview.png` | PNG-превью виджета 480×220 для лаунчеров API<31: карточка записи №1 («accomplish»); `nodpi` — не масштабируется по плотности (этап 8) |
| `res/mipmap-anydpi-v26/ic_launcher.xml` | адаптивная иконка API 26+ (фон + глиф) |
| `res/mipmap-*/ic_launcher.png` | растровые иконки для API<26 (этап 8): 48/72/96/144/192 px в mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi — скруглённый зелёный квадрат с глифом «W.» (перегенерированы этапом 10) |

## 7. ios/ — каркас iOS (этап 11)

Сгенерирован `flutter create --platforms=ios --org com.english.widget .` (bundle id `com.english.widget.engWidgetApp`), минимальная iOS — 15.0. Сборки на Windows нет: валидация статическая (analyze/test зелёные, SPM-резолв зависимостей), ручная приёмка — на Mac (`docs/QA_CHECKLIST.md` §10).

| Путь | Что это |
|---|---|
| `Runner/Info.plist` | `CFBundleDisplayName` «Word of Day»; `CFBundleLocalizations` en/ru/id; URI-схема `wordoftheday` (`CFBundleURLTypes`) — тот же контракт, что у Android-виджета (открытие карточки дня); этап 12: `NSCameraUsageDescription`/`NSPhotoLibraryUsageDescription` (обязательны для image_picker на iOS) |
| `Runner/ru.lproj/InfoPlist.strings` + `id.lproj/` | имя под иконкой: «Слово дня» / «Kata Hari Ini» (en — из самого Info.plist); этап 12: локализованные usage-описания камеры/фотобиблиотеки |
| `Runner/Base.lproj/LaunchScreen.storyboard` | сплэш — заливка `#F1F8E9` (тот же `launch_bg_color`, что на Android), без лого — паритет платформ |
| `Runner/Assets.xcassets/AppIcon.appiconset/` | single-size иконка 1024×1024 (Xcode 14+ деривирует все размеры сам): зелёный квадрат `#4CAF50`, белый «W.» + янтарная точка — тот же глиф, что в Android-иконке (перерисован GDI+ по координатам вектора `ic_launcher_foreground.xml`) |
| `Runner/AppDelegate.swift` / `SceneDelegate.swift` | шаблонный Swift-каркас (сценический жизненный цикл UIKit), регистрация плагинов — в `GeneratedPluginRegistrant` |
| `Runner.xcodeproj` / `Runner.xcworkspace` | проект Xcode; App Group `group.com.english.widget.engWidgetApp` включается вручную в Signing & Capabilities (задел под WidgetKit) |
| Podfile отсутствует | новый шаблон Flutter использует Swift Package Manager: `Flutter/ephemeral/` генерирует `FlutterGeneratedPluginSwiftPackage`, все 4 плагина подтягиваются без CocoaPods |

Собственного нативного кода нет: платформенные отличия живут в Dart — Darwin-ветки `notification_service.dart`, App Group в `widget_sync_service.dart`, адаптивный UI в `platform_widgets.dart`. `flutter_tts`/`flutter_timezone` на iOS работают без правок (AVSpeechSynthesizer имеет en-US-голос; часовой пояс — система). Виджета на iOS в v1.0 нет — WidgetKit-расширение требует Mac/Xcode (v1.1).

## 8. Корень и служебные файлы

| Путь | Что это |
|---|---|
| `PLAN.md` | главный план: решения §1, стек §2, структура §3, данные §4, формула §5, нативная логика §6, уведомления §7, этапы и статусы §8, риски §9, DoD §10 |
| `docs/KNOWLEDGE_BASE.md` | словарь терминов проекта |
| `docs/PROJECT_STRUCTURE.md` | этот документ |
| `docs/QA_CHECKLIST.md` | ручной чек-лист приёмки (этапы 8–11): матрица лаунчеров, ребут, темы, уведомления, иконки и превью, релизный APK, произношение, локализация/редизайн, iOS |
| `docs/ideas/README.md` | процесс ведения бэклога бизнес-идей: категории, статусы, шаблон карточки, путь идеи до этапа PLAN.md §8 (заведено 02.10.2026) |
| `docs/ideas/BACKLOG.md` | сам бэклог: сводная таблица + карточки идей; источник этапов 13+ / v1.1 |
| `README.md` | витрина репозитория (GitHub): возможности, устройство, сборка/запуск/тесты, ссылки на доки; обновляйте при заметных изменениях |
| `pubspec.yaml` | зависимости (`home_widget 0.10.0`, `flutter_local_notifications 22.3.1`, `timezone` + `flutter_timezone` — этап 7, `flutter_tts 4.2.5` — этап 9, `flutter_localizations` (sdk) + `intl` — этап 10, `image_picker 1.2.3` + `path_provider 2.1.6` — этап 12), ассеты `words_db.json` + `assets/brand/` (логотип студии, этап 17), версия SDK, `generate: true` (gen-l10n) |
| `pubspec.lock` | точная фиксация версий пакетов — коммитить |
| `l10n.yaml` | конфиг `flutter gen-l10n` (этап 10): ARB-каталог `lib/l10n`, шаблон en, явный `output-dir` в `lib/l10n/generated` |
| `analysis_options.yaml` | включение flutter_lints (`flutter create` этапа 11 добавил исключения `build/` и платформенных каталогов) |
| `.gitignore` | исключения из git: `build/`, `.dart_tool/`, `local.properties` и т.п. |
| `.metadata`, `*.iml`, `.flutter-plugins-dependencies` | служебные файлы Flutter/IDE — руками не редактируются |

## 9. Куда класть новый код

| Добавляю | Куда | Пример |
|---|---|---|
| логика/сервис | `lib/services/` + тест в `test/` | `notification_service.dart` (этап 7) |
| экран | `lib/ui/screens/` | — |
| переиспользуемый виджет UI | `lib/ui/widgets/` | `word_card.dart`, `type_badge.dart` (этап 6) |
| строка UI (л10н) | `lib/l10n/app_*.arb` + перегенерация `flutter gen-l10n` | `app_en.arb` (шаблон) + `app_ru.arb` / `app_id.arb` (этап 10) |
| модель данных | `lib/models/` | — |
| строка виджета (нативная) | `android/.../res/values/strings.xml` | плейсхолдеры этапа 4 |
| цвет виджета | `values/widget_colors.xml` + `values-night/widget_colors.xml` (пара!) | — |
| ключ контракта Flutter↔Kotlin | `widget_sync_service.dart` + `WordWidgetProvider.kt` синхронно | 6 ключей: `widget.*` + `word_db_json`; URI тапа `wordoftheday://word?date=…` общий для виджета и уведомления (парсер `dateFromWidgetUri`) |
| чистая нативная логика | object в `kotlin/…/` + JVM-тест в `android/app/src/test/kotlin/` | `WordOfDayCalculator.kt` (этап 5) |
| платформенная ветка UI | `lib/ui/widgets/platform_widgets.dart` (по `Theme.of(context).platform`, не dart:io) | Cupertino/Material-кнопки (этап 11) |

## 10. Что появится по плану

- **Этап 5** ✅ выполнен (27.09.2026) — ключ `word_db_json` в prefs, `WordOfDayCalculator.kt` (org.json) и автономный `onUpdate` с fallback-цепочкой, `BootCompletedReceiver` + право `RECEIVE_BOOT_COMPLETED` в манифесте. Полуночный будильник НЕ потребовался: гарантию смены слова даёт `updatePeriodMillis` 30 мин (PLAN.md §6, риски §9-2/§9-6).
- **Этап 6** ✅ выполнен (27.09.2026) — `WordCard` (`Card.filled`) + `TypeBadge` (индиго/янтарь/teal, фиксированы в обеих темах) + полноценный `HomeScreen` (`formatDateRu` без intl, maxWidth 600, экран ошибки словаря); янтарный акцент палитры §1 — бейдж идиомы и метка «из виджета»; +5 тестов (flutter test 44/44), analyze чисто, debug-APK собирается. Ручная приёмка на устройстве — за пользователем.
- **Этап 7** ✅ выполнен (27.09.2026) — `services/notification_service.dart`: канал `word_of_day`, ежедневно 09:00 (`inexactAllowWhileIdle`, `matchDateTimeComponents: time` — повтор натив переставляет сам), контент = слово дня дня срабатывания, payload = URI-контракт виджета (тап → карточка того же дня), `POST_NOTIFICATIONS` 1 раз за запуск с мягкой деградацией; манифест: `POST_NOTIFICATIONS` + 2 receiver'а плагина; пакеты `timezone` + `flutter_timezone`; +12 тестов (flutter test 56/56), analyze чисто, debug-APK собирается. Ручная приёмка (приход в 09:00, тап, отказ в разрешении) — за пользователем.
- **Этап 8** ✅ выполнен (28.09.2026) — PNG-иконки лаунчера `mipmap-{mdpi…xxxhdpi}/ic_launcher.png` (5 плотностей, 48–192 px), PNG-превью виджета `drawable-nodpi/widget_preview.png` + `previewImage` в дескрипторе, alpha-only иконка уведомлений `drawable/ic_stat_word.xml`; analyze чисто, flutter test 56/56, релизный APK собирается. Ручная матрица QA — `docs/QA_CHECKLIST.md`, приёмка — за пользователем.
- **Этап 9** ✅ выполнен (28.09.2026) — `services/pronunciation_service.dart` (`TtsBackend`/`FlutterTtsBackend` + `PronunciationService`, мягкая деградация `_quietly`), кнопка-динамик в `WordCard` (`onListen`/`isListening`, null → кнопки нет), проводка в `HomeScreen` (`ValueListenableBuilder` + `WidgetsBindingObserver`: фон/смена даты → стоп речи), `<queries>` `TTS_SERVICE` в манифесте (Android 11+); пакет `flutter_tts ^4.2.5`; +13 тестов (flutter test 69/69), analyze чисто; релизный APK 45.4 МБ, `aapt dump permissions` — новых прав нет, `INTERNET` нет; установлен на RMX2001. Ручная приёмка (звук en-US, скорость, стоп тапом/фоном) — за пользователем.
- **Этап 10** ✅ выполнен (01.10.2026) — локализация en/ru/id (first-party стек `flutter_localizations` + `intl`; ARB `lib/l10n/app_*.arb`, генерация `flutter gen-l10n` по `l10n.yaml` в `l10n/generated/` — коммитится; неподержанная локаль → en) + редизайн (seed зелёный `#4CAF50`, приложение light-only, светлый сплэш и в ночной теме — `launch_bg_color`, зелёные иконки: вектор + перегенерированные PNG) + бренд «Word of Day» (`app_name`, `onGenerateTitle`); нативные строки локализованы (`values-ru/`, `values-id/`: имя/описание виджета, плейсхолдер); уведомления: тексты и имя/описание канала по локали устройства (`in`→`id`); тесты переведены на en-ожидания (flutter test 69/69, количество сохранено), analyze чисто. Ручная приёмка (языки, ночная тема, канал в настройках ОС) — `docs/QA_CHECKLIST.md` §9, за пользователем.
- **Этап 11** ✅ выполнен (01.10.2026) — iOS-каркас `flutter create --platforms=ios` (bundle id `com.english.widget.engWidgetApp`, iOS 15+, SPM без Podfile): `Info.plist` («Word of Day», `CFBundleLocalizations`, URI-схема `wordoftheday`), `InfoPlist.strings` ru/id, сплэш `#F1F8E9`, single-size иконка 1024 (глиф «W.» идентичен Android); Darwin-ветки уведомлений (разрешение alert/sound отдельным вызовом, баннер+звук без бейджа); `iosAppGroupId` в `PluginHomeWidgetBackend` (задел WidgetKit); `lib/ui/widgets/platform_widgets.dart` + рефакторинг home_screen/word_card (навбар/индикатор/кнопка/иконка ошибки); +7 тестов (76/76), analyze чисто. Виджета на iOS нет (WidgetKit — v1.1, нужен Mac/Xcode); сборка и ручная приёмка — на Mac, QA §10.
- **Этап 12** ✅ выполнен (01.10.2026) — фото-ассоциации к словам: `image_picker ^1.2.3` + `path_provider ^2.1.6`; `services/word_image_service.dart` (бэкенд-паттерн, `documents/word_images/{id}.jpg`, тихие ошибки, синхронный IO для fake-async); `ui/widgets/image_source_sheet.dart` (CupertinoActionSheet ↔ bottom sheet); секция фото в `WordCard` (16:10, адаптивные «заменить»/«убрать», errorBuilder); `HomeScreen` — кэш future-ов «слово+фото»; ARB +7 строк en/ru/id; iOS usage-описания (+ `InfoPlist.strings` ru/id); Android — ноль новых прав (без `CAMERA`, системные intents); +15 тестов (91/91), analyze чисто. Ручная приёмка — QA §11 (Android) / §10 (iOS).
- **Этап 13** ✅ выполнен (02.10.2026, идея B-002) — избранное: `services/favorite_service.dart` (`documents/favorites.json`, id записи + дата добавления, `ValueNotifier` — синхронная звезда и список, тихие ошибки, синхронный IO паттерна этапа 12); `ui/screens/favorites_screen.dart` (свежие сверху, свайп-удаление + контекстное меню, пустое состояние) + `ui/screens/word_detail_screen.dart` (полная карточка избранного слова: TTS, фото, снятие звезды); звезда в `WordCard` (контур ↔ янтарная заливка; iOS — CupertinoButton+SF, цвет M3 через `IconButton.color`); вход — иконка в AppBar; ARB +4 ключа en/ru/id; +16 тестов (9 сервис + 5 список + 2 звезда) — 107/107, analyze чисто; сценарии приложения объединены в один `testWidgets` (урок о `flutter/assets` — БЗ §15); ноль новых зависимостей/прав. Ручная приёмка — QA §12 (Android) / iOS по аналогии.
- **Этап 14** ✅ выполнен (02.10.2026, идея B-006) — квиз-повторение каждые 3 дня: `services/quiz_service.dart` (`quiz_results.json` — история, `nextQuizDate`/`isDue`, `onQuizFinished`; статическая `generate`: избранное + добор из словаря, дистракторы того же типа, Random инжектируемый); `ui/screens/quiz_screen.dart` (подсветка ответа, пауза 900 мс, результат со «словами на повторение» и датой следующего квиза, «Ещё раз»); напоминание: `scheduleOneShot` (одноразовый `zonedSchedule`) на +3 дня в 10:00, канал `quiz`, payload `wordoftheday://quiz` → `_quizOpenRequest` → QuizScreen; триггеры перепланирования старт/резюм/полночь/`onQuizFinished`; ARB +15 ключей en/ru/id; +25 тестов (12 сервис + 7 экран + 6 напоминание) — 132/132, analyze чисто; ноль новых зависимостей/прав. Ручная приёмка — QA §13 (Android) / iOS по аналогии.
- **Этап 15** ✅ выполнен (03.10.2026, идея B-001) — шеринг карточки картинкой: `services/card_share_service.dart` (`ShareBackend`/`SharePlusBackend` паттерна этапа 9; `share_plus ^13.3.1` — `SharePlus.instance.share(ShareParams(files+text))`, решение владельца; рендер постера в оверлее за экраном → `RepaintBoundary.toImage` @3x → PNG 1080×1350 → `temp/wordofday_card.png` (sync-IO паттерна этапа 12); инъекция `renderer` — движковое `toImage` реальный async; тихие ошибки) + `ui/widgets/share_poster.dart` (360×450 4:5, бренд «Word of Day», константные цвета светлой палитры, `FittedBox`); кнопка `onShare` в `WordCard` (крайняя правая, `PlatformIconActionButton`), проводка в HomeScreen/WordDetailScreen; ARB +`shareCard` en/ru/id; +8 тестов (5 сервис + 3 кнопка) — 140/140, analyze чист; релизный APK 49.4 МБ, `aapt dump permissions` — прав не изменилось, `INTERNET` нет (FileProvider `ShareFileProvider` мержится плагином без прав). Ручная приёмка — QA §14 (Android) / iOS по аналогии.
- **Этап 16** ✅ выполнен (03.10.2026, идея B-003) — свой пример к избранному слову: `services/user_example_service.dart` (`documents/user_examples.json`: `id` записи → текст ≤ 300, `ValueNotifier<Map<int, String>>`; `save` тримит/обрезает, пустое = удаление; паттерн этапа 13 — тихие ошибки, синхронный IO, мемоизированный `load`; ключ id — пример переживает unfavorite/refavorite, как фото этапа 12, схему `favorites.json` не трогаем); секция `_UserExampleSection` в `word_detail_screen.dart` (`Card.filled` одним стеком с карточкой: без примера — кнопка добавления, с примером — текст + «изменить»/«удалить» `PlatformIconActionButton`; inline `TextField` maxLength 300 + «Сохранить»/«Отмена», пустой ввод = удаление); сервисом владеет HomeScreen → FavoritesScreen → WordDetailScreen (как FavoriteService); карточка дня и виджет не меняются (контракт §6); ARB +6 ключей en/ru/id; +17 тестов (11 сервис + 6 секция) — 157/157, analyze чист; ноль новых зависимостей/прав. Ручная приёмка — QA §15 (Android) / iOS по аналогии.
- **Этап 17** ✅ выполнен (03.10.2026, идея B-009) — preload-экран приветствия при открытии приложения: `ui/screens/welcome_screen.dart` (глиф «W.», бренд «Word of Day», теглайн, логотип студии `assets/brand/logo.jpg` за `errorBuilder`; анимация 2,5 с одним `AnimationController` (растянута с 1,5 с по правке приёмки 05.10.2026); тап = мгновенный пропуск, зона подписана `Semantics` `welcomeSkip`); правки по итогам ручной приёмки: глиф и бренд — системный serif, теглайн всегда английский и без «— офлайн» (ключ `welcomeTagline` удалён из ARB — остался +1 ключ `welcomeSkip`); гейт первого кадра в `main.dart`: до резолва стартовых источников (URI виджета + payload уведомления; `catchError`+`whenComplete` — ошибка плагина не держит гейт) — пустой scaffold на фоне `#F1F8E9` (бесшовная стыковка с нативным сплэшем), дееплинк-старт (виджет/уведомление/квиз) — без приветствия сразу карточка/квиз, обычный запуск — всегда (решение триажа, без счётчика запусков); +5 тестов (1 гейт на приложении + 4 экран) — 162/162, analyze чист; релизный APK 52.4 МБ, `aapt dump permissions` — состав прав не изменился, `INTERNET` нет; ноль новых зависимостей и прав (ассет студии лёг раньше — коммиты 3fd4f41/2fbc420). Ручная приёмка — QA §16 (Android) / iOS по аналогии.
- **Этап 18** ✅ выполнен (05.10.2026, идея B-005 часть 1) — выбор языка интерфейса: `services/settings_service.dart` (`documents/settings.json` v1, `interfaceLanguage`: system|ru|id|de|fr|es; `ValueNotifier` + единая валидация чтения/записи, паттерн этапа 13) + `ui/screens/settings_screen.dart` («Как в системе» с подписью системного фолбэка + 5 языков аутонимами из `kInterfaceLanguages`, галочка; шестерёнка — крайняя справа в AppBar) + проводка `main.dart` (`MaterialApp.locale` от нотифаера — смена мгновенная; null = системная резолв); en из пикера исключён — template-фолбэк (неподдержанная системная → en); ARB +3 ключа ×6 локалей — файлы `app_de/-fr/-es.arb` новые (48 ключей); нативные строки: Android `values-de/-fr/-es` (имя/описание виджета, пустой плейсхолдер; превью остаётся русским до schema v2) + iOS `de/fr/es.lproj/InfoPlist.strings` (дисплей-имя, камера/галерея); +16 тестов (9 сервис + 5 экран + 2 e2e) — 182/182, analyze чист; ноль новых зависимостей и прав; ⚠ переводы de/fr/es — бот-черновик, до сторе-публикации — native-speaker-ревью; ограничение: уведомления/виджет следуют системной локали, не выбору (документировано в БЗ §20). Ручная приёмка — QA §17 (Android) / iOS по аналогии.
- **Этап 19** ✅ выполнен (05.10.2026, идея B-005 часть 2) — язык переводов слов (ru/id/de/fr/es): словарь v2 (`assets/words_db.json`, `version: 2` — в каждой из 160 записей карты `translations`/`example_translations`; миграция — одноразовый `tool/merge_translations.dart` с данными `tool/v2_*.txt`, лимиты 60/90 символов; тест-гард целостности в `word_entry_test.dart`); `WordEntry` v2 — `translationFor`/`exampleTranslationFor` с фолбэком на русские поля, `toJson` v1-совместим; `SettingsService` v2 — `translationLanguage` (дефолт ru, без «как в системе») + секция «Язык переводов» на экране настроек (ARB +1 ключ ×6); проводка: `WordCard`, `SharePoster` + share-текст, избранное/detail, квиз (`generate(translationLanguage:)`), тело уведомления; `main.dart` — слушатель смены: setState + re-sync виджета + перепланирование; контракт виджета — 7-й ключ `widget.translation_lang`, Kotlin `entryFor(db, date, lang)` (фолбэк — русское поле, паритет Dart); +21 Dart-тест (203/203) и +2 Kotlin, analyze чист; релизный APK 52.6 МБ (+0.2 МБ — карты словаря), права не менялись; ноль новых зависимостей и прав. Ручная приёмка — QA §18 (Android) / iOS по аналогии.
- **Правка приёмки 05.10.2026 (репорт этапа 19)** ✅ — единый язык приложения: `settings.json` v3 (`appLanguage`: system|en|ru|id|de|fr|es + флаги онбордингов `languagePromptShown`/`onboardingShown`; миграция v1/v2 — приоритет выбору интерфейса, онбординги → показанные); настройки — одна секция «Язык» (7 опций; en с подписью «переводы слов: Русский»), `en` — валидный выбор (интерфейс English, переводы слов русские); новый `ui/screens/language_pick_screen.dart` — мини-онбординг «Выберите язык» при en/неподдержанной системной локали (один раз, `PopScope`, после приветствия); `didChangeLocales` — «как в системе» следует смене системного языка на лету; `localeResolutionCallback` — починен latent-баг фолбэка локализации (gen-l10n сортирует supportedLocales: со этапа 18 неподдержанная системная локаль получала немецкий интерфейс); тесты settings/settings_screen переписаны, +`language_pick_screen_test.dart` (3), e2e +пикер-сценарий — 213 зелёных, analyze чист; ноль новых зависимостей и прав. Ручная приёмка — QA §17–18.
- **Этап 20** ✅ выполнен (05.10.2026, идея B-010) — онбординг первого запуска: `ui/screens/onboarding_screen.dart` — PageView из 3 слайдов ценности (слово дня → виджет → запоминание), точки-индикаторы, «Пропустить» всегда доступна («Далее» → «Начать» на последнем); гейт в main.dart после пикера языка (`isLoaded && !onboardingShown`; флаг в settings.json v3, миграция v1/v2 → true); запрос разрешения на уведомления перенесён из initState в «Начать» (Skip откладывает до следующего запуска; видевшие онбординг — стартовый прогон после загрузки настроек); payload запуска читается всегда; ARB +8 ключей ×6; +3 теста, e2e расширен — 216 зелёных, analyze и Gradle (`:app:testDebugUnitTest`) зелёные; релизный APK 52.6 МБ, права не менялись; ноль новых зависимостей и прав. Ручная приёмка — QA §19. B-007 («три регистра примеров») — кандидат на этап 21.

## 11. Порядок чтения кода новичку

1. `PLAN.md` — что и почему делаем.
2. `docs/KNOWLEDGE_BASE.md` — термины.
3. `lib/models/word_entry.dart` → `lib/services/dictionary_service.dart` → `word_of_day_service.dart` — данные и формула.
4. `lib/services/widget_sync_service.dart` → `lib/services/notification_service.dart` → `lib/services/pronunciation_service.dart` → `lib/main.dart` → `home_screen.dart` — мост, уведомления, произношение и UI.
5. `WordWidgetProvider.kt` → `res/layout/word_widget.xml` → `res/xml/word_widget_info.xml` — нативная сторона; iOS-каркас — раздел 7 этого документа (термины — БЗ §13).
6. `test/` — как всё это проверяется.

