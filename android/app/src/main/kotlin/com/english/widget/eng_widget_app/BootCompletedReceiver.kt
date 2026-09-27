package com.english.widget.eng_widget_app

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent

/**
 * Этап 5: после перезагрузки виджет молчал бы до первого системного
 * `updatePeriodMillis`-тика. Ресивер сразу по BOOT_COMPLETED просит систему
 * вызвать `onUpdate` провайдера (риск №2 в PLAN.md §9).
 *
 * Приложение не запускается: провайдер пересчитает слово дня сам из
 * `word_db_json` (PLAN.md §6). Право RECEIVE_BOOT_COMPLETED в манифесте;
 * `exported="false"` — рассылка системная, защищённая.
 */
class BootCompletedReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        val provider = ComponentName(context, WordWidgetProvider::class.java)
        val ids = AppWidgetManager.getInstance(context).getAppWidgetIds(provider)
        if (ids.isEmpty()) return // виджет не добавлен — делать нечего

        // Явный интент себе же: AppWidgetProvider разложит его в onUpdate.
        context.sendBroadcast(
            Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE).apply {
                component = provider
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            },
        )
    }
}
