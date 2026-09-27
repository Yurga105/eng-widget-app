# Структура проекта «Слово дня» (eng_widget_app)

> Карта каталогов и файлов: что где лежит, зачем нужно и как части связаны.
> Актуально на 27.09.2026 (состояние после этапа 4, коммит `37f70b1`).
> Термины и определения — в `docs/KNOWLEDGE_BASE.md`; план и статусы этапов — в `PLAN.md`.

## 1. Вид сверху

```text
eng_widget_app/                 корень репозитория
├─ lib/                         весь Dart-код приложения (Flutter)
│  ├─ main.dart                 входная точка: темы M3, синк виджета, приём тапов
│  ├─ models/                   модели данных (WordEntry, WordType)
│  ├─ services/                 логика: словарь, формула слова дня, мост к виджету
│  └─ ui/screens/               экраны приложения
├─ assets/
│  └─ words_db.json             офлайн-словарь: 160 записей (единственный источник данных)
├─ android/                     нативная часть: Kotlin, ресурсы виджета, сборка Gradle
├─ test/                        тесты (зеркалят структуру lib/)
├─ docs/                        документация: База знаний + этот файл
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
      │   HomeWidget.saveWidgetData ×5
      │   HomeWidget.updateWidget(androidName: 'WordWidgetProvider')
      ▼
SharedPreferences «HomeWidgetPreferences»
      │ ключи widget.date / widget.word / widget.transcription /
      │       widget.translation / widget.example  (общий контракт)
      ▼
WordWidgetProvider.onUpdate → RemoteViews(word_widget.xml)
      ▼
Виджет 4×2 на домашнем экране
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
        HomeScreen: карточка слова этой даты + метка «открыто из виджета»
```

Оба потока сходятся на контракте «5 ключей + URI» — его части живут в `lib/services/widget_sync_service.dart` и `WordWidgetProvider.kt`, менять только синхронно.

## 4. lib/ — Dart-часть

| Файл | Роль | Зачем существует |
|---|---|---|
| `main.dart` | `main()` + `WordOfTheDayApp` | «Проводка» этапа 4: синк слова в виджет при старте, на `resumed` и в полночь (пере-планируемый Timer); подписка на тапы (`initiallyLaunchedFromHomeWidget` + `widgetClicked`) → `ValueNotifier`; темы Material 3 (seed — индиго `#3F51B5`, светлая и тёмная следуют системе) |
| `models/word_entry.dart` | `WordEntry`, `WordType` | модель записи словаря: `fromJson`/`toJson`, валидация `type`, полное равенство полей — основа тестов |
| `services/dictionary_service.dart` | `DictionaryService` | чтение и парсинг `words_db.json` через `rootBundle` (UTF-8), кэш в памяти; загрузчик подменяем в тестах |
| `services/word_of_day_service.dart` | `WordOfDayService` | формула §5 (`seedFor`/`indexFor`) — та же арифметика будет в Kotlin; часы инжектируются (фейк в тестах) |
| `services/widget_sync_service.dart` | `WidgetSyncService`, `HomeWidgetBackend` | мост к виджету: 5 ключей + `updateWidget`; `isoDate`/`widgetUri`/`dateFromWidgetUri`; интерфейс бэкенда введён ради тестируемости |
| `ui/screens/home_screen.dart` | `HomeScreen` | промежуточная карточка этапа 4: слово выбранной даты (из тапа по виджету или сегодня); полноценный UI — этап 6 |

Принцип: модели не знают про UI; вся логика — в сервисах (тестируются без интерфейса); экраны тонкие. Новый код: сервис → `services/`, экран → `ui/screens/`, переиспользуемый виджет UI → `ui/widgets/` (появится на этапе 6).

## 5. test/ — тесты (35, все зелёные)

| Файл | Что покрывает |
|---|---|
| `word_entry_test.dart` | модель: заполнение полей, round-trip `toJson`/`fromJson`, маппинг `type` (word / idiom / phrasal_verb), `ArgumentError` на неизвестный тип |
| `dictionary_service_test.dart` | чтение ассета, повторный вызов из кэша, ошибки: битый JSON, отсутствие массива `words` |
| `word_of_day_service_test.dart` | формула: `seed = yyyy*10000 + MM*100 + dd`, фиксированные даты при N=160, зависимость индекса от размера базы, `ArgumentError` при `total <= 0`, смена года перемешивает последовательность (2027-01-01 → id 22) |
| `widget_sync_service_test.dart` (11) | мост на фейк-бэкенде: контракт 5 ключей и их значения, `isoDate` с ведущими нулями, `widgetUri`/`dateFromWidgetUri` round-trip, отбраковка чужих схем и дат вида «31 февраля» |
| `widget_test.dart` | приложение целиком: мок обоих MethodChannel плагина (`home_widget`, `home_widget/updates`), синк при старте, тап по виджету → карточка с меткой «открыто из виджета»; демонтаж приложения в конце |

Тесты зеркалят `lib/`: новый файл в `lib/` → парный в `test/` с суффиксом `_test`.

## 6. android/ — нативная часть

```text
android/
├─ build.gradle.kts / settings.gradle.kts / gradle.properties   обвязка сборки (Kotlin DSL)
├─ gradle/wrapper/ + gradlew(.bat)                              Gradle Wrapper — фиксированная версия сборщика
├─ local.properties          локальные пути SDK — НЕ в git
├─ .gradle/                  локальный кэш Gradle — НЕ в git
└─ app/
   ├─ build.gradle.kts       id com.english.widget.eng_widget_app; core library desugaring
   │                         (требование flutter_local_notifications)
   └─ src/
      ├─ main/               основная конфигурация и код (таблица ниже)
      ├─ debug/ + profile/   технические манифесты-оверлеи Flutter
      └─ java/.../GeneratedPluginRegistrant.java   генерируется Flutter, не редактировать
```

`app/src/main/`:

| Путь | Роль |
|---|---|
| `AndroidManifest.xml` | `MainActivity` (`singleTop`, лаунчер) + `<receiver .WordWidgetProvider>` (`exported="false"`, `APPWIDGET_UPDATE`, meta-data → `word_widget_info`); сетевых прав нет |
| `kotlin/.../MainActivity.kt` | пустая `FlutterActivity` — точка входа, сюда доезжают интенты тапа |
| `kotlin/.../WordWidgetProvider.kt` | провайдер виджета: 5 ключей → `RemoteViews`; пустые prefs → плейсхолдер (§9-7); тап → URI; этап 5 — автономный пересчёт слова |
| `res/layout/word_widget.xml` | RemoteViews-макет 4×2: слово (20sp) → транскрипция (12sp) → перевод (14sp) → пример (12sp, до 2 строк), фон `widget_bg` |
| `res/xml/word_widget_info.xml` | дескриптор виджета: `targetCell 4×2` (API 31+), `minWidth/Height 250×110dp`, `updatePeriodMillis` 30 мин, `resizeMode=none`, `previewLayout` |
| `res/values/strings.xml` | имя «Слово дня», описание, заглушки-превью (запись №1), тексты плейсхолдера |
| `res/values/widget_colors.xml` + `res/values-night/widget_colors.xml` | палитры виджета для светлой и тёмной темы — менять только парой |
| `res/values/styles.xml` + `res/values-night/styles.xml` | темы приложения и сплэша |
| `res/values/ic_launcher_colors.xml` | цвета адаптивной иконки |
| `res/drawable/widget_bg.xml` | скруглённый фон виджета (16dp) |
| `res/drawable/ic_launcher_foreground.xml` | вектор-глиф «W.» иконки (safe zone 108dp) |
| `res/mipmap-anydpi-v26/ic_launcher.xml` | адаптивная иконка API 26+ (фон + глиф) |
| `res/mipmap-*/ic_launcher.png` | растровые иконки для API<26 (замена — этап 8) |

## 7. Корень и служебные файлы

| Путь | Что это |
|---|---|
| `PLAN.md` | главный план: решения §1, стек §2, структура §3, данные §4, формула §5, нативная логика §6, уведомления §7, этапы и статусы §8, риски §9, DoD §10 |
| `docs/KNOWLEDGE_BASE.md` | словарь терминов проекта |
| `docs/PROJECT_STRUCTURE.md` | этот документ |
| `pubspec.yaml` | зависимости (`home_widget 0.10.0`, `flutter_local_notifications 22.3.1`), ассет `words_db.json`, версия SDK |
| `pubspec.lock` | точная фиксация версий пакетов — коммитить |
| `analysis_options.yaml` | включение flutter_lints |
| `.gitignore` | исключения из git: `build/`, `.dart_tool/`, `local.properties` и т.п. |
| `.metadata`, `*.iml`, `.flutter-plugins-dependencies` | служебные файлы Flutter/IDE — руками не редактируются |

## 8. Куда класть новый код

| Добавляю | Куда | Пример |
|---|---|---|
| логика/сервис | `lib/services/` + тест в `test/` | `notification_service.dart` (этап 7) |
| экран | `lib/ui/screens/` | — |
| переиспользуемый виджет UI | `lib/ui/widgets/` (появится на этапе 6) | `word_card.dart`, `type_badge.dart` |
| модель данных | `lib/models/` | — |
| строка виджета (нативная) | `android/.../res/values/strings.xml` | плейсхолдеры этапа 4 |
| цвет виджета | `values/widget_colors.xml` + `values-night/widget_colors.xml` (пара!) | — |
| ключ контракта Flutter↔Kotlin | `widget_sync_service.dart` + `WordWidgetProvider.kt` синхронно | 5 ключей `widget.*` |

## 9. Что появится по плану

- **Этап 5** — ключ `word_db_json` в prefs, парсер `org.json` в провайдере, полуночный будильник в дополнение к `updatePeriodMillis`, ресивер `BOOT_COMPLETED` + право в манифесте.
- **Этап 6** — `ui/widgets/word_card.dart`, `type_badge.dart`, полноценный `HomeScreen` (M3, бейджи типов: word=индиго, idiom=янтарь, phrasal_verb=teal).
- **Этап 7** — `services/notification_service.dart`, канал `word_of_day`, расписание 09:00, permission-флоу.
- **Этап 8** — PNG-иконки для API<26, PNG-превью виджета для API<31, матрица лаунчеров, релизная сборка.

## 10. Порядок чтения кода новичку

1. `PLAN.md` — что и почему делаем.
2. `docs/KNOWLEDGE_BASE.md` — термины.
3. `lib/models/word_entry.dart` → `lib/services/dictionary_service.dart` → `word_of_day_service.dart` — данные и формула.
4. `lib/services/widget_sync_service.dart` → `lib/main.dart` → `home_screen.dart` — мост и UI.
5. `WordWidgetProvider.kt` → `res/layout/word_widget.xml` → `res/xml/word_widget_info.xml` — нативная сторона.
6. `test/` — как всё это проверяется.

