package com.english.widget.eng_widget_app

import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * Паритет формулы «слова дня» с Dart (PLAN.md §5, риск №4 в §9).
 *
 * ТА ЖЕ таблица векторов, что в `test/word_of_day_service_test.dart`;
 * при изменении размера базы N (сейчас 160) пересчитать в обеих сторонах
 * одновременно:
 *
 * | дата       | seed     | index = seed % 160 | id записи |
 * |------------|----------|--------------------|----------|
 * | 1999-12-31 | 19991231 | 31                 | 32       |
 * | 2000-01-01 | 20000101 | 101                | 102      |
 * | 2024-02-29 | 20240229 | 69                 | 70       |
 * | 2025-06-15 | 20250615 | 55                 | 56       |
 * | 2026-09-26 | 20260926 | 126                | 127      |
 * | 2026-09-27 | 20260927 | 127                | 128      |
 * | 2026-12-31 | 20261231 | 111                | 112      |
 * | 2027-01-01 | 20270101 | 21                 | 22       |
 */
class WordOfDayCalculatorTest {

    @Test
    fun `seed сворачивает дату в число yyyyMMdd`() {
        assertEquals(20260926, WordOfDayCalculator.seedFor(LocalDate.of(2026, 9, 26)))
        assertEquals(20240229, WordOfDayCalculator.seedFor(LocalDate.of(2024, 2, 29)))
        assertEquals(20000101, WordOfDayCalculator.seedFor(LocalDate.of(2000, 1, 1)))
    }

    @Test
    fun `index для фиксированных дат при N = 160`() {
        val vectors = listOf(
            LocalDate.of(1999, 12, 31) to 31,
            LocalDate.of(2000, 1, 1) to 101,
            LocalDate.of(2024, 2, 29) to 69,
            LocalDate.of(2025, 6, 15) to 55,
            LocalDate.of(2026, 9, 26) to 126,
            LocalDate.of(2026, 9, 27) to 127,
            LocalDate.of(2026, 12, 31) to 111,
            LocalDate.of(2027, 1, 1) to 21,
        )
        vectors.forEach { (date, index) ->
            assertEquals("вектор $date разошёлся с Dart", index, WordOfDayCalculator.indexFor(date, 160))
        }
    }

    @Test
    fun `index зависит от размера базы N`() {
        // 20270101 mod 100 = 1; 20260926 mod 7 = 0 — те же значения, что в Dart-тесте.
        assertEquals(1, WordOfDayCalculator.indexFor(LocalDate.of(2027, 1, 1), 100))
        assertEquals(0, WordOfDayCalculator.indexFor(LocalDate.of(2026, 9, 26), 7))
    }

    @Test
    fun `total меньше или равен 0 — IllegalArgumentException (аналог ArgumentError)`() {
        assertThrows(IllegalArgumentException::class.java) {
            WordOfDayCalculator.indexFor(LocalDate.of(2026, 9, 26), 0)
        }
        assertThrows(IllegalArgumentException::class.java) {
            WordOfDayCalculator.indexFor(LocalDate.of(2026, 9, 26), -5)
        }
    }

    @Test
    fun `isoDate — формат yyyy-MM-dd с ведущими нулями (контракт с Dart isoDate)`() {
        assertEquals("2026-09-05", WordOfDayCalculator.isoDate(LocalDate.of(2026, 9, 5)))
        assertEquals("2027-01-01", WordOfDayCalculator.isoDate(LocalDate.of(2027, 1, 1)))
        assertEquals("2026-12-31", WordOfDayCalculator.isoDate(LocalDate.of(2026, 12, 31)))
    }

    /** Та же мини-база, что в `test/widget_sync_service_test.dart`. */
    private val miniDb =
        """
        {"version":1,"words":[
        {"id":1,"word":"alpha","transcription":"/ˈælfə/",
        "translation":"альфа","example":"Alpha example.",
        "example_ru":"Пример альфы.","type":"word"},
        {"id":2,"word":"beta hang out","transcription":"/ˈbiːtə/",
        "translation":"бета","example":"Beta example.",
        "example_ru":"Пример беты.","type":"idiom"}]}
        """.trimIndent()

    @Test
    fun `entryFor по мини-базе — та же арифметика, что в Dart-тестах`() {
        // 20260926 % 2 = 0 → «alpha»; 20260927 % 2 = 1 → «beta hang out».
        val alpha = WordOfDayCalculator.entryFor(miniDb, LocalDate.of(2026, 9, 26))!!
        assertEquals("alpha", alpha.word)
        assertEquals("/ˈælfə/", alpha.transcription)
        assertEquals("альфа", alpha.translation)
        assertEquals("Alpha example.", alpha.example)

        val beta = WordOfDayCalculator.entryFor(miniDb, LocalDate.of(2026, 9, 27))!!
        assertEquals("beta hang out", beta.word)
        assertEquals("бета", beta.translation)
    }

    @Test
    fun `entryFor — битый JSON, пустая база, нет массива words → null (fallback виджета)`() {
        val date = LocalDate.of(2026, 9, 27)
        assertNull(WordOfDayCalculator.entryFor("{oops", date))
        assertNull(WordOfDayCalculator.entryFor("""{"version":1,"words":[]}""", date))
        assertNull(WordOfDayCalculator.entryFor("""{"version":1}""", date))
        assertNull(WordOfDayCalculator.entryFor("[1,2,3]", date))
    }

    /** v2 мини-база с картами переводов (этап 19, B-005); та же
     *  арифметика seed, что у мини-базы v1 выше. */
    private val miniDbV2 =
        """
        {"version":2,"words":[
        {"id":1,"word":"alpha","transcription":"/ˈælfə/",
        "translation":"альфа","example":"Alpha example.",
        "example_ru":"Пример альфы.","type":"word",
        "translations":{"ru":"альфа","de":"Alpha auf Deutsch"},
        "example_translations":{"ru":"Пример альфы.","de":"Alpha-Beispiel."}},
        {"id":2,"word":"beta hang out","transcription":"/ˈbiːtə/",
        "translation":"бета","example":"Beta example.",
        "example_ru":"Пример беты.","type":"idiom",
        "translations":{"ru":"бета","fr":"bêta"}}]}
        """.trimIndent()

    @Test
    fun `entryFor с языком — перевод из карты v2, фолбэк на русский (этап 19)`() {
        // 20260926 % 2 = 0 → запись 1 (de есть, fr нет).
        val de = WordOfDayCalculator.entryFor(miniDbV2, LocalDate.of(2026, 9, 26), "de")!!
        assertEquals("Alpha auf Deutsch", de.translation)
        assertEquals("alpha", de.word)
        assertEquals("Alpha example.", de.example)

        val fr = WordOfDayCalculator.entryFor(miniDbV2, LocalDate.of(2026, 9, 26), "fr")!!
        assertEquals("альфа", fr.translation)

        // Без языка — прежнее поведение (русское поле v1).
        val ru = WordOfDayCalculator.entryFor(miniDbV2, LocalDate.of(2026, 9, 26))!!
        assertEquals("альфа", ru.translation)
    }

    @Test
    fun `entryFor — пустое значение в карте → фолбэк на русское поле (паритет Dart)`() {
        val db =
            """
            {"version":2,"words":[
            {"id":1,"word":"a","translation":"ру",
            "translations":{"ru":"ру","de":""}}]}
            """.trimIndent()
        val entry = WordOfDayCalculator.entryFor(db, LocalDate.of(2026, 9, 26), "de")!!
        assertEquals("ру", entry.translation)
    }
}
