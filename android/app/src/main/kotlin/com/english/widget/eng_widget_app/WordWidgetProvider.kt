package com.english.widget.eng_widget_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.time.LocalDate

/**
 * Провайдер виджета «Слово дня» — ЭТАП 5: автономная смена (PLAN.md §6).
 *
 * Цепочка источников данных (первый доступный побеждает):
 *  1. `word_db_json` — вся база в prefs (пишет `WidgetSyncService` при
 *     первом запуске приложения): провайдер сам пересчитывает слово дня
 *     формулой §5 через [WordOfDayCalculator] → смена слова после полуночи
 *     БЕЗ запуска приложения (`updatePeriodMillis` ≤ 30 мин; сразу после
 *     ребута — `BootCompletedReceiver`). Этап 19: язык перевода — ключ
 *     `widget.translation_lang`, фолбэк — русское поле записи.
 *  2. Шесть ключей `widget.*` (этапы 4 и 19) — последние поля, записанные
 *     Flutter; `widget.translation` уже перевод выбранного языка.
 *  3. Плейсхолдер — prefs пусты, виджет добавлен до первого запуска
 *     (риск №7 в PLAN.md §9).
 *
 * Тап → карточка показанного дня: URI `wordoftheday://word?date=…` с датой
 * рендера (сегодня — в автономном режиме). Flutter ловит через
 * `initiallyLaunchedFromHomeWidget()`/`widgetClicked`.
 *
 * Ключи и схема URI — общий контракт с `widget_sync_service.dart`
 * (PLAN.md §6); менять только синхронно.
 */
class WordWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        // Автономный путь: база в prefs → сами считаем слово сегодня.
        // Этап 19: язык переводов — ключ `widget.translation_lang` (пишет
        // Flutter), фолбэк калькулятора — русское поле v1.
        val today = LocalDate.now()
        val dbJson = widgetData.getString(KEY_DB_JSON, null)
        val lang = widgetData.getString(KEY_TRANSLATION_LANG, null) ?: DEFAULT_LANG
        val computed = dbJson?.let { WordOfDayCalculator.entryFor(it, today, lang) }

        // Дата для URI тапа — ровно та, что показана: сегодня у автономного
        // слова, иначе последняя записанная Flutter (иначе карточка тапа
        // разойдётся с виджетом).
        val uriDate = computed?.let { WordOfDayCalculator.isoDate(today) }
            ?: widgetData.getString(KEY_DATE, null)

        // Один и тот же RemoteViews для всех экземпляров виджета —
        // слово дня общее.
        val views = RemoteViews(context.packageName, R.layout.word_widget).apply {
            if (computed != null) {
                setTextViewText(R.id.widget_word, computed.word)
                setTextViewText(R.id.widget_transcription, computed.transcription)
                setTextViewText(R.id.widget_translation, computed.translation)
                setTextViewText(R.id.widget_example, computed.example)
            } else if (uriDate != null) {
                // Этап 4 — fallback на поля, записанные Flutter.
                setTextViewText(R.id.widget_word, widgetData.getString(KEY_WORD, uriDate))
                setTextViewText(
                    R.id.widget_transcription,
                    widgetData.getString(KEY_TRANSCRIPTION, ""),
                )
                setTextViewText(
                    R.id.widget_translation,
                    widgetData.getString(KEY_TRANSLATION, ""),
                )
                setTextViewText(
                    R.id.widget_example,
                    widgetData.getString(KEY_EXAMPLE, ""),
                )
            } else {
                // Виджет добавлен до первого запуска приложения, prefs пусты
                // (риск №7 в PLAN.md §9) — показываем подсказку-плейсхолдер.
                setTextViewText(
                    R.id.widget_word,
                    context.getString(R.string.word_widget_empty_word),
                )
                setTextViewText(R.id.widget_transcription, "")
                setTextViewText(
                    R.id.widget_translation,
                    context.getString(R.string.word_widget_empty_translation),
                )
                setTextViewText(R.id.widget_example, "")
            }

            // Тап → карточка именно этой даты: детерминизм §5 избавляет от
            // передачи всей карточки в URI. MainActivity — singleTop,
            // повторные тапы не плодят задачи.
            val uri = uriDate?.let {
                Uri.parse("$URI_SCHEME://$URI_HOST?$URI_DATE_PARAM=$it")
            }
            setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri),
            )
        }
        appWidgetIds.forEach { id -> appWidgetManager.updateAppWidget(id, views) }
    }

    private companion object {
        // Контракт с lib/services/widget_sync_service.dart — менять только вместе.
        const val KEY_DB_JSON = "word_db_json"
        const val KEY_DATE = "widget.date"
        const val KEY_WORD = "widget.word"
        const val KEY_TRANSCRIPTION = "widget.transcription"
        const val KEY_TRANSLATION = "widget.translation"

        /// Этап 19 (B-005): язык переводов виджета для автономного пересчёта.
        const val KEY_TRANSLATION_LANG = "widget.translation_lang"
        const val DEFAULT_LANG = "ru"
        const val KEY_EXAMPLE = "widget.example"
        const val URI_SCHEME = "wordoftheday"
        const val URI_HOST = "word"
        const val URI_DATE_PARAM = "date"
    }
}

