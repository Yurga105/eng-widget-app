# Структура проекта «Слово дня» (eng_widget_app)

> Карта каталогов и файлов: что где лежит, зачем нужно и как части связаны.
> Актуально на 28.09.2026 (состояние после этапа 8).
> Термины и определения — в `docs/KNOWLEDGE_BASE.md`; план и статусы этапов — в `PLAN.md`.

## 1. Вид сверху

```text
eng_widget_app/                 корень репозитория
├─ lib/                         весь Dart-код приложения (Flutter)
│  ├─ main.dart                 входная точка: темы M3, синк виджета, приём тапов
│  ├─ models/                   модели данных (WordEntry, WordType)
│  ├─ services/                 логика: словарь, формула слова дня, мост к виджету
│  ├─ ui/screens/               экраны приложения
│  └─ ui/widgets/               переиспользуемые виджеты (карточка слова, бейдж типа)
├─ assets/
│  └─ words_db.json             офлайн-словарь: 160 записей (единственный источник данных)
├─ android/                     нативная часть: Kotlin (провайдер, калькулятор, boot-ресивер), ресурсы виджета, сборка Gradle
├─ test/                        тесты (зеркалят структуру lib/)
├─ docs/                        документация: База знаний, QA-чек-лист + этот файл
├─ PLAN.md                      главный план: решения, этапы 0–8, риски, DoD
├─ pubspec.yaml / pubspec.lock  зависимости Flutter и их фиксация
├─ analysis_options.yaml        правила линтера (flutter_lints)
└─ README.md                    шаблонная заготовка Flutter
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
| `main.dart` | `main()` + `WordOfTheDayApp` | «Проводка» этапов 4–7: синк слова в виджет при старте, на `resumed` и в полночь (пере-планируемый Timer); подписка на тапы (`initiallyLaunchedFromHomeWidget` + `widgetClicked`) → `ValueNotifier`; этап 7 — старт `NotificationService` (разрешение 1 раз за запуск + расписание), перепланирование на резюме/в полночь, тап по уведомлению (тёплый — колбэк, холодный — payload запуска) → тот же `ValueNotifier`; темы Material 3 (seed — индиго `#3F51B5`, светлая и тёмная следуют системе) |
| `models/word_entry.dart` | `WordEntry`, `WordType` | модель записи словаря: `fromJson`/`toJson`, валидация `type`, полное равенство полей — основа тестов |
| `services/dictionary_service.dart` | `DictionaryService` | чтение и парсинг `words_db.json` через `rootBundle` (UTF-8), кэш в памяти; `loadRawJson()` — исходный текст для `word_db_json` (этап 5); загрузчик подменяем в тестах |
| `services/word_of_day_service.dart` | `WordOfDayService` | формула §5 (`seedFor`/`indexFor`) — зеркально в `WordOfDayCalculator.kt` (этап 5); `databaseJson` — исходный JSON для предзагрузки виджета; часы инжектируются (фейк в тестах) |
| `services/widget_sync_service.dart` | `WidgetSyncService`, `HomeWidgetBackend` | мост к виджету: 5 ключей + `word_db_json` (база целиком, 1 раз на инстанс — этап 5) + `updateWidget`; `isoDate`/`widgetUri`/`dateFromWidgetUri`; интерфейс бэкенда введён ради тестируемости |
| `services/notification_service.dart` | `NotificationService`, `FlutterNotificationsBackend` | уведомление этапа 7: канал `word_of_day`, ежедневно в 09:00 (`nextDailyAt` — чистая функция, час — константа `notifyHour`); контент — слово дня ДНЯ срабатывания; payload = URI-контракт виджета; разрешение спрашивается 1 раз за запуск, отказ не блокирует; все вызовы плагина «тихие» (`_quietly`); бэкенд держит `tz.local` (flutter_timezone → `Etc/GMT±` → UTC) и `matchDateTimeComponents: time` — повтор натив сам переставляет и восстанавливает после ребута |
| `services/pronunciation_service.dart` | `PronunciationService`, `TtsBackend`, `FlutterTtsBackend` | произношение этапа 9: системный TTS-движок (`flutter_tts`), язык фиксированный `en-US`, `awaitSpeakCompletion(true)`; `isAvailable` — есть ли en-US-голос (нет → кнопки в карточке нет, риск §9-13), `isSpeaking` ValueNotifier — кнопка динамик↔«стоп»; `toggle`/`stop`/`dispose`; ошибки плагина глотаются `_quietly` (паттерн этапа 7) |
| `ui/screens/home_screen.dart` | `HomeScreen` + `formatDateRu` | экран этапа 6: FutureBuilder → `WordCard` выбранной даты (из тапа по виджету или сегодня); русская дата без intl («27 сентября 2026»), maxWidth 600 на планшетах, аккуратный экран ошибки словаря; этап 9: владеет `PronunciationService` (старт в initState, dispose), `ValueListenableBuilder` над `isSpeaking` перерисовывает кнопку прослушивания, `WidgetsBindingObserver` — стоп речи в фоне и при смене даты из тапа по виджету |
| `ui/widgets/word_card.dart` | `WordCard` | большая M3-карточка (`Card.filled`): Wrap-заголовок (бейдж типа, янтарная метка «из виджета», дата), слово, IPA, перевод, пример + перевод; чистый stateless — данными кормит экран; этап 9: строка слова — `Row` с `Expanded` (длинные фразы переносятся) и опциональной кнопкой-динамиком `onListen`/`isListening` (динамик ↔ «стоп»; `onListen == null` — кнопки нет) |
| `ui/widgets/type_badge.dart` | `TypeBadge` | бейдж типа: «слово»/«идиома»/«фразовый глагол», фиксированные в обеих темах цвета (индиго `#3F51B5` / янтарь `#FFB300` / teal `#00796B`); публичные `labelFor`/`backgroundFor` — для тестов и переиспользования |

Принцип: модели не знают про UI; вся логика — в сервисах (тестируются без интерфейса); экраны тонкие. Новый код: сервис → `services/`, экран → `ui/screens/`, переиспользуемый виджет UI → `ui/widgets/`.

## 5. test/ — тесты (69 Flutter + 7 Kotlin JVM, все зелёные)

| Файл | Что покрывает |
|---|---|
| `word_entry_test.dart` | модель: заполнение полей, round-trip `toJson`/`fromJson`, маппинг `type` (word / idiom / phrasal_verb), `ArgumentError` на неизвестный тип |
| `dictionary_service_test.dart` | чтение ассета, повторный вызов из кэша, `loadRawJson` (исходный текст и его ошибки), ошибки: битый JSON, отсутствие массива `words` |
| `word_of_day_service_test.dart` | формула: `seed = yyyy*10000 + MM*100 + dd`, фиксированные даты при N=160, зависимость индекса от размера базы, `ArgumentError` при `total <= 0`, смена года перемешивает последовательность (2027-01-01 → id 22) |
| `widget_sync_service_test.dart` (13) | мост на фейк-бэкенде: контракт 6 ключей (5 полей + `word_db_json`, пишется 1 раз), `isoDate` с ведущими нулями, `widgetUri`/`dateFromWidgetUri` round-trip, отбраковка чужих схем и дат вида «31 февраля» |
| `notification_service_test.dart` (12) | этап 7 на фейк-бэкенде: `nextDailyAt` (граница 09:00 ровно, переходы месяца/года), порядок `start` (initialize → permission → cancel → schedule), контент = слово дня срабатывания (до/после 09:00), payload-URI, отказ разрешения не отменяет расписание, сбои бэкенда глотаются, тап по payload → карточка даты (чужой payload игнорируется), reschedule заменяет расписание, холодный старт payload (успех/сбой) |
| `pronunciation_service_test.dart` (9) | этап 9 на фейк-бэкенде (speak не завершается сам — Completer, имитация awaitSpeakCompletion): `start` → initialize→available(en-US), нет голоса/сбой движка — мягкая деградация (кнопки нет); `speak`/`toggle` во время речи → `stop`; ошибки бэкенда и поздние платформенные колбэки не роняют сервис; `dispose` глушит речь |
| `widget_test.dart` | приложение целиком: мок обоих MethodChannel плагина (`home_widget`, `home_widget/updates`), запуск показывает слово дня по формуле §5 (регрессия экрана после этапа 6); уведомления этапа 7 без плагина тихо деградируют (`_quietly` ловит); демонтаж приложения в конце |
| `word_card_test.dart` (9) | UI этапа 6: все поля карточки + дата и бейдж, тёмная тема, метка «из виджета» только при открытии с виджета, бейджи трёх типов (подпись + цвет), влезание карточки с фразовым глаголом на экран 320×480; этап 9 (+4): тап по динамику зовёт `onListen`, кнопки нет при `onListen == null` (TTS недоступен), иконка «стоп» во время речи, влезание 320×480 проверено с кнопкой |

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
   │                         для JVM-тестов (testImplementation, этап 5)
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
| `res/values/strings.xml` | имя «Слово дня», описание, заглушки-превью (запись №1), тексты плейсхолдера |
| `res/values/widget_colors.xml` + `res/values-night/widget_colors.xml` | палитры виджета для светлой и тёмной темы — менять только парой |
| `res/values/styles.xml` + `res/values-night/styles.xml` | темы приложения и сплэша |
| `res/values/ic_launcher_colors.xml` | цвета адаптивной иконки |
| `res/drawable/widget_bg.xml` | скруглённый фон виджета (16dp) |
| `res/drawable/ic_launcher_foreground.xml` | вектор-глиф «W.» иконки (safe zone 108dp) |
| `res/drawable/ic_stat_word.xml` | alpha-only вектор 24dp для строки уведомления: белая «W.» с янтарной точкой; `defaultIcon` в `notification_service.dart` (этап 8) |
| `res/drawable-nodpi/widget_preview.png` | PNG-превью виджета 480×220 для лаунчеров API<31: карточка записи №1 («accomplish»); `nodpi` — не масштабируется по плотности (этап 8) |
| `res/mipmap-anydpi-v26/ic_launcher.xml` | адаптивная иконка API 26+ (фон + глиф) |
| `res/mipmap-*/ic_launcher.png` | растровые иконки для API<26 (этап 8): 48/72/96/144/192 px в mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi — скруглённый индиго-квадрат с глифом «W.» |

## 7. Корень и служебные файлы

| Путь | Что это |
|---|---|
| `PLAN.md` | главный план: решения §1, стек §2, структура §3, данные §4, формула §5, нативная логика §6, уведомления §7, этапы и статусы §8, риски §9, DoD §10 |
| `docs/KNOWLEDGE_BASE.md` | словарь терминов проекта |
| `docs/PROJECT_STRUCTURE.md` | этот документ |
| `docs/QA_CHECKLIST.md` | ручной чек-лист приёмки (этапы 8–9): матрица лаунчеров, ребут, темы, уведомления, иконки и превью, релизный APK, произношение |
| `README.md` | витрина репозитория (GitHub): возможности, устройство, сборка/запуск/тесты, ссылки на доки; обновляйте при заметных изменениях |
| `pubspec.yaml` | зависимости (`home_widget 0.10.0`, `flutter_local_notifications 22.3.1`, `timezone` + `flutter_timezone` — этап 7, `flutter_tts 4.2.5` — этап 9), ассет `words_db.json`, версия SDK |
| `pubspec.lock` | точная фиксация версий пакетов — коммитить |
| `analysis_options.yaml` | включение flutter_lints |
| `.gitignore` | исключения из git: `build/`, `.dart_tool/`, `local.properties` и т.п. |
| `.metadata`, `*.iml`, `.flutter-plugins-dependencies` | служебные файлы Flutter/IDE — руками не редактируются |

## 8. Куда класть новый код

| Добавляю | Куда | Пример |
|---|---|---|
| логика/сервис | `lib/services/` + тест в `test/` | `notification_service.dart` (этап 7) |
| экран | `lib/ui/screens/` | — |
| переиспользуемый виджет UI | `lib/ui/widgets/` | `word_card.dart`, `type_badge.dart` (этап 6) |
| модель данных | `lib/models/` | — |
| строка виджета (нативная) | `android/.../res/values/strings.xml` | плейсхолдеры этапа 4 |
| цвет виджета | `values/widget_colors.xml` + `values-night/widget_colors.xml` (пара!) | — |
| ключ контракта Flutter↔Kotlin | `widget_sync_service.dart` + `WordWidgetProvider.kt` синхронно | 6 ключей: `widget.*` + `word_db_json`; URI тапа `wordoftheday://word?date=…` общий для виджета и уведомления (парсер `dateFromWidgetUri`) |
| чистая нативная логика | object в `kotlin/…/` + JVM-тест в `android/app/src/test/kotlin/` | `WordOfDayCalculator.kt` (этап 5) |

## 9. Что появится по плану

- **Этап 5** ✅ выполнен (27.09.2026) — ключ `word_db_json` в prefs, `WordOfDayCalculator.kt` (org.json) и автономный `onUpdate` с fallback-цепочкой, `BootCompletedReceiver` + право `RECEIVE_BOOT_COMPLETED` в манифесте. Полуночный будильник НЕ потребовался: гарантию смены слова даёт `updatePeriodMillis` 30 мин (PLAN.md §6, риски §9-2/§9-6).
- **Этап 6** ✅ выполнен (27.09.2026) — `WordCard` (`Card.filled`) + `TypeBadge` (индиго/янтарь/teal, фиксированы в обеих темах) + полноценный `HomeScreen` (`formatDateRu` без intl, maxWidth 600, экран ошибки словаря); янтарный акцент палитры §1 — бейдж идиомы и метка «из виджета»; +5 тестов (flutter test 44/44), analyze чисто, debug-APK собирается. Ручная приёмка на устройстве — за пользователем.
- **Этап 7** ✅ выполнен (27.09.2026) — `services/notification_service.dart`: канал `word_of_day`, ежедневно 09:00 (`inexactAllowWhileIdle`, `matchDateTimeComponents: time` — повтор натив переставляет сам), контент = слово дня дня срабатывания, payload = URI-контракт виджета (тап → карточка того же дня), `POST_NOTIFICATIONS` 1 раз за запуск с мягкой деградацией; манифест: `POST_NOTIFICATIONS` + 2 receiver'а плагина; пакеты `timezone` + `flutter_timezone`; +12 тестов (flutter test 56/56), analyze чисто, debug-APK собирается. Ручная приёмка (приход в 09:00, тап, отказ в разрешении) — за пользователем.
- **Этап 8** ✅ выполнен (28.09.2026) — PNG-иконки лаунчера `mipmap-{mdpi…xxxhdpi}/ic_launcher.png` (5 плотностей, 48–192 px), PNG-превью виджета `drawable-nodpi/widget_preview.png` + `previewImage` в дескрипторе, alpha-only иконка уведомлений `drawable/ic_stat_word.xml`; analyze чисто, flutter test 56/56, релизный APK собирается. Ручная матрица QA — `docs/QA_CHECKLIST.md`, приёмка — за пользователем.
- **Этап 9** ✅ выполнен (28.09.2026) — `services/pronunciation_service.dart` (`TtsBackend`/`FlutterTtsBackend` + `PronunciationService`, мягкая деградация `_quietly`), кнопка-динамик в `WordCard` (`onListen`/`isListening`, null → кнопки нет), проводка в `HomeScreen` (`ValueListenableBuilder` + `WidgetsBindingObserver`: фон/смена даты → стоп речи), `<queries>` `TTS_SERVICE` в манифесте (Android 11+); пакет `flutter_tts ^4.2.5`; +13 тестов (flutter test 69/69), analyze чисто; релизный APK 45.4 МБ, `aapt dump permissions` — новых прав нет, `INTERNET` нет; установлен на RMX2001. Ручная приёмка (звук en-US, скорость, стоп тапом/фоном) — за пользователем.

## 10. Порядок чтения кода новичку

1. `PLAN.md` — что и почему делаем.
2. `docs/KNOWLEDGE_BASE.md` — термины.
3. `lib/models/word_entry.dart` → `lib/services/dictionary_service.dart` → `word_of_day_service.dart` — данные и формула.
4. `lib/services/widget_sync_service.dart` → `lib/services/notification_service.dart` → `lib/services/pronunciation_service.dart` → `lib/main.dart` → `home_screen.dart` — мост, уведомления, произношение и UI.
5. `WordWidgetProvider.kt` → `res/layout/word_widget.xml` → `res/xml/word_widget_info.xml` — нативная сторона.
6. `test/` — как всё это проверяется.

