# PLAN.md — «Word of Day» (eng_widget_app)

> Мини-приложение Flutter + нативный виджет Android (домашний экран 4×2).
> Полностью ОФФЛАЙН: без сети, подписок и внешних API. Источник данных — локальный JSON-словарь.

## 1. Зафиксированные решения

| Область | Решение |
|---|---|
| Источник данных | Локальный `assets/words_db.json` (150–200 записей), генерируется заранее |
| Состав базы | 50% отдельных слов + 50% идиом и фразовых глаголов; уровни B1–B2 с сильным уклоном в современный разговорный английский |
| Поля записи | `word`, `transcription` (американская IPA), `translation` (1–2 значения через запятую), `example` (англ.), `example_ru` (рус.), `type` (`word` / `idiom` / `phrasal_verb`) |
| Слово дня | Детерминированное: `index = seed(дата) % N`; одно слово на весь календарный день, смена после полуночи; год входит в seed → последовательность «перемешивается» ежегодно |
| Виджет | Один широкий 4×2: слово, транскрипция, перевод, пример (обрезка до 2 строк); БЕЗ кнопок на виджете; тап → приложение с полной карточкой слова этого дня |
| Тема виджета | Авто: светлая/тёмная по системной теме (`values-night`); скруглённые углы (нативно Android 12+, drawable-фон для более старых) |
| Экран блокировки | Нативный виджет на lock screen телефонов невозможен (удалён в Android 5.0; в Android 16 QPR2 возвращён только для планшетов). Компенсация: ежедневное ЛОКАЛЬНОЕ уведомление (видно на lock screen) |
| UI v1.0 | Один экран: большая карточка слова дня; Material 3; язык интерфейса en/ru/id по локали устройства (этап 10; в исходном плане — русский); тёмная тема приложения убрана этапом 10 (light-only), виджет остаётся авто (свет/тьма по системе) |
| Произношение | Кнопка-динамик в карточке (этап 9): системный TTS-движок устройства (`flutter_tts`), язык фиксированный `en-US`, офлайн и без прав. Озвучивается только слово/фраза дня (не пример-предложение); на виджете звука нет (RemoteViews); нет движка/голоса en-US — кнопки нет (мягкая деградация) |
| Платформы | Android 7.0+ (minSdk 24) и iOS 15+ (этап 11): одно Dart-ядро, адаптивный UI (точечные Material/Cupertino-ветки в `platform_widgets.dart`), локальные уведомления и TTS на обеих ОС. Нативный виджет — только Android: WidgetKit требует Mac/Xcode (вне v1.0); Dart-задел — URI-схема `wordoftheday` и App Group `group.com.english.widget.engWidgetApp` |
| Фото-ассоциация | Своя картинка-ассоциация к слову дня (этап 12): камера или галерея через `image_picker` (сжатие на месте: maxWidth 1600, imageQuality 85), хранение `documents/word_images/{id}.jpg` — ключ `id` записи, а не дата: ассоциация переживает ежегодные повторы слова формулой §5; замена/удаление из карточки; на виджет не попадает. Android — ноль новых прав (системные intents/Photo Picker); iOS — usage-описания камеры/фотобиблиотеки |
| Сеть | Никаких сетевых запросов; `dio` удалить из зависимостей; в манифесте не должно быть прав на интернет |

**Допущения v1.0** (по умолчанию, легко меняется): уведомление в 09:00 локального времени (константа, настроек в v1 нет); палитра M3 — индиго (seed) + янтарный акцент; с этапа 10 — зелёный seed `#4CAF50` (редизайн под аудиторию Индонезии), тёмной темы приложения нет.

## 2. Стек технологий

- **Flutter / Dart**: SDK ^3.13.4 (уже настроен), Material 3, без внешнего state-management — `StatefulWidget` + `ValueNotifier`.
- **Пакеты**: `home_widget ^0.10.0` (уже в pubspec), `flutter_local_notifications ^22.3.1` (добавлен ✅ этап 0), `flutter_lints` (есть); `timezone ^0.11.1` + `flutter_timezone ^5.1.0` (добавлены ✅ этап 7 — IANA-зона устройства, по ней натив считает ежедневный повтор уведомления); `flutter_tts ^4.2.5` (добавлен ✅ этап 9 — системный TTS-движок Android для произношения: офлайн, без прав; в манифесте только `<queries>` с `TTS_SERVICE` — видимость движка на Android 11+, новых прав нет); `flutter_localizations` (sdk) + `intl` (добавлены ✅ этап 10 — локализация UI en/ru/id: ARB + `flutter gen-l10n` по `l10n.yaml`, генерат в `lib/l10n/generated/` коммитится; сторонние l10n-пакеты не привлекались); этап 11 подтвердил iOS-поддержку всех 4 плагинов (уведомления — Darwin*-ветки, TTS — AVSpeechSynthesizer); `image_picker ^1.2.3` + `path_provider ^2.1.6` (добавлены ✅ этап 12 — фото-ассоциация к слову дня: системная камера/галерея и каталог documents; на Android ноль новых прав — плагин использует intents/Photo Picker без `CAMERA`).
- **Нативная часть**: Kotlin + XML `RemoteViews`, `AppWidgetProvider`, `PendingIntent`, `SharedPreferences`, встроенный `org.json` (парсинг базы в нативном провайдере для автономной смены слова). iOS (этап 11) — только шаблонный Swift-каркас Runner (AppDelegate/SceneDelegate), собственного нативного кода нет; интеграция плагинов — Swift Package Manager (Podfile не нужен).
- **Тесты**: `flutter_test` — unit (парсинг JSON, формула слова дня), widget-тесты (карточка, экран).

## 3. Структура папок

```
lib/
  main.dart                        # MaterialApp, темы M3, HomeScreen
  models/
    word_entry.dart                # модель записи + fromJson/toJson + enum WordType
  services/
    dictionary_service.dart        # загрузка и кэш words_db.json (rootBundle, utf8)
    word_of_day_service.dart       # формула seed(дата) % N (единая с Kotlin)
    widget_sync_service.dart       # предзагрузка базы в prefs + save/update через HomeWidget
    notification_service.dart      # канал, расписание 09:00, permission-флоу
    pronunciation_service.dart     # TTS-произношение слова дня (этап 9)
  ui/
    screens/home_screen.dart       # экран карточки (+ приём даты из тапа по виджету)
    widgets/word_card.dart         # карточка: слово, IPA, перевод, пример + перевод
    widgets/type_badge.dart        # бейдж типа: word / idiom / phrasal_verb
assets/
  words_db.json                    # база 150–200 записей
android/app/src/main/
  AndroidManifest.xml              # + receiver виджета, права
  kotlin/com/english/widget/eng_widget_app/
    MainActivity.kt                # singleTop уже есть; тап с виджета приходит сюда
    WordWidgetProvider.kt          # onUpdate: сам пересчитывает слово дня из prefs
  res/
    layout/word_widget.xml         # RemoteViews-макет 4×2
    xml/word_widget_info.xml       # appwidget-provider метаданные
    drawable/widget_bg.xml         # скруглённый фон (fallback Android < 12)
    values/widget_colors.xml       # палитра светлой темы виджета
    values-night/widget_colors.xml # палитра тёмной темы виджета
    drawable-nodpi/widget_preview.png
test/
  word_entry_test.dart
  dictionary_service_test.dart
  widget_test.dart
  word_of_day_service_test.dart
  word_card_test.dart
  pronunciation_service_test.dart
```

## 4. Контракт данных — assets/words_db.json

```json
{
  "version": 1,
  "words": [
    {
      "id": 1,
      "word": "no-brainer",
      "transcription": "/ˌnoʊˈbreɪnər/",
      "translation": "очевидное решение, дело ясное",
      "example": "Skipping that meeting was a no-brainer.",
      "example_ru": "Пропустить эту встречу было очевидным решением.",
      "type": "idiom"
    }
  ]
}
```

Требования к базе:

- `version` — целое, для будущих миграций; `id` — уникальны и стабильны.
- `type` — строго `word` / `idiom` / `phrasal_verb`; распределение ~50% `word` / ~50% `idiom`+`phrasal_verb`.
- `transcription` — американская IPA в слэшах; `translation` — 1–2 значения, суммарно ≤ 60 символов (влезает в виджет 4×2).
- `example` — короткое предложение (≤ 90 символов), `example_ru` — его естественный перевод.
- Уровень B1–B2 + современный разговорный (doomscrolling, no-brainer, hang out, ghosting...).
- Кодировка UTF-8 без BOM; никакой разметки (HTML/Markdown) внутри строк.

## 5. Логика «слова дня» — единая формула для Dart и Kotlin

```
date  = локальная дата пользователя (yyyy-MM-dd)
seed  = yyyy * 10000 + MM * 100 + dd
index = seed mod words.length
```

- Формула преднамеренно тривиальна и реализуется ИДЕНТИЧНО в Dart (`DateTime.now()` → год/месяц/день) и в Kotlin (`java.time.LocalDate.now()`), чтобы нативный провайдер без запуска приложения показывал ровно то же слово, что и Flutter.
- Год входит в seed — 1 января последовательность автоматически «перемешивается».
- Смена слова происходит по ЛОКАЛЬНОЙ полуночи (без таймзон-математики — берём только календарную дату).
- Известное ограничение: чистый mod допускает редкие повторы одного слова в течение года — принято для v1.0 (см. §9).

## 6. Нативный виджет — детали

**Манифест** (`android/app/src/main/AndroidManifest.xml`):

- `<receiver android:name=".WordWidgetProvider" android:exported="false">` + intent-filter `android.appwidget.action.APPWIDGET_UPDATE` + `<meta-data android:name="android.appwidget.provider" android:resource="@xml/word_widget_info"/>`.
- Права: `RECEIVE_BOOT_COMPLETED` (обновить виджет после перезагрузки), `POST_NOTIFICATIONS` (runtime, Android 13+). `SCHEDULE_EXACT_ALARM` НЕ запрашиваем. Сетевых прав — нет.

**appwidget-provider** (`res/xml/word_widget_info.xml`): `targetCellWidth=4` / `targetCellHeight=2` (API 31+), `minWidth=250dp` / `minHeight=110dp` (4×2 для старых), `updatePeriodMillis=1800000` (30 мин — системный минимум), `widgetCategory=home_screen`, `resizeMode=none`, `initialLayout`, `previewLayout` (API 31+, иначе `previewImage`), `description`.

**Layout** (только вью, разрешённые в RemoteViews): вертикальный LinearLayout → слово (bold ~22sp) → транскрипция (~12sp, вторичный цвет) → перевод (~14sp) → пример (~12sp, `maxLines=2`, `ellipsize=end`, третичный цвет). Фон `@drawable/widget_bg` (скругление 16dp) + перекраска палитры через `values-night` — тема «авто». Android 12+ сам применяет системные скругления/отступы.

**Тап**: `setOnClickPendingIntent` → `HomeWidgetLaunchIntent` с URI `wordoftheday://word?date=yyyy-MM-dd`; Flutter ловит через `HomeWidget.initiallyStartedWithWidget()` / `HomeWidget.widgetClicked` → карточка именно этой даты (детерминизм §5 избавляет от передачи всей карточки).

**Автономная смена слова (полночь без запуска приложения)**: при первом запуске Flutter кладёт весь JSON базы в prefs (ключ `word_db_json`, через `HomeWidget.saveWidgetData<String>`); `WordWidgetProvider.onUpdate()` парсит его `org.json`, сам считает индекс по формуле §5 и рендерит RemoteViews. `updatePeriodMillis` гарантирует смену слова в пределах ~30 мин после полуночи; дополнительно — BOOT_COMPLETED-ресивер и обновление при каждом открытии приложения.

## 7. Уведомление «слово дня»

- `flutter_local_notifications`: канал `word_of_day`; ежедневное `zonedSchedule` на 09:00 локального времени, `androidScheduleMode: inexactAllowWhileIdle` (без разрешений на точные будильники).
- Заголовок «Слово дня — {word}», тело «{transcription} — {translation}»; тап → приложение. Этап 10: тексты, имя и описание канала локализованы (en/ru/id по локали устройства; id канала неизменяем, переименование — повторным `createNotificationChannel`).
- Запрос `POST_NOTIFICATIONS` на первом запуске (Android 13+); отказ — мягкая деградация: виджет продолжает работать; повторный запрос — не раньше следующего запуска.

## 8. Этапы разработки

> Статусы обновлены 27.09.2026 после завершения этапов 0–6 (Dart: `flutter analyze` чисто, `flutter test` — 44/44 зелёные; натив: 7/7 JVM-тестов, debug-APK собирается; ручная проверка виджета на устройстве ✓).

| Этап | Содержание | Критерий приёмки | Статус |
|---|---|---|---|
| 0. Чистка шаблона | Убрать `dio` из pubspec и счётчик из main.dart; добавить `flutter_local_notifications`; `flutter pub get` | `flutter analyze` без замечаний, `flutter run` показывает пустой scaffold | ✅ **Выполнен** (26.09.2026): `dio` удалён, `flutter_local_notifications ^22.3.1` добавлен, шаблонный счётчик заменён на `WordOfTheDayApp` + `HomeScreen`-заглушку; `pub get`/`analyze` чисто. Рендер проверен widget-тестом; запуск на устройстве перенесён в этап 8 (QA) |
| 1. Данные | Сгенерировать `assets/words_db.json` (150–200 записей по §4); регистрация ассета; `WordEntry` + `DictionaryService` (кэш) | Unit-тест: все записи валидны, id уникальны, типы ~50/50 | ✅ **Выполнен** (26.09.2026): база 160 записей = 80 слов / 55 идиом / 25 фразовых (50 % / 34 % / 16 %), id 1–160 подряд; ассет зарегистрирован в pubspec; модель + сервис (UTF-8 через rootBundle, кэш, обработка ошибок); тесты `word_entry_test` + `dictionary_service_test` зелёные |
| 2. Слово дня | `WordOfDayService` по формуле §5 + тест-векторы | Тесты: слово стабильно весь день; меняется на следующий день; индекс совпадает с эталоном для фиксированных дат | ✅ **Выполнен** (26.09.2026): статические `seedFor`/`indexFor` — единая арифметика с Kotlin; таблица векторов (8 дат, N=160) в шапке `word_of_day_service_test.dart` для пословного переноса в Kotlin-тест этапа 5; инжектируемые часы; стабильность дня (00:01/13:37/23:59), смена дня и года проверены на реальной базе; 24/24 зелёные |
| 3. Виджет (статика) | Манифест + receiver, `word_widget_info.xml`, layout + night-палитры, провайдер с захардкоженным словом | Виджет 4×2 добавляется на экран, корректен в свете/тьме, есть превью в пикере | ✅ **Выполнен** (27.09.2026): receiver (exported=false) + layout (слово/транскрипция/перевод/пример, заглушки = записи №1 «accomplish» — нет мигания до onUpdate) + night-палитры + тап → MainActivity; previewLayout (API 31+) и targetCell* заложены — на API<31 в пикере иконка (PNG-превью — этап 8); включён core library desugaring (требование flutter_local_notifications); `flutter build apk --debug` ✓; ручная проверка на RMX2001 / Android 11: добавление 4×2, статика, тап, свет/тьма — ок; **+ кастомная адаптивная иконка приложения «W.»** (индиго + белый глиф + янтарная точка, API 26+; ревью на устройстве 27.09.2026 — принято) |
| 4. Мост Flutter↔виджет | `WidgetSyncService`: предзагрузка JSON в prefs, сохранение полей, `updateWidget`; тап → приложение открывает карточку этой даты | Слово в виджете = слову в приложении; тап работает после сворашивания и убийства приложения | ✅ **Выполнен** (27.09.2026): WidgetSyncService → 5 ключей prefs (widget.date/word/transcription/translation/example) + updateWidget(WordWidgetProvider); синк на старте/резюме/в полночь; тап: холодный старт (initiallyLaunchedFromHomeWidget) + тёплый (стрим widgetClicked) → карточка даты с меткой «открыто из виджета»; провайдер читает те же 5 ключей, пустые prefs → плейсхолдер (риск §9-7); flutter analyze чисто, flutter test 35/35 (было 24); приём на RMX2001 / Android 11 — ок; предзагрузка полной JSON-базы перенесена в этап 5 |
| 5. Автономная смена | Логика в `WordWidgetProvider.onUpdate` (§6) + предзагрузка JSON в prefs (перенос из этапа 4) | Перевести часы на следующий день, НЕ открывая приложение (или перезагрузка) — слово сменилось ≤ 30 мин | ✅ **Выполнен** (27.09.2026): WidgetSyncService пишет `word_db_json` (вся база, 1 раз на инстанс сервиса); `WordOfDayCalculator.kt` — формула §5 + org.json, JVM-тест 7/7 на общих векторах с Dart (риск §9-4); onUpdate: word_db_json → 5 ключей → плейсхолдер; BootCompletedReceiver + RECEIVE_BOOT_COMPLETED; полуночный будильник не понадобился — гарантию даёт updatePeriodMillis 30 мин (§9-2/§9-6); flutter analyze чисто, flutter test 39/39, testDebugUnitTest 7/7, debug-APK собран и установлен на устройство; ручная приёмка «перевод часов/ребут без открытия приложения» — за пользователем |
| 6. UI | Темы M3 (light/dark, indigo+amber), `HomeScreen` + `WordCard` + `TypeBadge` (word=индиго, idiom=янтарь, phrasal_verb=teal), русские строки | Карточка вмещается на маленьких экранах; тема следует системной | ✅ **Выполнен** (27.09.2026): `ui/widgets/word_card.dart` (`Card.filled`: Wrap-заголовок с бейджем/датой/меткой «из виджета», слово, IPA, перевод, пример+перевод) + `type_badge.dart` («слово»/«идиома»/«фразовый глагол»; фиксированные в обеих темах цвета: индиго/янтарь/teal) + `HomeScreen` переписан (`formatDateRu` без intl, maxWidth 600, экран ошибки словаря); темы M3 light/dark/system — с этапа 4, янтарный акцент §1 — бейдж идиомы и метка «из виджета»; `word_card_test.dart` +5 тестов (влезание на 320×480, тёмная тема) — flutter test 44/44, analyze чисто, debug-APK собран; ручная приёмка на устройстве — за пользователем |
| 7. Уведомления | `NotificationService` по §7 + permission-флоу | Уведомление приходит в срок; тап открывает приложение; отказ от разрешения не ломает виджет | ✅ **Выполнен** (27.09.2026): `notification_service.dart` — `NotificationService` + `NotificationsBackend` (фейк в тестах); расписание: контент = слово дня ДНЯ СРАБАТЫВАНИЯ (запуск после 09:00 планирует завтрашнее со завтрашним словом), payload = `wordoftheday://word?date=…` — тап (тёплый/холодный старт) открывает карточку того же дня общим парсером с виджетом; `matchDateTimeComponents: time` — натив сам переставляет ежедневный повтор по настенным часам зоны `TZDateTime.location` (IANA из `flutter_timezone`, фолбэки `Etc/GMT±` → UTC) и восстанавливает его после ребута (2 receiver'а плагина в манифесте + `POST_NOTIFICATIONS`); `POST_NOTIFICATIONS` спрашивается 1 раз за запуск (`requestNotificationsPermission`), отказ не блокирует расписание (риск §9-5); reschedule-триггеры: старт/резюм/полночь; analyze чисто, flutter test 56/56, debug-APK собран; ручная приёмка (приход в 09:00, тап, отказ в разрешении) — за пользователем |
| 8. QA и полировка | Матрица лаунчеров (Pixel, One UI, MIUI), reboot, смена темы, виджет до первого запуска (placeholder), PNG-иконки приложения для API<26 и PNG-превью виджета для API<31, сборка релиза | `flutter test` зелёный; `flutter build apk --release` собирается | ✅ **Выполнен** (28.09.2026): PNG-иконки лаунчера `mipmap-{mdpi…xxxhdpi}/ic_launcher.png` 48/72/96/144/192 px (глиф «W.» на скруглённом индиго-квадрате); PNG-превью виджета `drawable-nodpi/widget_preview.png` 480×220 + `android:previewImage` в `word_widget_info.xml`; alpha-only иконка уведомлений `drawable/ic_stat_word.xml` (`defaultIcon`); analyze чисто, flutter test 56/56; релизный APK собран (45.3 МБ, debug-подпись) и установлен (`--user 0 -r`, запуск без ошибок в logcat); `aapt dump permissions`: в release НЕТ `INTERNET` (в debug есть — оверлей Flutter); остальные права — свои (boot, POST_NOTIFICATIONS) и merged от плагинов/AndroidX (VIBRATE — flutter_local_notifications; WAKE_LOCK/ACCESS_NETWORK_STATE/FOREGROUND_SERVICE — androidx.work 2.11.2 транзитивно через androidx.glance 1.2.0 из home_widget), сетевого доступа не дают; ручная матрица — `docs/QA_CHECKLIST.md`, приёмка — за пользователем |
| 9. Произношение | `PronunciationService` + `TtsBackend` (паттерн этапа 7): кнопка-динамик в `WordCard`, язык фиксированный `en-US`, `awaitSpeakCompletion`; `<queries>` `TTS_SERVICE` в манифесте | Тап по динамику озвучивает слово/фразу дня (en-US); повторный тап и уход в фон — стоп; нет голоса — кнопки нет; ноль новых прав в APK | ✅ **Выполнен** (28.09.2026): `flutter_tts ^4.2.5` (системный TTS-движок Android: офлайн, без прав, APK 45.4 МБ против 45.3); `lib/services/pronunciation_service.dart` — `TtsBackend`/`FlutterTtsBackend` + `PronunciationService` (`isAvailable` — есть ли en-US-голос: нет → кнопки нет, риск §9-13; `isSpeaking` ValueNotifier — динамик↔«стоп»; `toggle`/`stop`/`dispose`; ошибки плагина глотаются `_quietly`); `WordCard` — опциональные `onListen`/`isListening` (Row: слово в `Expanded` + кнопка; `null` → кнопки нет, виджет остался stateless); `HomeScreen` — `ValueListenableBuilder` над `isSpeaking` + `WidgetsBindingObserver` (`paused`/`hidden` и смена даты из тапа → стоп речи); манифест: `<queries>` с `TTS_SERVICE` (Android 11+ package visibility — иначе движок не виден); озвучивается только слово/фраза дня (не пример-предложение); на виджете звука нет (RemoteViews); +13 тестов (9 unit на фейк-бэкенде с «долгой речью» через Completer + 4 виджет) — flutter test 69/69, analyze чисто; релизный APK собран, `aapt dump permissions`: НОВЫХ прав нет, `INTERNET` нет; установлен на RMX2001 (`--user 0 -r`, запуск без ошибок в logcat); ручная приёмка (звук en-US, скорость речи, стоп тапом/фоном) — за пользователем |
| 10. Локализация + редизайн | Локализация UI en/ru/id (first-party `flutter_localizations` + `intl`, ARB / `flutter gen-l10n`), нативные строки `values-ru`/`values-id`, бренд «Word of Day»; редизайн: зелёный seed `#4CAF50`, приложение light-only, зелёные иконки | Язык устройства → язык UI/уведомлений/строк виджета; приложение светлое и в тёмной системной теме; `flutter test` зелёный | ✅ **Выполнен** (01.10.2026): `l10n.yaml` + `lib/l10n/` (ARB en/ru/id; `generated/` коммитится — синтетический пакет deprecated, явный `output-dir` рекомендован); `MaterialApp` — `localizationsDelegates`/`supportedLocales`/`onGenerateTitle`; `NotificationService` — локализованные тексты и канал (локаль устройства, каноникализация `in`→`id`); нативно: `app_name` «Word of Day», `values-ru`/`values-id` (перевод превью-записи русский до schema v2 — задокументировано); редизайн: seed `#4CAF50`, `ThemeMode.light`, светлый сплэш и в ночной теме (`launch_bg_color`), зелёная адаптивная иконка + перегенерированные PNG, `drawable-v21/launch_background.xml` удалён (стал идентичен базовому); тесты переведены на en-ожидания (flutter test 69/69, количество сохранено), analyze чисто; ручная приёмка — `docs/QA_CHECKLIST.md` §9, за пользователем |
| 11. iOS-платформа | Каркас `ios/` (`flutter create --platforms=ios`), `Info.plist` (имя «Word of Day», локализации ru/id через `InfoPlist.strings`, URI-схема `wordoftheday`), Darwin-ветки уведомлений (разрешение alert/sound; boot-восстановление не нужно — план хранит система), адаптивный UI (`platform_widgets.dart`: навбар/индикатор/кнопка/иконка), single-size иконка 1024 + сплэш `#F1F8E9`, App Group — задел под WidgetKit | `flutter analyze`/`flutter test` зелёные; сборка и ручная приёмка — на Mac (Windows не собирает iOS), QA §10 | ✅ **Выполнен** (01.10.2026): `ios/` создан (bundle id `com.english.widget.engWidgetApp`, iOS 15+, SPM без Podfile — новый шаблон Flutter); `DarwinInitializationSettings`/`DarwinNotificationDetails` (запрос разрешений внутри initialize отключён — системный диалог один раз из `requestPermission`, как на Android; баннер+звук, бейджа нет); `lib/ui/widgets/platform_widgets.dart` (`isAppleStyle` по `Theme.of(context).platform` — iOS-ветки тестируются через `ThemeData(platform:)`) + home_screen/word_card на хелперах; `InfoPlist.strings` ru/id («Слово дня»/«Kata Hari Ini»); сплэш `#F1F8E9`; single-size AppIcon 1024 с тем же глифом «W.»; `PluginHomeWidgetBackend` применяет `setAppGroupId` лениво; +7 тестов (76/76), analyze чисто; на Windows — статическая валидация, сборка/QA — Mac (`docs/QA_CHECKLIST.md` §10) |
| 12. Фото-ассоциация к слову дня | `image_picker` + `path_provider`: выбор источника (платформенный пикер: CupertinoActionSheet/bottom sheet), камера/галерея, сжатие, хранение `word_images/{id}.jpg`, замена/удаление; секция в `WordCard`; iOS usage-описания (+ ru/id) | Фото добавляется/заменяется/удаляется из карточки, переживает перезапуск и годовые повторы слова; `flutter test` зелёный; ноль новых прав в APK | ✅ **Выполнен** (01.10.2026): `services/word_image_service.dart` (`ImagePickerBackend`/`PluginImagePickerBackend` — паттерн этапов 4/7/9; `WordImageSource`; тихие ошибки; синхронный файловый IO — детерминирован в fake-async тестах); `ui/widgets/image_source_sheet.dart` (CupertinoActionSheet ↔ modal bottom sheet); `WordCard` — секция фото 16:10 (OutlinedButton добавления / картинка + адаптивные «заменить»/«убрать», errorBuilder на битый файл); `HomeScreen` — кэш future-ов «слово+фото» по дате (`_WordCardData`); ARB +7 строк (en/ru/id); iOS: `NSCameraUsageDescription`/`NSPhotoLibraryUsageDescription` (+ `InfoPlist.strings` ru/id), Android — БЕЗ `CAMERA` (intents); +15 тестов (9 сервис + 2 пикер + 4 карточка) — 91/91, analyze чисто; релизный APK собран (48.3 МБ), `aapt dump permissions`: НОВЫХ прав нет (`CAMERA` и `INTERNET` отсутствуют); ручная приёмка — QA §11 (Android) и §10 (iOS на Mac) |
| 13. Избранное (идея B-002) | `FavoriteService` (`documents/favorites.json`: id записи + дата добавления; `ValueNotifier` — живая синхронизация экранов; тихие ошибки, синхронный IO — паттерн этапа 12), звёздочка в `WordCard` (контур ↔ янтарная заливка), экран списка избранного из AppBar (новые сверху, удаление свайпом) + `WordDetailScreen` с полной карточкой (TTS, фото-ассоциация, снятие звезды); ARB +4 ключа en/ru/id; ноль новых зависимостей и прав | Слово добавляется/удаляется звездой в карточке в любой момент; список открывается из AppBar, порядок «свежие сверху», свайп удаляет; избранное переживает перезапуск; `flutter analyze`/`flutter test` зелёные; ноль новых прав | ✅ **Выполнен** (02.10.2026): `services/favorite_service.dart` (id записи + дата добавления, порядок «старые → новые», `ValueNotifier` для синхронной звезды и списка, стартовое чтение в конструкторе + мемоизированный `load()`, тихие ошибки); `ui/screens/favorites_screen.dart` (список свежими сверху, тап → карточка, свайп-удаление с контекстным меню, пустое состояние со звёздочкой-заглушкой) + `ui/screens/word_detail_screen.dart` (полная карточка избранного слова: TTS, фото-ассоциация, снятие звезды); `WordCard` — звезда `Icons.star_outline_rounded` ↔ залитая янтарным `Icons.star_rounded` (M3: цвет глифа — через `IconButton.color`, не IconTheme; iOS — `CupertinoButton` + SF-иконка); вход — иконка в AppBar (`PlatformIconActionButton`); ARB +4 ключа (favoritesTitle/favoritesEmptyTitle/favoritesEmptyHint/favoriteRemove) en/ru/id; +16 тестов (9 сервис + 5 экран списка + 2 карточка-звезда) и сценарий приложения собран в один `testWidgets` (см. БЗ §15 — платформенный ответ `flutter/assets` живёт только в первом тесте файла) — 107/107, analyze чисто; ноль новых зависимостей и прав |
| 14. Квиз-повторение (идея B-006) | `QuizService` (`documents/quiz_results.json`: история прохождений, дата последнего квиза, `isDue`/`nextQuizDate` — цикл «каждые 3 дня»; генерация: 5 вопросов «слово → перевод из 4 вариантов», материал — избранное с добором из словаря, дистракторы того же типа), экран квиза (прогресс, подсветка верно/неверно, результат: счёт + «слова на повторение» + дата следующего квиза, «Ещё раз»), вход — иконка в AppBar + тап по напоминанию; напоминание: одноразовое уведомление на дату следующего квиза 10:00 (канал `quiz`, payload `wordoftheday://quiz`, перепланирование: старт/резюм/полночь/завершение квиза); ARB +15 ключей en/ru/id; ноль новых зависимостей и прав | Квиз собирается из избранного (с добором из словаря при нехватке), 4 варианта с одним верным; ответ подсвечивается, счёт и «что повторить» показываются в конце; результат и дата следующего квиза переживают перезапуск; напоминание ставится на +3 дня после прохождения и открывает квиз по тапу; `flutter analyze`/`flutter test` зелёные; ноль новых прав | ✅ **Выполнен** (02.10.2026): `services/quiz_service.dart` (история `quiz_results.json` паттерна этапа 13 + статическая `generate`: пул = избранное, добор случайными записями, дистракторы того же типа, уникальные переводы, инжектируемый Random; `nextQuizDate` = +3 дня, `isDue`, колбэк `onQuizFinished`); `ui/screens/quiz_screen.dart` (вопрос → подсветка (галочка/крестик) → пауза 900 мс → следующий; результат: счёт, «слова на повторение», дата следующего квиза, «Ещё раз»/«Готово»; пустое состояние при крошечном словаре); вход — иконка `Icons.quiz_rounded`/`CupertinoIcons.question_circle` в AppBar рядом со звездой + сигнал `_quizOpenRequest` из main.dart; напоминание — `NotificationsBackend.scheduleOneShot` (одноразовое `zonedSchedule` без matchDateTimeComponents) + `NotificationService.rescheduleQuizReminder` (id 2, канал `quiz`, 10:00; null → отмена; прошедшая дата → ближайшее будущее 10:00; триггеры: старт/резюм/полночь/`onQuizFinished`); тап по напоминанию (тёплый `onOpenQuiz`/холодный payload) открывает квиз; ARB +15 ключей en/ru/id; +25 тестов (12 сервис + 7 экран + 6 напоминание) — 132/132, analyze чисто; ноль новых зависимостей и прав |
| 15. Шеринг карточки (идея B-001) | Кнопка «поделиться» в карточке (слово дня + избранное): брендированный постер (бейдж типа, слово, транскрипция, перевод, бренд «Word of Day») рендерится через `RepaintBoundary` → PNG во временную папку, отдаётся в системный share sheet; зависимость `share_plus` (решение владельца 03.10.2026); `ShareBackend`-паттерн этапа 9 для тестируемости; ARB +ключи en/ru/id; ноль новых прав | Тап по кнопке открывает системный share sheet с картинкой карточки; отправка в мессенджер доставляет читаемый PNG; карточка дня и избранное шерятся одинаково; тултип кнопки локализован en/ru/id; `flutter analyze`/`flutter test` зелёные; ноль новых прав в APK | ✅ выполнен (03.10.2026) |

> Источник новых этапов (13+, v1.1) — бэклог бизнес-идей `docs/ideas/BACKLOG.md`: карточка со статусом «принята» становится строкой таблицы выше (процесс и статусы — `docs/ideas/README.md`).

## 9. Риски и обход

| # | Риск | Обход |
|---|---|---|
| 1 | RemoteViews: ограниченный набор вью, только системные шрифты | Минималистичный макет, Roboto, кастомизация цветами/фонами |
| 2 | Полночь + Doze → задержка смены слова до 30–60 мин | Принято; дополнительно обновляем при открытии приложения, тапе и после BOOT_COMPLETED |
| 3 | OEM-лаунчеры (One UI, MIUI) кэшируют/режут фоновую активность | Ручная матрица тестов; в v1.1 — подсказка «разрешить автозапуск» |
| 4 | Расхождение формулы seed между Dart и Kotlin | Формула из одного выражения (§5), общие тест-векторы дат в тестах обеих сторон |
| 5 | Android 13+: отказ в POST_NOTIFICATIONS | Мягкая деградация — виджет от уведомлений не зависит |
| 6 | Ограничения точных будильников Android 12+/14+ | inexactAllowWhileIdle; минутная точность не нужна |
| 7 | Виджет добавлен до первого запуска → prefs пустые | Placeholder «Откройте приложение»; первый запуск всё заполнит |
| 8 | База ~60–80 КБ в SharedPreferences | Допустимо; при росте > 500 записей — файл в filesDir + чтение нативно |
| 9 | Повторы слова в году (чистый mod) | Принято в v1.0; v1.1 — хранимая перестановка индексов |
| 10 | home_widget 0.10.0 — свежий релиз | Версия зафиксирована в pubspec; апгрейд — отдельной задачей по ченджлогу |
| 11 | Кракозябры JSON | utf8.decode при чтении ассета; файл в UTF-8 без BOM |
| 12 | Пользователь ждёт ресайза виджета | resizeMode=none — честное фиксированное 4×2 |
| 13 | Нет TTS-движка или голоса en-US на устройстве (этап 9) | Мягкая деградация: `isLanguageAvailable('en-US')` → кнопки прослушивания нет, карточка работает; звук — только в приложении |
| 14 | Windows-станция: iOS-сборка и ручное QA невозможны (этап 11) | Статическая валидация (analyze/test зелёные, SPM-резолв); сборка и приёмка — на Mac по `QA_CHECKLIST.md` §10 при появлении доступа |
| 15 | Нет iOS-виджета в v1.0 (WidgetKit = отдельный extension-таргет + Mac/Xcode) | Честный скоуп: карточка дня открывается из уведомления; Dart-задел готов (URI-схема + App Group); WidgetKit — v1.1 |
| 16 | Отказ/отсутствие камеры или галереи (этап 12: эмуляторы без камеры, отказ в iOS-разрешениях) | Мягкая деградация: выбор источника тихо возвращает null, карточка работает без фото; повторная попытка — новой кнопкой |

## 10. Definition of Done

- Виджет оффлайн показывает слово дня, меняется после полуночи (±30 мин) без сети и без запуска приложения, переживает перезагрузку.
- Тап по виджету/уведомлению открывает карточку соответствующего дня.
- Светлая/тёмная тема виджета следует системе; приложение всегда светлое (изменено этапом 10).
- `flutter analyze` / `flutter test` зелёные, релизный APK собирается.
- Ноль сетевых прав в манифесте (проверка: `aapt dump permissions`).
- iOS (этап 11): каркас валиден статически (analyze/test зелёные, SPM-резолв); сборка и ручная приёмка — на Mac (`docs/QA_CHECKLIST.md` §10); виджет на iOS вне v1.0 (задел — URI-схема + App Group).
- Фото-ассоциация (этап 12): добавляется/заменяется/удаляется из карточки на обеих ОС, переживает перезапуск и годовые повторы слова (ключ — id записи); Android — ноль новых прав.
- Перед КАЖДЫМ коммитом этапа актуализированы `docs/KNOWLEDGE_BASE.md` (термины, даты актуальности) и `docs/PROJECT_STRUCTURE.md` (дерево, таблицы файлов, схемы потоков) — под внесённые изменения.
