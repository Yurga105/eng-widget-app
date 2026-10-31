# QA-сид данных для приёмки квиза (этап 14) и избранного (этап 13)

Отладочные данные для ручной приёмки: `favorites.json` и `quiz_results.json`
кладутся через `adb run-as` в documents-каталог debug-сборки (release не
debuggable — `run-as` на нём не работает). Код приложения не меняется.

## Состав сида

`favorites.json` — 7 слов (порядок «старые → новые», добавлены 18–29.09.2026):

| id | Слово | Тип | Добавлено |
|----|-------|-----|-----------|
| 1 | accomplish | word | 18.09 |
| 82 | piece of cake | idiom | 20.09 |
| 5 | appreciate | word | 22.09 |
| 136 | hang out | phrasal_verb | 24.09 |
| 2 | adapt | word | 25.09 |
| 81 | no-brainer | idiom | 27.09 |
| 7 | avoid | word | 29.09 |

`quiz_results.json` — история из одной записи: квиз пройден
**29.09.2026 10:15** (5 вопросов, 3 верно, ошибки — id 1 и 82). Значит
`nextQuizDate` = **02.10.2026** — дата уже прошла, `isDue` = true: при старте
приложение считает «день квиза» наступившим и перепланирует одноразовое
напоминание на ближайшее 10:00 (сегодня, если время < 10:00, иначе завтра).
Так как `finishedAt` фиксирован, «день квиза» у сида не устаревает — после
02.10.2026 `isDue` остаётся true всегда.

## Как подготовить устройство (серийник Realme: `WO7LLJ79ZL99EU95`)

```powershell
# 1. Debug-сборка и установка. Поверх DEBUG-версии — без потерь (`install -r`).
#    С релиза (upload-ключ из key.properties, правка 29.10.2026) — только после
#    `adb uninstall com.english.widget.eng_widget_app` (подписи не совпадают,
#    QA-данные придётся перезалить шагом 2).
flutter build apk --debug
adb -s WO7LLJ79ZL99EU95 install -r build\app\outputs\flutter-apk\app-debug.apk

# 2. Остановить приложение и положить файлы (documents = app_flutter).
#    Важно: cp отдельными командами — составная `sh -c "cat ... > ..."`
#    из PowerShell не передаётся (кавычки теряются, mkdir получает 0 аргументов).
adb -s WO7LLJ79ZL99EU95 shell am force-stop com.english.widget.eng_widget_app
adb -s WO7LLJ79ZL99EU95 push tool\qa\favorites.json /data/local/tmp/favorites.json
adb -s WO7LLJ79ZL99EU95 push tool\qa\quiz_results.json /data/local/tmp/quiz_results.json
adb -s WO7LLJ79ZL99EU95 shell run-as com.english.widget.eng_widget_app mkdir -p app_flutter
adb -s WO7LLJ79ZL99EU95 shell run-as com.english.widget.eng_widget_app cp /data/local/tmp/favorites.json app_flutter/favorites.json
adb -s WO7LLJ79ZL99EU95 shell run-as com.english.widget.eng_widget_app cp /data/local/tmp/quiz_results.json app_flutter/quiz_results.json

# 3. Проверить, что файлы легли.
adb -s WO7LLJ79ZL99EU95 shell run-as com.english.widget.eng_widget_app ls -l app_flutter

# 4. Запустить приложение.
adb -s WO7LLJ79ZL99EU95 shell monkey -p com.english.widget.eng_widget_app -c android.intent.category.LAUNCHER 1
```

Повтор сценария «день квиза» (например, после прохождения квиза) — просто
заново выполнить шаги 2 и 4: файлы перезапишутся, история вернётся к 29.09.

## Варианты сценария

- **«Квизов не было ни разу»** (напоминание не ставится до первого
  прохождения): не класть `quiz_results.json` (или удалить его через `run-as`).
- **Напоминание «сегодня»**: после установки сида перевести часы устройства
  на 09:55 следующего дня, force-stop и запустить приложение (перепланирование
  на старте) — в 10:00 придёт уведомление канала «quiz» с payload
  `wordoftheday://quiz`.

## Возврат на release

```powershell
flutter build apk --release
adb -s WO7LLJ79ZL99EU95 install -r build\app\outputs\flutter-apk\app-release.apk
```

Данные (избранное/история квизов) общие — при необходимости очистить:
`adb shell run-as com.english.widget.eng_widget_app rm app_flutter/favorites.json app_flutter/quiz_results.json`.
