# PLAN.md — «Word of the Day» (eng_widget_app)

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
| UI v1.0 | Один экран: большая карточка слова дня; Material 3, светлая + тёмная тема; язык интерфейса — русский |
| Сеть | Никаких сетевых запросов; `dio` удалить из зависимостей; в манифесте не должно быть прав на интернет |

**Допущения v1.0** (по умолчанию, легко меняется): уведомление в 09:00 локального времени (константа, настроек в v1 нет); палитра M3 — индиго (seed) + янтарный акцент.

## 2. Стек технологий

- **Flutter / Dart**: SDK ^3.13.4 (уже настроен), Material 3, без внешнего state-management — `StatefulWidget` + `ValueNotifier`.
- **Пакеты**: `home_widget ^0.10.0` (уже в pubspec), `flutter_local_notifications ^22.3.1` (добавлен ✅ этап 0), `flutter_lints` (есть).
- **Нативная часть**: Kotlin + XML `RemoteViews`, `AppWidgetProvider`, `PendingIntent`, `SharedPreferences`, встроенный `org.json` (парсинг базы в нативном провайдере для автономной смены слова).
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
- Заголовок «Слово дня — {word}», тело «{transcription} — {translation}»; тап → приложение.
- Запрос `POST_NOTIFICATIONS` на первом запуске (Android 13+); отказ — мягкая деградация: виджет продолжает работать; повторный запрос — не раньше следующего запуска.

## 8. Этапы разработки

> Статусы обновлены 27.09.2026 после завершения этапов 0–3 (Dart: `flutter analyze` чисто, `flutter test` — 24/24 зелёные; натив: сборка APK ✓, ручная проверка виджета на устройстве ✓).

| Этап | Содержание | Критерий приёмки | Статус |
|---|---|---|---|
| 0. Чистка шаблона | Убрать `dio` из pubspec и счётчик из main.dart; добавить `flutter_local_notifications`; `flutter pub get` | `flutter analyze` без замечаний, `flutter run` показывает пустой scaffold | ✅ **Выполнен** (26.09.2026): `dio` удалён, `flutter_local_notifications ^22.3.1` добавлен, шаблонный счётчик заменён на `WordOfTheDayApp` + `HomeScreen`-заглушку; `pub get`/`analyze` чисто. Рендер проверен widget-тестом; запуск на устройстве перенесён в этап 8 (QA) |
| 1. Данные | Сгенерировать `assets/words_db.json` (150–200 записей по §4); регистрация ассета; `WordEntry` + `DictionaryService` (кэш) | Unit-тест: все записи валидны, id уникальны, типы ~50/50 | ✅ **Выполнен** (26.09.2026): база 160 записей = 80 слов / 55 идиом / 25 фразовых (50 % / 34 % / 16 %), id 1–160 подряд; ассет зарегистрирован в pubspec; модель + сервис (UTF-8 через rootBundle, кэш, обработка ошибок); тесты `word_entry_test` + `dictionary_service_test` зелёные |
| 2. Слово дня | `WordOfDayService` по формуле §5 + тест-векторы | Тесты: слово стабильно весь день; меняется на следующий день; индекс совпадает с эталоном для фиксированных дат | ✅ **Выполнен** (26.09.2026): статические `seedFor`/`indexFor` — единая арифметика с Kotlin; таблица векторов (8 дат, N=160) в шапке `word_of_day_service_test.dart` для пословного переноса в Kotlin-тест этапа 5; инжектируемые часы; стабильность дня (00:01/13:37/23:59), смена дня и года проверены на реальной базе; 24/24 зелёные |
| 3. Виджет (статика) | Манифест + receiver, `word_widget_info.xml`, layout + night-палитры, провайдер с захардкоженным словом | Виджет 4×2 добавляется на экран, корректен в свете/тьме, есть превью в пикере | ✅ **Выполнен** (27.09.2026): receiver (exported=false) + layout (слово/транскрипция/перевод/пример, заглушки = записи №1 «accomplish» — нет мигания до onUpdate) + night-палитры + тап → MainActivity; previewLayout (API 31+) и targetCell* заложены — на API<31 в пикере иконка (PNG-превью — этап 8); включён core library desugaring (требование flutter_local_notifications); `flutter build apk --debug` ✓; ручная проверка на RMX2001 / Android 11: добавление 4×2, статика, тап, свет/тьма — ок; **+ кастомная адаптивная иконка приложения «W.»** (индиго + белый глиф + янтарная точка, API 26+; ревью на устройстве 27.09.2026 — принято) |
| 4. Мост Flutter↔виджет | `WidgetSyncService`: предзагрузка JSON в prefs, сохранение полей, `updateWidget`; тап → приложение открывает карточку этой даты | Слово в виджете = слову в приложении; тап работает после сворачивания и убийства приложения | ⏭ **Следующий** — не начат |
| 5. Автономная смена | Логика в `WordWidgetProvider.onUpdate` (§6) | Перевести часы на следующий день, НЕ открывая приложение (или перезагрузка) — слово сменилось ≤ 30 мин | ⬜ Не начат |
| 6. UI | Темы M3 (light/dark, indigo+amber), `HomeScreen` + `WordCard` + `TypeBadge` (word=индиго, idiom=янтарь, phrasal_verb=teal), русские строки | Карточка вмещается на маленьких экранах; тема следует системной | ⬜ Не начат |
| 7. Уведомления | `NotificationService` по §7 + permission-флоу | Уведомление приходит в срок; тап открывает приложение; отказ от разрешения не ломает виджет | ⬜ Не начат |
| 8. QA и полировка | Матрица лаунчеров (Pixel, One UI, MIUI), reboot, смена темы, виджет до первого запуска (placeholder), PNG-иконки приложения для API<26 и PNG-превью виджета для API<31, сборка релиза | `flutter test` зелёный; `flutter build apk --release` собирается | ⬜ Не начат |

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

## 10. Definition of Done

- Виджет оффлайн показывает слово дня, меняется после полуночи (±30 мин) без сети и без запуска приложения, переживает перезагрузку.
- Тап по виджету/уведомлению открывает карточку соответствующего дня.
- Светлая/тёмная тема виджета и приложения следуют системе.
- `flutter analyze` / `flutter test` зелёные, релизный APK собирается.
- Ноль сетевых прав в манифесте (проверка: `aapt dump permissions`).
