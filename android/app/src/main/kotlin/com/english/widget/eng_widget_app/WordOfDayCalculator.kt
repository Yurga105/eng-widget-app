package com.english.widget.eng_widget_app

import java.time.LocalDate
import java.util.Locale
import org.json.JSONObject

/**
 * Чистая математика «слова дня» — этап 5 (PLAN.md §6).
 *
 * КОНТРАКТ ПАРИТЕТА с Dart (риск №4 в PLAN.md §9): арифметика повторяет
 * `WordOfDayService` 1:1, тест-векторы дат общие для обеих сторон —
 * `WordOfDayCalculatorTest` ↔ `test/word_of_day_service_test.dart`.
 * Менять формулу только синхронно в обоих файлах.
 */
object WordOfDayCalculator {

    /** `seed = yyyy * 10000 + MM * 100 + dd` — идентично `seedFor` на Dart. */
    fun seedFor(date: LocalDate): Int =
        date.year * 10000 + date.monthValue * 100 + date.dayOfMonth

    /** `index = seed mod total`; итог всегда в `0..total-1`.
     *  `total <= 0` — ошибка данных (аналог `ArgumentError` на Dart). */
    fun indexFor(date: LocalDate, total: Int): Int {
        require(total > 0) { "размер базы должен быть > 0 (total=$total)" }
        return seedFor(date) % total
    }

    /** `yyyy-MM-dd` с ведущими нулями — формат даты в URI тапа
     *  (контракт с `WidgetSyncService.isoDate` на Dart).
     *  Locale.ROOT — только ASCII-цифры независимо от языка системы. */
    fun isoDate(date: LocalDate): String =
        String.format(Locale.ROOT, "%04d-%02d-%02d", date.year, date.monthValue, date.dayOfMonth)

    /** Поля записи, нужные виджету (перевод примера виджету не показываем). */
    data class WidgetWord(
        val word: String,
        val transcription: String,
        val translation: String,
        val example: String,
    )

    /**
     * Слово дня для [date] из JSON базы (формат `assets/words_db.json`,
     * ключ prefs `word_db_json`). [lang] — код языка переводов (этап 19,
     * идея B-005; ключ prefs `widget.translation_lang`, паритет
     * `WordEntry.translationFor` на Dart): перевод берётся из карты v2
     * `translations` записи, при отсутствии карты/языка/пустом значении —
     * русское поле v1. Возвращает `null`, если база не читается
     * или пуста — пусть виджет уходит на fallback-ключи / плейсхолдер
     * (риски №7–8 в PLAN.md §9), а не падает.
     */
    fun entryFor(dbJson: String, date: LocalDate, lang: String = "ru"): WidgetWord? = try {
        val words = JSONObject(dbJson).getJSONArray("words")
        val entry = words.getJSONObject(indexFor(date, words.length()))
        WidgetWord(
            word = entry.getString("word"),
            transcription = entry.optString("transcription", ""),
            translation = translationFor(entry, lang),
            example = entry.optString("example", ""),
        )
    } catch (_: Exception) {
        null
    }

    /** Перевод записи на [lang] из карты v2 `translations`; нет карты,
     *  нет ключа или пусто — русское поле v1 (как на Dart). */
    private fun translationFor(entry: JSONObject, lang: String): String {
        val fallback = entry.optString("translation", "")
        val translations = entry.optJSONObject("translations") ?: return fallback
        return translations.optString(lang, fallback).ifEmpty { fallback }
    }
}
