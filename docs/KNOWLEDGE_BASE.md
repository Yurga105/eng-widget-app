# База знаний — словарь терминов проекта «Слово дня» (eng_widget_app)

> Живой глоссарий: понятия из кода, PLAN.md, коммитов и обсуждений — с короткими определениями и указанием, где термин живёт в репозитории.
> Актуальность: 28.09.2026, состояние после этапа 9. Обновляйте при изменении архитектуры.
> Сопутствующий документ: `docs/PROJECT_STRUCTURE.md` — карта файлов и потоков данных.

## 1. Продукт и данные

**Слово дня** — главная сущность: одна запись словаря, закреплённая за календарной датой. Выбирается детерминированной формулой (раздел 3) и одинакова при любом числе запусков в этот день.

**Словарная база** — единственный источник данных: `assets/words_db.json`, 160 записей, обёртка `{"version":1,"words":[...]}`. Приложение полностью офлайн: сети, API и прав на интернет нет (PLAN.md §1, §10).

**Запись (WordEntry)** — `lib/models/word_entry.dart`. Поля: `id`, `word`, `transcription`, `translation` (1–2 значения, ≤60 символов), `example` (англ., ≤90), `example_ru`, `type`. Реализует `fromJson`/`toJson` и полное поэлементное равенство — на нём строятся тесты.

**WordType** — enum типа записи: `word` (слово), `idiom` (идиома), `phrasal_verb` (фразовый глагол); JSON-значения фиксированы, неизвестное значение бросает `ArgumentError`.

**Транскрипция IPA** — американское произношение в слэшах, например `/əˈkɑːmplɪʃ/`.

**Идиома / фразовый глагол** — устойчивые выражения (50% базы): это обычные записи, отличает только `type` — и цвет бейджа на карточке (этап 6: идиома — янтарный, фразовый глагол — teal).

**Заглушки-превью** — статические тексты этапа 3 (`res/values/strings.xml`, `word_widget_preview_*`), равные записи №1 (`accomplish`): виджет показывает их до первого `onUpdate` — нет мигания пустым макетом.

**Плейсхолдер пустых данных** — «Слово дня / Откройте приложение…»: если виджет добавлен до первого запуска приложения и prefs ещё пусты (риск §9-7).

## 2. Dart: сервисы и UI

**DictionaryService** (`lib/services/dictionary_service.dart`) — читает и парсит ассет через `rootBundle` (гарантированный UTF-8, риск §9-11), кэширует список `WordEntry`; `loadRawJson()` отдаёт исходный текст базы — его кладут в `word_db_json` для нативной стороны (этап 5). Загрузчик ассета подменяемый — для тестов.

**WordOfDayService** (`word_of_day_service.dart`) — выбор слова: `today`/`wordForDate()` поверх статических `seedFor()`/`indexFor()` (раздел 3). Часы инжектируются: продакшн `DateTime.now`, тесты — фейк.

**WidgetSyncService** (`widget_sync_service.dart`) — мост Flutter→виджет (этапы 4–5): `syncToday()`/`syncForDate(date)` пишут 5 ключей + `word_db_json` (вся база, один раз на инстанс сервиса) и просят перерисовку; `isoDate()`, `widgetUri()`, `dateFromWidgetUri()` обслуживают URI тапа.

**HomeWidgetBackend / PluginHomeWidgetBackend** — узкий интерфейс над плагином (`saveWidgetData`, `updateWidget`): статика плагина плохо подменяется в тестах, поэтому тесты получают фейк, прод — `PluginHomeWidgetBackend`.

**ValueNotifier<DateTime?>** — транспорт «тап виджета → экран»: `main.dart` кладёт туда дату из URI, `HomeScreen` слушает и перестраивает карточку.

**rootBundle** — доступ Flutter к ассетам; `loadString` декодирует данные как UTF-8 явно.

**HomeScreen** (`lib/ui/screens/home_screen.dart`) — единственный экран приложения (UI v1.0, §1): FutureBuilder запрашивает `WordOfDayService.wordForDate` и рисует `WordCard`; слушает `ValueNotifier<DateTime?>` тапов виджета (этап 4). Три состояния: загрузка (спиннер), ошибка словаря (иконка + текст), карточка; maxWidth 600 — не растягивается на планшетах. Этап 9: владеет `PronunciationService` (старт в initState, dispose в dispose), обёртка `ValueListenableBuilder` над `isSpeaking` перерисовывает кнопку прослушивания; `WidgetsBindingObserver` — уход в фон/скрытие глушит речь, как и смена даты из тапа по виджету.

**WordCard** (`lib/ui/widgets/word_card.dart`) — большая карточка слова дня (`Card.filled`, Material 3): Wrap-заголовок (бейдж типа + янтарная метка «из виджета» + дата), слово, транскрипция, перевод, пример и его перевод. Wrap вместо Row — заголовок переносится на узких экранах без переполнения; `SizedBox(width: double.infinity)` — растяжение на ширину карточки. Этап 9: строка слова — `Row` с `Expanded` (длинные фразы переносятся) и опциональной кнопкой-динамиком `onListen`/`isListening` (динамик ↔ «стоп»); `onListen == null` (нет TTS) — кнопки нет, виджет остаётся stateless.

**TypeBadge** (`lib/ui/widgets/type_badge.dart`) — цветной бейдж типа: «слово» (индиго `#3F51B5`), «идиома» (янтарь `#FFB300`), «фразовый глагол» (teal `#00796B`); цвета фиксированы в обеих темах — легенда читается одинаково в свете и тьме. Публичные `labelFor`/`backgroundFor`/`foregroundFor` переиспользуются тестами.

**formatDateRu** — русская дата «27 сентября 2026» (функция в `home_screen.dart`): месяцы родительного падежа списком, без пакета intl (стек §2 — без внешних пакетов сверх необходимых).

**Янтарный акцент палитры §1** — индиго остаётся seed-цветом тем (этап 4), янтарь появляется точечно: бейдж идиомы и метка «из виджета» (фон ~18% янтарного, тёмно-янтарный текст в свете / `#FFD54F` в тьме).

## 3. Формула слова дня (PLAN.md §5)

```text
date  = локальная календарная дата (yyyy-MM-dd)
seed  = yyyy * 10000 + MM * 100 + dd      // 2026-09-27 → 20260927
index = seed mod N                        // N = 160
```

**seed** — целое число даты; **index** — позиция записи в базе. Одно слово на весь календарный день, смена после локальной полуночи.

**Детерминизм** — нет случайностей и зависимости от времени суток: слово восстанавливается из одной только даты. Поэтому тап из виджета передаёт лишь дату (`wordoftheday://word?date=…`), а не содержимое карточки.

**Перемешивание по годам** — год входит в seed: 1 января последовательность стартует с новой позиции (2027-01-01 → запись с id 22 при N=160).

**Единая формула Dart/Kotlin (риск §9-4)** — арифметика повторена 1:1 в `WordOfDayCalculator.kt` (этап 5); контроль — общие тест-векторы дат в `word_of_day_service_test.dart` и `WordOfDayCalculatorTest.kt`.

## 4. Контракт Flutter↔виджет (PLAN.md §6)

Общее правило: ключи и схема URI — контракт `lib/services/widget_sync_service.dart` ↔ `WordWidgetProvider.kt`; менять только синхронно.

| Ключ prefs | Содержимое | Пример |
|---|---|---|
| `widget.date` | дата слова, `yyyy-MM-dd` | `2026-09-27` |
| `widget.word` | слово/выражение | `accomplish` |
| `widget.transcription` | IPA | `/əˈkɑːmplɪʃ/` |
| `widget.translation` | перевод | `достигать, выполнять` |
| `widget.example` | английский пример | `She accomplished all her goals this year.` |
| `word_db_json` | весь `words_db.json` одним текстом (этап 5) | `{"version":1,"words":[…]}` |

Пишет — `WidgetSyncService` через `HomeWidget.saveWidgetData`; читает — `WordWidgetProvider.onUpdate`.

**HomeWidgetPreferences** — имя файла SharedPreferences Android, куда плагин `home_widget` складывает всё, что записали через `saveWidgetData`.

**URI тапа** — `wordoftheday://word?date=yyyy-MM-dd`. Провайдер помещает URI в PendingIntent тапа; Dart разбирает `dateFromWidgetUri()` с отбраковкой чужих схем и невозможных дат («31 февраля» отсекается round-trip-проверкой через `DateTime`).

**word_db_json** — вся база одним текстом (этап 5): `WidgetSyncService` пишет исходный текст ассета как есть (UTF-8 без перекодировок, риск §9-11), а `WordOfDayCalculator` парсит его `org.json`-ом и считает слово дня сам — виджет меняет слово после полуночи без запуска приложения.

## 5. Нативная сторона Android

**App Widget** — мини-приложение на домашнем экране; наш — 4×2 без кнопок, тап по всей площади.

**Receiver / AppWidgetProvider** — системный колбэк обновления. В манифесте: `exported="false"`, intent-filter `APPWIDGET_UPDATE`, `meta-data` → `@xml/word_widget_info`.

**HomeWidgetProvider** — базовый класс из плагина: расширяет `AppWidgetProvider` и подаёт в `onUpdate` готовые `SharedPreferences`.

**WordWidgetProvider** (`WordWidgetProvider.kt`) — наш провайдер (этап 5): приоритет источников — `word_db_json` (автономный пересчёт через `WordOfDayCalculator`, дата URI = сегодня) → 5 ключей `widget.*` (этап 4) → плейсхолдер; тап → `HomeWidgetLaunchIntent` с URI показанной даты.

**WordOfDayCalculator** (`WordOfDayCalculator.kt`) — чистый object этапа 5: формула §5 (`seedFor`/`indexFor`/`isoDate` с `Locale.ROOT` — только ASCII-цифры) + `entryFor(dbJson, date)` поверх `org.json`; любые проблемы базы → `null`, и провайдер уходит в fallback. Не знает про Android — тестируется на JVM.

**RemoteViews** — «снимок» UI виджета: допускает только простые view (LinearLayout, TextView) и системные шрифты (риск §9-1) — отсюда минималистичный макет.

**PendingIntent** — заранее подготовленное намерение открыть `MainActivity` по тапу; `HomeWidgetLaunchIntent` — обёртка плагина, доставляющая URI в Flutter.

**singleTop** — launchMode MainActivity: повторные тапы не плодят задачи, интент доезжает в уже живое приложение.

**updatePeriodMillis** — системный ритм обновления виджета; 30 мин (1 800 000 мс) — минимум Android. Это и есть гарантия автономной смены слова ≤30 мин после полуночи (этап 5); отдельный будильник не нужен — окно ≤30–60 мин принято (риски §9-2/§9-6), точных будильников не запрашиваем.

**BOOT_COMPLETED** — рассылка после перезагрузки: `BootCompletedReceiver` (`exported="false"`, право `RECEIVE_BOOT_COMPLETED`) сразу просит систему вызвать `onUpdate` провайдера — иначе виджет молчал бы до первого 30-минутного тика (риск §9-2, этап 5). Приложение при этом не запускается.

**values-night** — тёмная палитра ресурсов: система сама подставляет её в тёмной теме, код темы не различает.

**Адаптивная иконка** — `mipmap-anydpi-v26/ic_launcher.xml` + вектор-глиф «W.» (индиго + янтарная точка), действует на API 26+; растровые PNG для API<26 — этап 8 (5 плотностей mdpi…xxxhdpi, 48–192 px; тот же глиф на скруглённом индиго-квадрате).

**previewImage / previewLayout** — два превью виджета в `word_widget_info.xml`: `previewLayout` (API 31+) рисует живой макет `word_widget`, `previewImage` (этап 8) — статичный PNG `drawable-nodpi/widget_preview.png` 480×220 для старых лаунчеров. В пикере виджетов система берёт то, что умеет: на API 31+ — живой макет, на API<31 — PNG.

**drawable-nodpi** — каталог ресурсов без квалификатора плотности: файл отдаётся всем устройствам как есть, без автоматического масштабирования. Выбран для превью, чтобы один PNG 480×220 не плодился в 5 плотностях (превью показывается недолго и только в пикере).

**alpha-only иконка уведомления (ic_stat_word)** — small icon уведомлений Android должна быть одноцветной альфа-маской (система сама красит в белый/тёмный по теме шторки); цветной PNG система заливает серым квадратом. `res/drawable/ic_stat_word.xml` — вектор 24dp: белые «W» и янтарная точка (точка тоже white-альфа; акцент теряется — это норма платформы). Подключена как `defaultIcon` в `notification_service.dart` (этап 8).

**org.json** — встроенный JSON-парсер Android — им `WordOfDayCalculator` разбирает `word_db_json`; в JVM-тестах классы `org.json` из `android.jar` — заглушки, поэтому для тестов в `app/build.gradle.kts` подключена `org.json:json` (testImplementation).

**Doze** — режим экономии батареи: точная полночь не гарантирована; принято окно ≤30–60 мин (риск §9-2) + синки при открытии приложения, тапе и резюме.

## 6. Плагин home_widget (0.10.0)

Плагин-посредник между Dart и нативной стороной: хранилище данных, запрос обновления, приём тапов. Версия зафиксирована в pubspec (риск §9-10).

**saveWidgetData(key, value)** — запись значения в HomeWidgetPreferences.

**updateWidget(androidName:)** — просьба к системе вызвать `onUpdate` провайдера (по имени класса).

**initiallyLaunchedFromHomeWidget()** — Future с URI тапа, который запустил холодный процесс приложения.

**widgetClicked** — Stream URI тапов, когда приложение уже живо (тёплый старт).

**Два MethodChannel** — `home_widget` и `home_widget/updates`: в widget-тестах нужно мокать ОБА через TestDefaultBinaryMessenger, иначе тест падает на реальном канале.

## 7. Жизненный цикл приложения

**WidgetsBindingObserver** — миксин `main.dart` (колбэк `didChangeAppLifecycleState`) и с этапа 9 также `HomeScreen`: уход в фон/скрытие (`paused`/`hidden`) глушит воспроизведение TTS.

**resumed** — возврат на передний план: повторный синк виджета (полночь могла пройти в фоне) и перепланирование таймера (риск §9-2).

**Полуночный Timer** — таймер до следующей локальной полуночи, перепланируется сам; смена слова, пока процесс жив. Без запуска приложения слово меняет сам провайдер из `word_db_json` (этап 5) — таймер лишь ускоряет момент, когда и приложение в курсе.

**Холодный старт** — процесс был убит: URI тапа читается один раз через `initiallyLaunchedFromHomeWidget()`.

**Тёплый старт** — приложение живо: тап приходит стримом `widgetClicked`.

## 8. Уведомления (этап 7)

**flutter_local_notifications ^22.3.1** — локальные уведомления (в pubspec с этапа 0; требует core library desugaring). App-level API v22: `initialize({required settings, …})`, `cancel({required id})`; `zonedSchedule` уже без `uiLocalNotificationDateInterpretation`. `matchDateTimeComponents: time` — нативный `ScheduledNotificationReceiver` после срабатывания сам ставит следующий день по настенным часам зоны из `TZDateTime.location` (java.time, DST-aware); после ребута/обновления приложения расписание восстанавливает `ScheduledNotificationBootReceiver` — оба receiver'а обязаны быть в манифесте (README плагина).

**Канал `word_of_day`** — ежедневное `zonedSchedule` на 09:00 локального времени, `androidScheduleMode: inexactAllowWhileIdle` — без прав на точные будильники (риск §9-6). Контент — слово дня ДНЯ СРАБАТЫВАНИЯ (запуск в 10:00 планирует завтрашнее уведомление со завтрашним словом); триггеры перепланирования — старт/резюм/полночь (`main.dart`); payload = `wordoftheday://word?date=…` — тем же парсером `dateFromWidgetUri` открывается карточка этого дня (тёплый и холодный старт). «Застарелое» расписание остаётся ежедневным и самосогласованным: показанное слово соответствует дате в payload.

**POST_NOTIFICATIONS** — runtime-разрешение Android 13+: запрашиваем через `requestNotificationsPermission()` Android-импла один раз за запуск; на Android <13 — no-op. Отказ — мягкая деградация: расписание всё равно ставится, виджет не зависит от уведомлений (риск §9-5); после отказов ОС сама перестаёт показывать диалог (включить можно в настройках приложения).

**flutter_timezone ^5.1.0** (этап 7) — IANA-имя зоны устройства: `getLocalTimezone()` → `TimezoneInfo.identifier` (в 5.x — объект, не строка!). Нужен, потому что пакет `timezone` не умеет читать системную зону.

**timezone ^0.11.1** (этап 7, прямая зависимость) — база зон и `tz.local` для `TZDateTime`. Цепочка фолбэков зоны: flutter_timezone → строка Dart «GMT+3» → `Etc/GMT-3` (знак инвертирован, зоны Etc покрывают только целые часы) → UTC (деградация: уведомление остаётся ежедневным, но в 09:00 UTC).

## 9. Произношение (этап 9)

**flutter_tts ^4.2.5** — обёртка над системным TTS-сервисом Android (`android.speech.tts`): играет движок, предустановленный на устройстве (Google Speech Services и т.п.) — офлайн, без прав, APK не растёт. В widget-тестах плагина нет — `start()` тихо деградирует (MissingPluginException ловится `_quietly`). `ErrorHandler` плагина принимает `dynamic`, а `isLanguageAvailable` возвращает `Future<dynamic>` — обёртка приводит типы под строгий контракт `TtsBackend`.

**PronunciationService** (`lib/services/pronunciation_service.dart`) — озвучивание слова/фразы дня (для идиом и фразовых глаголов — вся фраза целиком): `start()` (настройка + `isLanguageAvailable('en-US')`), `toggle(text)` (молчит → speak, говорит → stop), `stop()`, `dispose()`. Состояние: `isSpeaking` — ValueNotifier для кнопки (динамик ↔ «стоп»), `isAvailable` — есть ли en-US-голос (нет → кнопки в карточке нет, риск §9-13). Все вызовы плагина «тихие», как в этапе 7.

**TtsBackend / FlutterTtsBackend** — интерфейс + продакшн-импла над плагином (паттерн `NotificationsBackend` этапа 7): фейк в тестах задаёт сбои и «долгую речь» (speak не завершается сам — Completer, имитация awaitSpeakCompletion).

**awaitSpeakCompletion(true)** — режим плагина: future `speak()` резолвится по концу речи, а не по постановке в очередь; колбэки `setCompletionHandler`/`setErrorHandler` — страховка сброса `isSpeaking` при сбое движка посреди фразы. Скорость речи 0.5 — «нормальная» для en-US-голосов плагина.

**TTS_SERVICE в `<queries>`** — package visibility: с Android 11 (API 30) приложение без этого intent-filter в `<queries>` не видит сервисы TTS — `flutter_tts` не нашёл бы ни одного движка. Это не право, а фильтр видимости: новых разрешений APK не получает.

## 10. Тестирование и качество

**flutter_test** — 56 тестов после этапа 7 (+12 `notification_service_test.dart` к 44 этапа 6): unit всех сервисов и модели + widget-тесты приложения и карточки (`word_card_test.dart`: поля карточки, тёмная тема, бейджи×3, метка «из виджета», влезание на экран 320×480). Этап 8 — только ресурсы (PNG, векторы, дескриптор): тесты не менялись. Этап 9 — +9 `pronunciation_service_test.dart` и +4 в `word_card_test.dart` (кнопка прослушивания): 69/69 зелёные. Нативная логика — 7 JVM-тестов `WordOfDayCalculatorTest` (`cd android; gradlew :app:testDebugUnitTest`).

**Фейк бэкенда** — `FakeHomeWidgetBackend` в `widget_sync_service_test.dart`: проверка контракта 6 ключей (5 полей + `word_db_json`, пишется один раз) без плагина.

**Фейковые часы** — подмена `DateTime.now()` в тестах WordOfDayService: фиксированные даты вместо «сегодня».

**Мок MethodChannel** — подмена обработчиков обоих каналов плагина в `widget_test.dart` + демонтаж приложения в конце (чистота между тестами).

**Тест-векторы Dart/Kotlin** — одинаковая таблица дат для N=160 (1999-12-31→31 … 2027-01-01→21) в `word_of_day_service_test.dart` и `WordOfDayCalculatorTest.kt` против расхождения формулы (риск §9-4); при изменении N пересчитать в обеих сторонах одновременно.

**flutter analyze** — статический анализ (flutter_lints); должен быть без замечаний перед каждым коммитом.

## 11. Сборка и окружение

**Flutter SDK ^3.13.4, Material 3** — темы из seed-цвета индиго `#3F51B5` (+ янтарный акцент); внешний state-management не используется: `StatefulWidget` + `ValueNotifier`.

**Gradle Kotlin DSL** — `android/*.gradle.kts`; **desugaring** включён в `app/build.gradle.kts` (благодаря ему `java.time.LocalDate` работает и на Android < 26).

**JAVA_HOME** — прямой запуск `gradlew.bat` требует валидный JAVA_HOME; системный указывал на удалённый JDK, рабочее значение — JBR Android Studio (`C:\Program Files\Android\Android Studio\jbr`). `flutter build …` находит JDK сам.

**Сборка и установка** — `flutter build apk --debug` и `flutter build apk --release` (релиз подписан debug-ключом — `signingConfig debug` в `app/build.gradle.kts`, для локальных приёмочных сборок; боевой keyStore — за рамками v1.0), установка через `adb install --user 0 -r`; приёмочные проверки — на RMX2001 / Android 11.

**Права манифеста (этап 8)** — `aapt dump permissions` релизного APK: `INTERNET` отсутствует (в debug он появляется из оверлея `src/debug` Flutter — норма отладки). Merged-права релиза: наши `RECEIVE_BOOT_COMPLETED` + `POST_NOTIFICATIONS`; `VIBRATE` — flutter_local_notifications; `WAKE_LOCK`, `ACCESS_NETWORK_STATE`, `FOREGROUND_SERVICE` — androidx.work:work-runtime 2.11.2, который транзитивно тянет androidx.glance 1.2.0 (поддержка Glance-виджетов в home_widget 0.10.0, нами не используется). Сетевого доступа не даёт ни одно — DoD «ноль сетевых прав» трактуем как «нет `INTERNET` и прав, дающих трафик».

**Стиль коммитов** — subject `Этап N: …` + тело из буллетов `•`.

## 12. Процесс

**PLAN.md** — единый источник правды: решения §1, стек §2, структура §3, данные §4, формула §5, нативная логика §6, уведомления §7, этапы §8, риски §9, DoD §10.

**Этапы 0–9** — 0: каркас; 1: модель и словарь; 2: формула; 3: нативный виджет (статика); 4: мост Flutter↔виджет; 5: автономная смена; 6: UI; 7: уведомления; 8: QA и полировка; 9: произношение (системный TTS). Текущий статус — таблица §8 PLAN.md.

**Definition of Done (§10)** — офлайн-смена слова ±30 мин без запуска приложения, тап → карточка дня, темы по системе, зелёные analyze/test, релизный APK, ноль сетевых прав.

