# База знаний — словарь терминов проекта «Слово дня» (eng_widget_app)

> Живой глоссарий: понятия из кода, PLAN.md, коммитов и обсуждений — с короткими определениями и указанием, где термин живёт в репозитории.
> Актуальность: 03.10.2026, состояние после этапа 17 (preload-экран приветствия). Обновляйте при изменении архитектуры.
> Сопутствующий документ: `docs/PROJECT_STRUCTURE.md` — карта файлов и потоков данных.

## 1. Продукт и данные

**Слово дня** — главная сущность: одна запись словаря, закреплённая за календарной датой. Выбирается детерминированной формулой (раздел 3) и одинакова при любом числе запусков в этот день.

**Словарная база** — единственный источник данных: `assets/words_db.json`, 160 записей, обёртка `{"version":1,"words":[...]}`. Приложение полностью офлайн: сети, API и прав на интернет нет (PLAN.md §1, §10).

**Запись (WordEntry)** — `lib/models/word_entry.dart`. Поля: `id`, `word`, `transcription`, `translation` (1–2 значения, ≤60 символов), `example` (англ., ≤90), `example_ru`, `type`. Реализует `fromJson`/`toJson` и полное поэлементное равенство — на нём строятся тесты.

**WordType** — enum типа записи: `word` (слово), `idiom` (идиома), `phrasal_verb` (фразовый глагол); JSON-значения фиксированы, неизвестное значение бросает `ArgumentError`.

**Транскрипция IPA** — американское произношение в слэшах, например `/əˈkɑːmplɪʃ/`.

**Идиома / фразовый глагол** — устойчивые выражения (50% базы): это обычные записи, отличает только `type` — и цвет бейджа на карточке (этап 6: идиома — янтарный, фразовый глагол — teal).

**Заглушки-превью** — статические тексты этапа 3 (`res/values/strings.xml`, `word_widget_preview_*`), равные записи №1 (`accomplish`): виджет показывает их до первого `onUpdate` — нет мигания пустым макетом. Перевод записи («достигать, выполнять») остаётся русским во всех локалях, пока не локализован сам словарь (schema v2).

**Плейсхолдер пустых данных** — «Word of Day / Open the app to see today's word» (локализован этапом 10: ru — «Слово дня / Откройте приложение…», id — «Kata Hari Ini / Buka aplikasi…»): если виджет добавлен до первого запуска приложения и prefs ещё пусты (риск §9-7).

## 2. Dart: сервисы и UI

**DictionaryService** (`lib/services/dictionary_service.dart`) — читает и парсит ассет через `rootBundle` (гарантированный UTF-8, риск §9-11), кэширует список `WordEntry`; `loadRawJson()` отдаёт исходный текст базы — его кладут в `word_db_json` для нативной стороны (этап 5). Загрузчик ассета подменяемый — для тестов.

**WordOfDayService** (`word_of_day_service.dart`) — выбор слова: `today`/`wordForDate()` поверх статических `seedFor()`/`indexFor()` (раздел 3). Часы инжектируются: продакшн `DateTime.now`, тесты — фейк.

**WidgetSyncService** (`widget_sync_service.dart`) — мост Flutter→виджет (этапы 4–5): `syncToday()`/`syncForDate(date)` пишут 5 ключей + `word_db_json` (вся база, один раз на инстанс сервиса) и просят перерисовку; `isoDate()`, `widgetUri()`, `dateFromWidgetUri()` обслуживают URI тапа.

**HomeWidgetBackend / PluginHomeWidgetBackend** — узкий интерфейс над плагином (`saveWidgetData`, `updateWidget`): статика плагина плохо подменяется в тестах, поэтому тесты получают фейк, прод — `PluginHomeWidgetBackend`.

**ValueNotifier<DateTime?>** — транспорт «тап виджета → экран»: `main.dart` кладёт туда дату из URI, `HomeScreen` слушает и перестраивает карточку.

**rootBundle** — доступ Flutter к ассетам; `loadString` декодирует данные как UTF-8 явно.

**HomeScreen** (`lib/ui/screens/home_screen.dart`) — единственный экран приложения (UI v1.0, §1): FutureBuilder запрашивает `WordOfDayService.wordForDate` и рисует `WordCard`; слушает `ValueNotifier<DateTime?>` тапов виджета (этап 4). Три состояния: загрузка (спиннер), ошибка словаря (иконка + текст), карточка; maxWidth 600 — не растягивается на планшетах. Этап 9: владеет `PronunciationService` (старт в initState, dispose в dispose), обёртка `ValueListenableBuilder` над `isSpeaking` перерисовывает кнопку прослушивания; `WidgetsBindingObserver` — уход в фон/скрытие глушит речь, как и смена даты из тапа по виджету.

**WordCard** (`lib/ui/widgets/word_card.dart`) — большая карточка слова дня (`Card.filled`, Material 3): Wrap-заголовок (бейдж типа + янтарная метка «из виджета» + дата), слово, транскрипция, перевод, пример и его перевод. Wrap вместо Row — заголовок переносится на узких экранах без переполнения; `SizedBox(width: double.infinity)` — растяжение на ширину карточки. Этап 9: строка слова — `Row` с `Expanded` (длинные фразы переносятся; правка приёмки 05.10.2026: одиночное слово — всегда одной строкой, длинное ужмётся `FittedBox` scaleDown, как заголовок постера, а не сломается посимвольно — репорт «passionate» → «passionat / e»; многословные лексемы до 29 символов — перенос на ≤2 строки, чтобы не мельчали) и опциональной кнопкой-динамиком `onListen`/`isListening` (динамик ↔ «стоп»); `onListen == null` (нет TTS) — кнопки нет, виджет остаётся stateless.

**TypeBadge** (`lib/ui/widgets/type_badge.dart`) — цветной бейдж типа: «слово» (зелёный green 800 `#2E7D32` — с этапа 10, было индиго), «идиома» (янтарь `#FFB300`), «фразовый глагол» (teal `#00796B`); цвета фиксированы независимо от темы — легенда читается одинаково. Подписи локализованы (этап 10): `labelFor(context, type)` берёт строку из AppLocalizations. Публичные `labelFor`/`backgroundFor`/`foregroundFor` переиспользуются тестами.

**formatDate** — локализованная дата «27 September 2026» / «27 сентября 2026» (функция в `home_screen.dart`, этап 10): `DateFormat('d MMMM y', локаль)` из intl — русские месяцы в родительном падеже библиотека дат берёт сама (раньше был собственный список месяцев — `formatDateRu`).

**Янтарный акцент палитры §1** — seed-цвет тем с этапа 10 — зелёный `#4CAF50` (редизайн; до этого индиго, этап 4), приложение всегда светлое; янтарь появляется точечно: бейдж идиомы и метка «из виджета» (фон ~18% янтарного, тёмно-янтарный текст в свете / `#FFD54F` в тьме).

**AppLocalizations / ARB (этап 10)** — типобезопасные локализованные строки UI: шаблон `lib/l10n/app_en.arb` (+ `app_ru.arb`, `app_id.arb`; id — целевой рынок Индонезия), генерация `flutter gen-l10n` по `l10n.yaml` в `lib/l10n/generated/` — генерат коммитится (синтетический пакет в `.dart_tool` объявлен deprecated, явный `output-dir` — рекомендованный способ). Подключение — `localizationsDelegates` + `supportedLocales` в MaterialApp, `onGenerateTitle` для имени ОС; неподержанная локаль → en. Уведомления локализуются без контекста: `NotificationService` грузит делегат по `PlatformDispatcher.instance.locale` с каноникализацией intl (`'in'` → `'id'` — legacy-коды Android). DateTime-плейсхолдеры ARB (описание канала — `{time}` из `notifyHour`) форматирует `DateFormat.jm` по локали; символы дат сервис инициализирует сам (`initializeDateFormatting` из intl) — он живёт без MaterialApp, GlobalMaterialLocalizations ему недоступен.

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

**values-night** — тёмная палитра ресурсов: система сама подставляет её в тёмной теме, код темы не различает. С этапа 10 приложение всегда светлое (`ThemeMode.light`), но виджет живёт на домашнем экране и ночную палитру (тёмно-зелёную) сохраняет.

**Адаптивная иконка** — `mipmap-anydpi-v26/ic_launcher.xml` + вектор-глиф «W.» (зелёный фон green 500 `#4CAF50` + янтарная точка — редизайн этапа 10, до этого индиго), действует на API 26+; растровые PNG для API<26 перегенерированы (5 плотностей mdpi…xxxhdpi, 48–192 px; тот же глиф на скруглённом зелёном квадрате).

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

**Канал `word_of_day`** — ежедневное `zonedSchedule` на 09:00 локального времени, `androidScheduleMode: inexactAllowWhileIdle` — без прав на точные будильники (риск §9-6). Id канала неизменяем, но имя/описание и тексты уведомления локализованы (этап 10): Android разрешает переименовывать существующий канал повторным `createNotificationChannel` — смена языка устройства подхватывается при следующем запуске. Время в описании канала — `{time}`-плейсхолдер: единственный источник — константа `notifyHour`, формат (`9:00 AM`/`9:00`/`09.00`) делает intl. Контент — слово дня ДНЯ СРАБАТЫВАНИЯ (запуск в 10:00 планирует завтрашнее уведомление со завтрашним словом); триггеры перепланирования — старт/резюм/полночь (`main.dart`); payload = `wordoftheday://word?date=…` — тем же парсером `dateFromWidgetUri` открывается карточка этого дня (тёплый и холодный старт). «Застарелое» расписание остаётся ежедневным и самосогласованным: показанное слово соответствует дате в payload.

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

**flutter_test** — 56 тестов после этапа 7 (+12 `notification_service_test.dart` к 44 этапа 6): unit всех сервисов и модели + widget-тесты приложения и карточки (`word_card_test.dart`: поля карточки, тёмная тема, бейджи×3, метка «из виджета», влезание на экран 320×480). Этап 8 — только ресурсы (PNG, векторы, дескриптор): тесты не менялись. Этап 9 — +9 `pronunciation_service_test.dart` и +4 в `word_card_test.dart` (кнопка прослушивания). Этап 10 — тесты переведены на en-ожидания AppLocalizations (локаль тестового окружения en, количество тестов сохранено): 69/69 зелёные. Нативная логика — 7 JVM-тестов `WordOfDayCalculatorTest` (`cd android; gradlew :app:testDebugUnitTest`).

**Фейк бэкенда** — `FakeHomeWidgetBackend` в `widget_sync_service_test.dart`: проверка контракта 6 ключей (5 полей + `word_db_json`, пишется один раз) без плагина.

**Фейковые часы** — подмена `DateTime.now()` в тестах WordOfDayService: фиксированные даты вместо «сегодня».

**Мок MethodChannel** — подмена обработчиков обоих каналов плагина в `widget_test.dart` + демонтаж приложения в конце (чистота между тестами).

**Тест-векторы Dart/Kotlin** — одинаковая таблица дат для N=160 (1999-12-31→31 … 2027-01-01→21) в `word_of_day_service_test.dart` и `WordOfDayCalculatorTest.kt` против расхождения формулы (риск §9-4); при изменении N пересчитать в обеих сторонах одновременно.

**Fake-async и реальный IO** — урок этапа 12: внутри `testWidgets` реальный асинхронный IO (`File.exists()`, `Directory.createTemp()` с await) никогда не резолвится — тест висит. Правила: (1) файловый IO сервисов, вызываемых из build/фutures экрана, делать синхронным (`existsSync`/`copySync` — исполняется в микрозадаче, детерминированно); (2) в самих тестах — `createTempSync`/`writeAsBytesSync` либо `tester.runAsync` (как в `widget_test.dart` для чтения ассета).

**flutter analyze** — статический анализ (flutter_lints); должен быть без замечаний перед каждым коммитом.

## 11. Сборка и окружение

**Flutter SDK ^3.13.4, Material 3** — seed-цвет тем — зелёный `#4CAF50` (редизайн этапа 10; до этого индиго `#3F51B5`), только светлая тема (`ThemeMode.light`) + янтарный акцент; внешний state-management не используется: `StatefulWidget` + `ValueNotifier`. Локализация (этап 10) — `flutter_localizations` (sdk) + `intl` (версию пинит flutter_localizations), генерация `flutter gen-l10n` по `l10n.yaml`.

**Gradle Kotlin DSL** — `android/*.gradle.kts`; **desugaring** включён в `app/build.gradle.kts` (благодаря ему `java.time.LocalDate` работает и на Android < 26).

**JAVA_HOME** — прямой запуск `gradlew.bat` требует валидный JAVA_HOME; системный указывал на удалённый JDK, рабочее значение — JBR Android Studio (`C:\Program Files\Android\Android Studio\jbr`). `flutter build …` находит JDK сам.

**Сборка и установка** — `flutter build apk --debug` и `flutter build apk --release` (релиз подписан debug-ключом — `signingConfig debug` в `app/build.gradle.kts`, для локальных приёмочных сборок; боевой keyStore — за рамками v1.0), установка через `adb install --user 0 -r`; приёмочные проверки — на RMX2001 / Android 11.

**Права манифеста (этап 8)** — `aapt dump permissions` релизного APK: `INTERNET` отсутствует (в debug он появляется из оверлея `src/debug` Flutter — норма отладки). Merged-права релиза: наши `RECEIVE_BOOT_COMPLETED` + `POST_NOTIFICATIONS`; `VIBRATE` — flutter_local_notifications; `WAKE_LOCK`, `ACCESS_NETWORK_STATE`, `FOREGROUND_SERVICE` — androidx.work:work-runtime 2.11.2, который транзитивно тянет androidx.glance 1.2.0 (поддержка Glance-виджетов в home_widget 0.10.0, нами не используется). Сетевого доступа не даёт ни одно — DoD «ноль сетевых прав» трактуем как «нет `INTERNET` и прав, дающих трафик».

**Swift Package Manager (iOS)** — с Flutter 3.35 новый шаблон `ios/` не использует CocoaPods: Podfile отсутствует, плагины подтягивает SPM через `ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage` (этап 11; генерат обновляет `flutter pub get`, `ephemeral/` в git не попадает).

**Windows-станция и iOS** — `flutter build ipa` требует macOS+Xcode; на Windows валидация iOS-части статическая: `flutter analyze`/`flutter test` зелёные + SPM-резолв. Ручная приёмка — `docs/QA_CHECKLIST.md` §10 (при доступе к Mac).

**Стиль коммитов** — subject `Этап N: …` + тело из буллетов `•`.

## 12. Процесс

**PLAN.md** — единый источник правды: решения §1, стек §2, структура §3, данные §4, формула §5, нативная логика §6, уведомления §7, этапы §8, риски §9, DoD §10.

**Этапы 0–18** — 0: каркас; 1: модель и словарь; 2: формула; 3: нативный виджет (статика); 4: мост Flutter↔виджет; 5: автономная смена; 6: UI; 7: уведомления; 8: QA и полировка; 9: произношение (системный TTS); 10: локализация en/ru/id + редизайн (зелёная палитра, light-only, бренд «Word of Day»); 11: iOS (каркас, адаптивный UI, Darwin-уведомления, задел WidgetKit); 12: фото-ассоциации к словам (image_picker + path_provider); 13: избранное (идея B-002: FavoriteService + звезда + экран списка и карточка избранного слова); 14: квиз-повторение (B-006); 15: шеринг карточки (B-001); 16: свой пример (B-003); 17: preload-экран приветствия (B-009); 18: выбор языка интерфейса — en/ru/id/de/fr/es (B-005 часть 1). Текущий статус — таблица §8 PLAN.md.

**Definition of Done (§10)** — офлайн-смена слова ±30 мин без запуска приложения, тап → карточка дня, темы по системе, зелёные analyze/test, релизный APK, ноль сетевых прав; iOS — статическая валидаемость каркаса, сборка/QA на Mac.

## 13. iOS (этап 11)

**Каркас ios/** — сгенерирован `flutter create --platforms=ios --org com.english.widget .` (bundle id `com.english.widget.engWidgetApp`, deployment target iOS 15.0). Собственного Swift-кода нет — только шаблонные AppDelegate/SceneDelegate; все платформенные отличия живут в Dart.

**CFBundleDisplayName / InfoPlist.strings** — имя приложения: «Word of Day» в самом `Info.plist` (базовая en-локаль), «Слово дня»/«Kata Hari Ini» — в `ru.lproj/`/`id.lproj/InfoPlist.strings` (механизм локализации plist-ключей iOS). `CFBundleLocalizations` en/ru/id сообщает системе список поддерживаемых языков.

**URI-схема wordoftheday (iOS)** — `CFBundleURLTypes` в Info.plist: приложение открывается по `wordoftheday://word?date=…` — тот же контракт, что у Android-виджета и payload уведомления; на iOS его будет использовать будущее WidgetKit-расширение (home_widget: `homeWidgetURL`). Проверка на симуляторе: `xcrun simctl openurl booted "wordoftheday://word?date=2026-09-27"`.

**App Group** — `group.com.english.widget.engWidgetApp` (константа `WidgetSyncService.iosAppGroupId`): общий контейнер UserDefaults — единственный способ передать данные приложения WidgetKit-расширению. `PluginHomeWidgetBackend` применяет `HomeWidget.setAppGroupId` лениво, один раз перед первой записью (на Android вызов — no-op). Сама группа включается в Xcode → Runner → Signing & Capabilities → App Groups.

**DarwinInitializationSettings / DarwinNotificationDetails** — iOS-ветки flutter_local_notifications: маленькая статусбарная иконка не нужна (система показывает иконку приложения); запросы разрешений внутри initialize отключены (дефолты Darwin* — true) — системный диалог показывается ровно один раз из `requestPermission()` через `requestPermissions(alert: true, sound: true)`; в деталях уведомления — `presentAlert`/`presentSound` true, `presentBadge` false. Boot-восстановление расписания не нужно: iOS сама хранит запланированные UNNotificationRequest после перезагрузки (в отличие от Android, где свой ресивер плагина).

**platform_widgets.dart** — адаптивные хелперы этапа 11. `isAppleStyle(context)` = `Theme.of(context).platform == TargetPlatform.iOS` — именно платформа темы, а не `dart:io` `Platform.isIOS`: так iOS-ветки покрываются widget-тестами (`ThemeData(platform: TargetPlatform.iOS)`), а не только реальными устройствами. Состав: `PlatformAppBar` (CupertinoNavigationBar ↔ AppBar), `PlatformProgressIndicator` (CupertinoActivityIndicator ↔ CircularProgressIndicator), `PlatformIconActionButton` (CupertinoButton 44×44 по HIG ↔ IconButton с tooltip; SF Symbols через `CupertinoIcons`), `platformErrorIcon`. Полная пара Material/Cupertino-экранов не нужна: экраны текстовые, расходятся только эти элементы.

**Single-size app icon** — формат Xcode 14+: один PNG 1024×1024 в `AppIcon.appiconset/` (`"idiom": "universal", "platform": "ios"` в Contents.json), остальные размеры деривирует акткомпилятор. Глиф «W.» нарисован GDI+ по координатам Android-вектора `ic_launcher_foreground.xml` (зелёный квадрат `#4CAF50`, белый штрих, янтарная точка); iOS маскирует иконку superellipse сам — квадрат без прозрачности и скруглений.

**WidgetKit** — нативные виджеты iOS (SwiftUI TimelineProvider). Вне v1.0: требует Mac/Xcode и отдельный extension-таргет; Dart-сторона подготовлена (URI-схема + App Group) — появившись, расширение прочитает те же ключи из общего UserDefaults.

## 14. Фото-ассоциация (этап 12)

**Фото-ассоциация** — картинка пользователя, привязанная к записи словаря: визуальный мнемонический якорь («своя картинка к слову дня»). Хранится в `documents/word_images/{id}.jpg` — ключ `id` записи, а НЕ дата: ассоциация переживает ежегодные повторы слова формулой §5. Одно фото на запись, повторный выбор перезаписывает файл.

**WordImageService** (`lib/services/word_image_service.dart`) — выбор/хранение/удаление фото: `capture(id, source)` (копирует кэш image_picker в целевой файл и удаляет кэш), `imageFor(id)`, `remove(id)`. Ошибки плагина и файловой системы глотаются с debugPrint (карточка обязана работать без фото). Файловый IO синхронный — см. «Fake-async и реальный IO» в §10.

**ImagePickerBackend / PluginImagePickerBackend** — обёртка над `image_picker` (паттерн `HomeWidgetBackend`/`TtsBackend`): `pick(WordImageSource)` с параметрами сжатия `maxWidth: 1600, imageQuality: 85` (JPEG). `WordImageSource` — свой enum (camera/gallery), типы плагина наружу не светятся.

**Права фото-фичи** — Android: ноль новых прав — галерея открывается системным Photo Picker/ACTION_GET_CONTENT, камера — интентом ACTION_IMAGE_CAPTURE (без `CAMERA` в манифесте runtime-запрос не нужен; `aapt dump permissions` не меняется). iOS: `NSCameraUsageDescription`/`NSPhotoLibraryUsageDescription` в `Info.plist` обязательны (без них приложение падает при открытии пикера; App Store требует) + ru/id в `InfoPlist.strings`.

**showImageSourcePicker** (`lib/ui/widgets/image_source_sheet.dart`) — первый по-настоящему платформенно-расходящийся диалог приложения: iOS — `CupertinoActionSheet` (HIG: actions + Cancel), Android — `showModalBottomSheet` (ListTile ×2). Контракт: true — камера, false — галерея, null — отмена; ветвление через `isAppleStyle` (§13).

**_WordCardData** — приватная пара «запись + путь фото» в `home_screen.dart`: FutureBuilder грузит слово и фото одним future (кэш по дате — карточка не мигает пустой секцией), а замена/удаление фото подменяют future в кэше без перезагрузки слова.


## 15. Избранное (этап 13)

**FavoriteService** (`lib/services/favorite_service.dart`) — коллекция слов «на вернуться»: JSON-файл `documents/favorites.json` (паттерн `WordImageService` этапа 12: инжектируемый каталог documents, после резолва — синхронный файловый IO, тихие ошибки). Запись `Favorite` — `id` записи словаря + дата добавления; ключ `id`, а не дата/слово: избранное переживает годовые повторы формулой §5. Состояние — публичный `ValueNotifier<List<Favorite>>` (порядок «старые → новые»): карточка дня и список избранного слушают один нотифаер — звезда и список синхронны без ручных перезагрузок (домашний паттерн `isSpeaking` у `PronunciationService`). Стартовое чтение стартует в конструкторе (`unawaited(load())`), `load()` мемоизирован (`_loading ??= …`) — повторные вызовы ждут тот же future, `_mutate` сначала `await load()`.

**Экраны** — `FavoritesScreen` (список свежими сверху, тап → карточка, удаление свайпом Dismissible + контекстное меню, пустое состояние со звездой-заглушкой) и `WordDetailScreen` (полная карточка избранного слова: TTS, фото-ассоциация, снятие звезды). Сервисы передаются из `HomeScreen` — состояние и кэш едины с карточкой дня.

**Звезда в WordCard** — `Icons.star_outline_rounded` ↔ залитая янтарным (`Colors.amber`) `Icons.star_rounded`; `onToggleFavorite == null` → звезды нет (как `onListen` у TTS). Внимание M3: `IconButton` красит глиф собственным style — контракт цвета проверять по `IconButton.color` виджета, а не по `IconTheme` контекста иконки.

**Widget-тесты полного приложения и «отравление» `flutter/assets`** — главный урок этапа. Платформенный ответ каналу `flutter/assets` (чтение `rootBundle` — словарь карточки) в widget-тестах доставляется только внутри `runAsync`-зон реального времени. Приложение, запущенное в ПЕРВОМ `testWidgets` файла, оставляет недокрученные фьючерсы чтения ассета — после завершения теста платформа (flutter_tester) перестаёт отвечать каналу `flutter/assets` ВООБЩЕ: любой следующий тест файла, запускающий приложение, висит на вечном спиннере карточки (FutureBuilder ждёт словарь). Мок `setMockMethodCallHandler`/`setMockMessageHandler('flutter/assets')` НЕ перехватывает это чтение, кэш `rootBundle` между тестами не выручает. Диагностировано зондами: `path_provider`-канал при этом жив (моки работают), изолированный тест один проходит за 1 итерацию pump, пара «тест 1 → тест 2» падает всегда — независимо от того, полный `WordOfTheDayApp` или голый `MaterialApp(home: HomeScreen())`. **Паттерн: все сценарии одного приложения в файле — ОДИН `testWidgets`** (загрузка → слово дня → звезда → список избранного → назад); межтестовых перезапусков приложения в одном файле не делать. Компонентные тесты (WordCard, FavoritesScreen с готовыми данными) от этого не страдают — моки `mockAppChannels()` (home_widget ×2 + path_provider → temp-папка с `addTearDown`) достаточно.

## 16. Квиз-повторение (этап 14)

**QuizService** (`lib/services/quiz_service.dart`, идея B-006) — две зоны ответственности. (1) Цикл «каждые 3 дня» и результаты: файл `documents/quiz_results.json` (паттерн этапа 13: инжектируемый каталог documents, синхронный IO, тихие ошибки) хранит историю прохождений (последние 50: `finishedAt`/`total`/`correct`/`wrongIds`); `lastResult` — `ValueNotifier`, `nextQuizDate` = дата последнего квиза + 3 дня, `isDue(now)` — календарное сравнение дат; `recordResult` дописывает историю и зовёт публичный колбэк `onQuizFinished(nextQuizDate)` — main.dart по нему перепланирует напоминание. (2) Генерация вопросов — чистая статика `generate(questionPool, dictionary)`: экран кормит пулом (избранное, свежие первыми), при нехватке до 5 вопросов добор случайными записями словаря; вопрос = запись + 4 уникальных перевода (верный + дистракторы, сначала того же типа «слово к слову»), `Random` инжектируется тестами. Сервис не зависит от DictionaryService/FavoriteService — поэтому один экземпляр создаётся в `main.dart` и передаётся вниз (HomeScreen → QuizScreen).

**Одноразовое уведомление** — `NotificationsBackend.scheduleOneShot`: `zonedSchedule` БЕЗ `matchDateTimeComponents` (ежедневное слово дня, §8, повторяется нативно само; напоминание квиза — нет). Следствие: расписание не самовосстанавливается — `NotificationService.rescheduleQuizReminder(nextQuizDate)` зовут 4 триггера: старт, резюм, полуночный таймер и `onQuizFinished`. Отмена+постановка (id 2, канал `quiz`, время 10:00 — на час позже слова дня, чтобы не конкурировать); null (квизов не было) — только отмена: напоминать до первого прохождения нечего; дата в прошлом (приложение долго не открывалось) — ближайшее будущее 10:00 (сегодня/завтра).

**Payload `wordoftheday://quiz`** — расширение URI-контракта виджета: парсер `dateFromWidgetUri` его честно не понимает, поэтому ветка квиза проверяется раньше (тап-хендлер NotificationService и холодный старт в main.dart); тёплый старт — колбэк `onOpenQuiz` → `ValueNotifier<bool> _quizOpenRequest` в main.dart → HomeScreen слушает (в т.ч. стартовое true через `addPostFrameCallback` — ValueNotifier дёргает листенеры только изменениями) и открывает QuizScreen.

**QuizScreen** — конечный автомат фаз loading/questions/result/empty; ответ подсвечивается (верно — primaryContainer + галочка, выбранная ошибка — errorContainer + крестик; кнопки блокируются), `Timer(900 мс)` ведёт к следующему вопросу (отменяется в dispose — паттерн полуночного таймера). Результат: счёт, «слова на повторение» (записи с ошибками), локализованная дата следующего квиза, «Ещё раз» (перегенерация) и «Готово». Вход — иконка в AppBar рядом со звездой.

**Добор материала** — квиз доступен и с пустым избранным (вопросы собираются из словаря целиком): первый квиз не требует подготовки, избранное лишь приоритизирует материал (карточка B-006: «если в избранном < 4 слов — добирать из словаря»); «мало слов» возможен только на крошечном словаре < 4 уникальных переводов — пустое состояние с подсказкой.

## 17. Шеринг карточки (этап 15)

**CardShareService** (`lib/services/card_share_service.dart`, идея B-001) — шеринг карточки картинкой: кнопка `onShare` в `WordCard` → `sharePoster(context, poster, text)` — растеризация постера в PNG (1080×1350, `pixelRatio 3` от логического 360×450/4:5), запись в `temp/wordofday_card.png` (перезапись, синхронный `writeAsBytesSync` — паттерн этапа 12) и отдача в системный share sheet. Сервис «тихий» (`_quietly` — ошибка рендера/файла/плагина не роняет карточку), состояния не держит — экраны создают его полем без dispose (свой в `HomeScreen` и `WordDetailScreen` — сигнатуры соседей менять не нужно).

**ShareBackend / SharePlusBackend** — паттерн `TtsBackend` (этап 9): плагин скрыт за интерфейсом `shareFile(path, {text})`; прод — `share_plus ^13.3.1` (решение владельца 03.10.2026; нативный MethodChannel отклонён — iOS без Mac). API мажора 10+: `SharePlus.instance.share(ShareParams(files: [XFile(path)], text: ...))` — статические `Share.share*` deprecated. Плагин сам мержит в манифест свой `FileProvider` (прав НЕ добавляет — проверяется `aapt dump permissions`); действие `ACTION_SEND` на Android, `UIActivityViewController` на iOS.

**Рендер постера за экраном** — постер обязан побывать в дереве, иначе `toImage` не найдёт слоя: `CardShareService.renderPosterPng` вставляет `OverlayEntry` (корневой оверлей, `Positioned` за правым краем: `right: -width - 8`) с `RepaintBoundary`, ждёт `SchedulerBinding.instance.endOfFrame` (если `debugNeedsPaint` — ещё кадр), растеризует `boundary.toImage(pixelRatio: 3)` → `toByteData(format: png)`, и убирает entry в `finally` (а `image.dispose()` — после `toByteData`). Виджет-постер при этом невидим пользователю.

**SharePoster** (`lib/ui/widgets/share_poster.dart`) — брендированный постер 360×450: бейдж типа + слово (`FittedBox(fit: scaleDown)` — длинный фразовый глагол ужимается одной строкой) + IPA + перевод (`maxLines 4` + ellipsis) + глиф «W» на зелёном круге и «Word of Day». Цвета — явные константы светлой палитры (#F1F8E9/#1B5E20/#52705C/#2E7D32), НЕ Theme: постер обязан выглядеть одинаково при любой теме окружения (приложение light-only) и в тестах; подпись и цвета бейджа — статические `TypeBadge.labelFor/backgroundFor/foregroundFor` (легенда типов едина).

**Тестирование растеризации** — дополнение к уроку §10 о fake-async: движковый реальный async (`RenderRepaintBoundary.toImage`/`toByteData`) внутри `testWidgets` виснет так же, как async-IO — ждать его нужно в `tester.runAsync` (паттерн golden-тестов). Поэтому в `CardShareService` инъектируется `renderer` (прод — `renderPosterPng`): пайплайн «постер → файл → бэкенд» тестируется на фейк-рендерере, а сама растеризация — отдельным widget-тестом с `runAsync` (PNG-подпись `89 50 4E 47` + объём > 1000 байт).

**Текст шеринга** — вместе с картинкой уходит текст «слово — перевод» (`ShareParams.text`): мессенджеры прикрепляют подпись к изображению; бренд на самой картинке, ссылок в v1 нет (магазина/сайта ещё не существует).

## 18. Свой пример к избранному (этап 16)

**UserExampleService** (`lib/services/user_example_service.dart`, идея B-003) — личный пример употребления к избранному слову («где я встретил это слово»): текст до 300 символов (`maxLength` — ассоциация, а не сочинение), хранится в `documents/user_examples.json` — `{"version":1,"items":[{"id","text"}]}`. Ключ — `id` записи, как у фото этапа 12: пример переживает удаление слова из избранного и повторное добавление; схему `favorites.json` НЕ трогаем. Состояние — `ValueNotifier<Map<int, String>>`; `save(id, text)` тримит и обрезает по 300, пустой текст = удаление (пустых записей не бывает); `remove(id)`; `textFor(id)`. Паттерн этапа 13 целиком: стартовое чтение в конструкторе, мемоизированный `load()`, синхронный IO после резолва documents (детерминирован в fake-async), тихие ошибки (`_quietly`-семантика: нет path_provider / битый JSON / мусорные элементы → тихая пустая карта, UI живёт), `dispose` гасит нотифаер.

**_UserExampleSection** (`word_detail_screen.dart`) — секция под карточкой избранного слова; на карточке дня и виджете её нет (контракт §6). Состояние — единственный `TextEditingController?`: null — просмотр (нет примера → `OutlinedButton` «добавить», есть → текст + «изменить»/«удалить» адаптивными `PlatformIconActionButton`), не-null — inline-редактор: многострочный `TextField` (`maxLength` 300, autofocus) + «Сохранить»/«Отмена»; пустой ввод сервис трактует как удаление — кнопка сохранения всегда валидна. Показ — `ValueListenableBuilder` над `examples`: секция перерисовывается сразу, а «перезапуск» покрывает стартовое чтение конструктора. Оформление — `Card.filled` без полей, padding 20 — карточка и секция читаются одним стеком контента. Владелец сервиса — `HomeScreen` (один на приложение), пробрасывается в `FavoritesScreen` → `WordDetailScreen` — как `FavoriteService` этапа 13.

## 19. Preload-экран приветствия (этап 17)

**WelcomeScreen** (`lib/ui/screens/welcome_screen.dart`, идея B-009) — preload-экран на холодном старте обычного запуска: центр — глиф «W.» (зеркало иконки лаунчера, этапы 8/10) и бренд «Word of Day» — оба системным serif («словарная» серьёзность вместо Roboto, правка по итогам приёмки 03.10.2026; теглайн остаётся sans — контраст) — плюс короткий английский теглайн «A new English word every day» (не переводим, как бренд; правки приёмки: всегда английский, без «— офлайна» и без обещания произношения — качество системного TTS в слоган не выносим; ключ `welcomeTagline` из ARB удалён; теглайн за `ConstrainedBox(maxWidth: 320)` — длинная строка переносится по центру в ≤2 строки, а не растягивается на весь экран). Вся композиция стоит на колонке во всю ширину экрана (`SizedBox(width: double.infinity)`): `Column` по умолчанию сжимается по ширине самого широкого ребёнка — когда теглайн стал коротким, центральный блок вместе с логотипом уехал к левому краю; поймано геометрическим тестом (`test/welcome_screen_layout_test.dart`) после жалобы приёмки 03.10.2026; низ — логотип студии `assets/brand/logo.jpg` кружком с окантовкой (проявляется позже — иерархия «сначала приложение, потом студия»; ассет за `errorBuilder`: битый/недоступный файл тихо пуст). Анимация — один `AnimationController` 2,5 с (растянута с 1,5 с по правке приёмки 05.10.2026: дольше держит бренд; fade+scale центрального блока, отдельный fade логотипа); доигрывание или тап в любую точку зовут `onFinished` → `main.dart` переключает на карточку дня. Зона тапа подписана для скринридеров: `Semantics(label: welcomeSkip, button: true)` — «Пропустить/Skip/Lewati». Экран без собственной навигации и состояния приложения — тонкий, как карточка.

**Гейт первого кадра** — решение «показывать ли приветствие» в `main.dart`: стартовые источники (URI виджета `initiallyLaunchedFromHomeWidget` + payload уведомления `launchNotificationPayload`) читаются асинхронно, поэтому до их резолва `home:` — пустой `Scaffold` на фоне `#F1F8E9` (scaffold приложения = `launch_bg_color` нативного сплэша — смены картинки не видно, вспышки нет; резолв — миллисекунды). Валидный URI/payload помечает запуск дееплинком (`_launchedFromDeeplink`) → сразу `HomeScreen`/квиз, без приветствия; обычный запуск → `WelcomeScreen`. Оба фьючерса завершаются через `catchError`+`whenComplete` — ошибка плагина не может вечно держать гейт (третий слой тишины поверх `_quietly`-паттернов этапов 7/9). Показ всегда на холодном старте — решение триажа 03.10.2026, счётчик запусков не нужен; тёплый старт (резюм) гейт не касается — приветствие живёт только в первом `home:` приложения.

## 20. Единый язык приложения (этапы 18–19; правка приёмки 05.10.2026)

**SettingsService** (`lib/services/settings_service.dart`, идея B-005) — единый язык приложения (интерфейс + переводы слов + виджет + уведомление): JSON `documents/settings.json` **v3** (правка приёмки 05.10.2026): `appLanguage` = `system` | код (`en|ru|id|de|fr|es`) + флаги онбордингов `languagePromptShown` / `onboardingShown` (гейт этапа 20). Паттерн этапа 13 целиком (инжектируемый documents, после резолва — синхронный IO, мемоизированный `load`, тихие ошибки, `dispose`). Один публичный нотифаер `appLanguage` (`ValueNotifier<String>`); геттер `locale`: `system` → null = обычная резолв MaterialApp (включая канонизацию legacy-кода Android `in`→`id`), иначе `Locale(code)`; геттер `isLoaded` — стартовое чтение завершилось (гейты онбордингов не спрашивают до чтения файла). **Миграция v1/v2 → v3** (`_decode`, чтение): приоритет — выбору языка интерфейса (`interfaceLanguage` ≠ `system` → он; иначе `translationLanguage` ≠ `ru` → он; иначе `system`), оба флага → `true` (приложением уже пользовались — онбординги не показываем повторно); любая запись после чтения пишет v3. Валидация одна на чтение и запись: не строка / неизвестный код → `system`. Чистые статические резолвы (тестируются без платформы, platformDispatcher в юнит-тестах не трогают): `interfaceLanguageForSystemLocale(locale)` — канонизация `in`→`id`, неподдержанная → `en`; `resolveTranslationLanguage(appLanguage, systemLocale)` — ручной выбор сам (`en`→`ru`: английских переводов в словаре нет, приложение учит английскому), `system` → язык системной локали, если словарь его переводит, иначе `ru`; `shouldPromptLanguage(...)` — гейт онбординга языка (один раз, только в режиме `system`, только при en/неподдержанной локали). Инстанс-геттеры `effectiveTranslationLanguage` / `needsLanguagePrompt` — те же резолвы по `platformDispatcher.locale`.

**kInterfaceLanguages** — единственная точка расширения: 6 пар «код + аутоним», en первый («English», «Русский», «Bahasa Indonesia», «Deutsch», «Français», «Español»). Аутонимы не переводятся и в ARB не живут — одинаковы во всех локалях; новый язык = ARB-файл `app_xx.arb` (+ нативные строки по образцу существующих), переводы в словаре v2 и одна строка в списке: валидация, пикеры и тест-«сентинел» читают его. en в списке (правка приёмки 05.10.2026): он и template-фолбэк локализации, и выбираемый язык — интерфейс English, переводы слов остаются русскими; подпись «переводы слов: Русский» (`settingsEnglishTranslations`, аутоним передаётся параметром) говорит об этом честно в настройках и на онбординг-пикере.

**SettingsScreen** (`lib/ui/screens/settings_screen.dart`) — stateless: состояние в нотифаере сервиса, тап сразу пишет (`setAppLanguage`). Одна секция «Язык» (правка приёмки 05.10.2026 — вместо двух секций этапов 18/19): «Как в системе» (подпись `settingsLanguageSystemDetails` — что реально дала бы системная локаль: язык интерфейса + язык переводов, по `platformDispatcher.locale`, т.к. `Localizations` уже отражает ручной выбор) + 6 языков аутонимами; у выбранного галочка `Icons.check_rounded` (одна на секцию). Вход — шестерёнка крайняя справа в AppBar (`PlatformIconActionButton`); сервис приходит из `HomeScreen`, владелец — `main.dart` (один на приложение).

**LanguagePickScreen** (`lib/ui/screens/language_pick_screen.dart`) — онбординг-пикер языка (правка приёмки 05.10.2026): один раз при первом запуске, когда системная локаль en/неподдержанная (`needsLanguagePrompt`), показывается после `WelcomeScreen` (гейт в `main.dart`: `_settings.isLoaded && needsLanguagePrompt` — не спрашиваем до чтения settings.json; дееплинк-старт тоже проходит через вопрос). `PopScope(canPop: false)` — выбор обязателен; тап = `setAppLanguage` + `markLanguagePromptShown` + пересборка гейта (`onDone`). Экран при показе всегда локализуется по en (иначе вопрос не понадобился бы).

**Проводка в main.dart** — один слушатель `_onAppLanguageChanged` (setState + re-sync виджета + `rescheduleDailyNotification`; срабатывает и на стартовое чтение файла: сохранённый выбор ≠ `system` доспанивает всё после загрузки) + `WidgetsBindingObserver.didChangeLocales` (режим «как в системе»: смена системного языка на лету — перерисовать и доспанить карточку/виджет/уведомление; при ручном выборе ранний выход) + `load().then(setState)` (гейты онбордингов оцениваются после чтения файла).

**Урок правки приёмки (05.10.2026): template-фолбэк локализации — НЕ первая supported-локаль.** `flutter gen-l10n` отдаёт `supportedLocales` отсортированными (первая — `de`!), и стандартная `basicLocaleListResolution` со этапа 18 выбирала бы неподдержанным системным локалям (ko, kk…) немецкий интерфейс. Лечится `localeResolutionCallback` в MaterialApp: `Locale(interfaceLanguageForSystemLocale(deviceLocale))` — en для неподдержанных (ручной выбор идёт мимо колбэка: `locale:` не-null). Старые тесты это не ловили: проверяли аутоним «English» в подписи настроек, а он от l10n-локали не зависит. В тестах колбэк нужно зеркалить в голый `MaterialApp` харнесса.

**Локали de/fr/es** — ARB-файлы новые (правка приёмки: +5 ключей `settingsLanguage`, `settingsLanguageSystemDetails`, `settingsEnglishTranslations`, `languagePickTitle`, `languagePickSubtitle`, −2 старых; en — шаблон с @метаданными, остальные компактные). Нативные строки: Android `values-de/-fr/-es/strings.xml` (имя и описание виджета, пустой плейсхолдер; `app_name` — бренд без перевода) + iOS `de/fr/es.lproj/InfoPlist.strings` (CFBundleDisplayName + описания камеры/галереи). Ограничение этапа 18 «уведомления и виджет следуют системной локали» снято этапом 19 (следуют выбранному языку) и правкой приёмки 05.10.2026 (в режиме «как в системе» — системной локали, включая смену на лету). **Тестовые уроки этапа:** (1) WidgetsApp резолвит локаль по СПИСКУ локалей — в тестах ставить и `localeTestValue`, и `localesTestValue`; (2) `tester.pageBack()` ищет кнопку по en-тултипу «Back» — на другой локали тапать `find.byType(BackButton)`; (3) свежая установка в e2e (`widget_test.dart`, `mockAppChannels`) — предзаписать settings.json с флагами онбордингов, иначе гейт пикера языка перехватывает маршрут; (4) резолвы системной локали вынесены в статику сервиса — юнит-тесты не трогают platformDispatcher.

## 21. Язык переводов слов (этап 19, B-005 часть 2)

**Словарь v2** (`assets/words_db.json`, `"version": 2`) — в каждой из 160 записей карты `translations` / `example_translations` (ключи `ru,id,de,fr,es`; `translations.ru` — копия v1-поля `translation`, аналогично для примера). `WordEntry` (v2-модель) парсит карты lenient-ом (кривые/пустые значения отбрасываются, `Map.unmodifiable`), `translationFor(code)` / `exampleTranslationFor(code)` — фолбэк на русские поля v1; `toJson` не пишет пустые карты — v1-сериализация байт-в-байт (Kotlin-сторона этапа 5 читает v1-ключи как раньше). Миграция — одноразовый `tool/merge_translations.dart` (данные `tool/v2_words.txt` / `v2_examples.txt`, формат строки `id|id|de|fr|es`, лимиты 60/90 символов проверяются скриптом и валидацией перед записью; скрипт идемпотентен, ru всегда берёт из актуальных v1-полей). Тест-гард целостности — в `word_entry_test.dart`: все 5 языков × 160 записей, `translations.ru == translation`, лимиты длин.

**Проводка перевода** — везде опциональный параметр `translationLanguage` (дефолт `'ru'` = прежнее поведение, старые тесты зелёные без правок): `WordCard` (перевод + пример), `SharePoster` + share-текст (Home/WordDetail), списки избранного и «слов на повторение», `QuizService.generate(translationLanguage: …)` — варианты и `correctIndex` считаются на выбранном языке, `NotificationService.start/rescheduleDailyNotification` — тело уведомления. Источник значения — `_settings.effectiveTranslationLanguage` (правка приёмки 05.10.2026: ручной выбор или системная локаль в режиме «как в системе»; `en` → русский): читатели в `build` (`HomeScreen` и экраны), слушатель `main.dart` `_onAppLanguageChanged` — setState + re-sync виджета + перепланирование уведомления (срабатывает и на стартовое чтение файла: сохранённый выбор ≠ `system` доспанивает всё после загрузки настроек). Тестовый урок: после правки приёмки секция языка в настройках одна — 7 тайлов и одна галочка, уточнение секции (`.first`/`.last`) в e2e больше не нужно; `tester.ensureVisible` остался для тайлов ниже экрана.

**Контракт виджета — 7-й ключ** `widget.translation_lang` (в `widget.translation` уже перевод выбранного языка, фолбэк записи — русский). Kotlin `WordOfDayCalculator.entryFor(db, date, lang = "ru")` в автономном режиме берёт перевод из карты v2 (`optJSONObject("translations")`; нет карты/ключа/пусто → русское поле — паритет Dart-фолбэку); провайдер читает язык из prefs (нет ключа → `"ru"`). Тесты паритета — `WordOfDayCalculatorTest` (v2-мини-база: de есть / fr нет / пустое значение) ↔ `widget_sync_service_test.dart` (v2-мини-база, те же сценарии + тест «ровно семь ключей»).

