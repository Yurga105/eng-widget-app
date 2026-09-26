package com.english.widget.eng_widget_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Провайдер виджета «Слово дня» — ЭТАП 3 (статика).
 *
 * Сейчас рисует захардкоженное слово (запись №1 базы — «accomplish»),
 * тексты в initialLayout совпадают, поэтому «миганий» до первого
 * [onUpdate] нет.
 *
 * Дальнейшие этапы:
 *  - 4: поля приходят из SharedPreferences (пишет WidgetSyncService на Dart),
 *    тап открывает карточку дня через HomeWidgetLaunchIntent с URI даты;
 *  - 5: провайдер сам пересчитывает слово дня по формуле PLAN.md §5
 *    (seed = yyyy*10000 + MM*100 + dd; index = seed % N) и вешает
 *    полуночный будильник вместо updatePeriodMillis.
 */
class WordWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        // Один и тот же RemoteViews для всех экземпляров виджета —
        // слово дня общее.
        val views = RemoteViews(context.packageName, R.layout.word_widget).apply {
            setTextViewText(R.id.widget_word, STATIC_WORD)
            setTextViewText(R.id.widget_transcription, STATIC_TRANSCRIPTION)
            setTextViewText(R.id.widget_translation, STATIC_TRANSLATION)
            setTextViewText(R.id.widget_example, STATIC_EXAMPLE)

            // Тап по виджету открывает приложение (этап 4 заменит на
            // HomeWidgetLaunchIntent с датой в URI). MainActivity —
            // singleTop, повторные тапы не плодят задачи.
            val openApp = PendingIntent.getActivity(
                context,
                REQUEST_OPEN_APP,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            setOnClickPendingIntent(R.id.widget_root, openApp)
        }
        appWidgetIds.forEach { id -> appWidgetManager.updateAppWidget(id, views) }
    }

    private companion object {
        // Запись №1 из assets/words_db.json — до интеграции с Dart (этап 4).
        const val STATIC_WORD = "accomplish"
        const val STATIC_TRANSCRIPTION = "/əˈkɑːmplɪʃ/"
        const val STATIC_TRANSLATION = "достигать, выполнять"
        const val STATIC_EXAMPLE = "She accomplished all her goals this year."

        const val REQUEST_OPEN_APP = 0
    }
}
