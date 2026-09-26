package com.english.widget.eng_widget_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Провайдер виджета «Слово дня» — ЭТАП 4 (мост Flutter ↔ виджет).
 *
 * Поля слова дня читает из SharedPreferences: их пишет `WidgetSyncService`
 * на Dart через `HomeWidget.saveWidgetData`. Тап открывает карточку этого
 * дня — `HomeWidgetLaunchIntent` с URI `wordoftheday://word?date=…`
 * (Flutter ловит через `initiallyLaunchedFromHomeWidget()`/`widgetClicked`).
 *
 * Ключи и схема URI — общий контракт с `widget_sync_service.dart`
 * (PLAN.md §6); менять только синхронно.
 *
 * ЭТАП 5: провайдер сам пересчитает слово дня по формуле §5 из базы
 * (ключ `word_db_json` в prefs) и повесит полуночный будильник.
 */
class WordWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        // Один и тот же RemoteViews для всех экземпляров виджета —
        // слово дня общее.
        val date = widgetData.getString(KEY_DATE, null)
        val views = RemoteViews(context.packageName, R.layout.word_widget).apply {
            if (date == null) {
                // Виджет добавили до первого запуска приложения, prefs пусты
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
            } else {
                setTextViewText(R.id.widget_word, widgetData.getString(KEY_WORD, date))
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
            }

            // Тап → карточка именно этой даты: детерминизм §5 избавляет от
            // передачи всей карточки в URI. MainActivity — singleTop,
            // повторные тапы не плодят задачи.
            val uri = date?.let {
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
        const val KEY_DATE = "widget.date"
        const val KEY_WORD = "widget.word"
        const val KEY_TRANSCRIPTION = "widget.transcription"
        const val KEY_TRANSLATION = "widget.translation"
        const val KEY_EXAMPLE = "widget.example"
        const val URI_SCHEME = "wordoftheday"
        const val URI_HOST = "word"
        const val URI_DATE_PARAM = "date"
    }
}

