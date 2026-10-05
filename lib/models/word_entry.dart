import 'package:flutter/foundation.dart' show mapEquals;

/// Тип единицы словаря (PLAN.md §4).
enum WordType {
  word('word'),
  idiom('idiom'),
  phrasalVerb('phrasal_verb');

  const WordType(this.jsonValue);

  /// Значение поля `type` в words_db.json.
  final String jsonValue;

  /// Разбирает значение поля `type`; для неизвестного значения бросает
  /// [ArgumentError] с понятным сообщением.
  static WordType fromJsonValue(String value) {
    for (final type in WordType.values) {
      if (type.jsonValue == value) return type;
    }
    throw ArgumentError('Неизвестное значение type: "$value"');
  }
}

/// Одна запись локального словаря `assets/words_db.json` (PLAN.md §4).
///
/// Этап 19 (идея B-005, часть 2) — схема v2: кроме полей v1 (перевод на
/// русский) запись может нести карты переводов `translations` и
/// `example_translations` вида `{ru, id, de, fr, es}`. v1-поля остаются
/// обязательными — это русский фолбэк для обновлённых установок (в prefs
/// виджета может лежать старая база) и для записей без карт. Для записей
/// v2 `translations['ru']` — копия поля `translation`, поэтому фолбэк
/// срабатывает только на действительно старых данных.
class WordEntry {
  const WordEntry({
    required this.id,
    required this.word,
    required this.transcription,
    required this.translation,
    required this.example,
    required this.exampleRu,
    required this.type,
    this.translations = const <String, String>{},
    this.exampleTranslations = const <String, String>{},
  });

  factory WordEntry.fromJson(Map<String, dynamic> json) {
    return WordEntry(
      id: json['id'] as int,
      word: json['word'] as String,
      transcription: json['transcription'] as String,
      translation: json['translation'] as String,
      example: json['example'] as String,
      exampleRu: json['example_ru'] as String,
      type: WordType.fromJsonValue(json['type'] as String),
      translations: _stringMap(json['translations']),
      exampleTranslations: _stringMap(json['example_translations']),
    );
  }

  /// Перевод слова по кодам языков (v2) — `ru` обязателен в базе v2.
  final Map<String, String> translations;

  /// Перевод примера по кодам языков (v2) — `ru` обязателен в базе v2.
  final Map<String, String> exampleTranslations;

  /// Разбирает карту переводов lenient-но: не-карта, не-строки и пустые
  /// значения молча пропускаются — чужой ключ или кривая запись не должны
  /// ронять разбор всей базы.
  static Map<String, String> _stringMap(Object? raw) {
    if (raw is! Map) {
      return const <String, String>{};
    }
    return <String, String>{
      for (final entry in raw.entries)
        if (entry.key is String &&
            entry.value is String &&
            (entry.value as String).isNotEmpty)
          entry.key as String: entry.value as String,
    };
  }

  static String? _pick(Map<String, String> map, String languageCode) {
    final value = map[languageCode];
    return value == null || value.isEmpty ? null : value;
  }

  /// Перевод слова на язык [languageCode]; карты нет или язык в ней
  /// отсутствует — поле v1 (русский) — фолбэк обновлённых установок.
  String translationFor(String languageCode) =>
      _pick(translations, languageCode) ?? translation;

  /// Перевод примера на язык [languageCode]; фолбэк — `example_ru`.
  String exampleTranslationFor(String languageCode) =>
      _pick(exampleTranslations, languageCode) ?? exampleRu;

  final int id;
  final String word;

  /// Американская IPA в слэшах, например `/əˈvɔɪd/`.
  final String transcription;

  /// 1–2 основных значения через запятую (≤ 60 символов).
  final String translation;

  /// Пример употребления (английский, ≤ 90 символов).
  final String example;

  /// Естественный перевод примера.
  final String exampleRu;

  final WordType type;

  /// Поля v1 идут первыми, карты v2 — сразу за «своим» полем; пустые
  /// карты не пишутся — сериализация записи без переводов байт-в-байт
  /// совпадает с v1 (parity-тесты Kotlin на мини-базе v1 не ломаются).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'word': word,
        'transcription': transcription,
        'translation': translation,
        if (translations.isNotEmpty) 'translations': translations,
        'example': example,
        'example_ru': exampleRu,
        if (exampleTranslations.isNotEmpty)
          'example_translations': exampleTranslations,
        'type': type.jsonValue,
      };

  @override
  bool operator ==(Object other) =>
      other is WordEntry &&
      other.id == id &&
      other.word == word &&
      other.transcription == transcription &&
      other.translation == translation &&
      other.example == example &&
      other.exampleRu == exampleRu &&
      other.type == type &&
      mapEquals(other.translations, translations) &&
      mapEquals(other.exampleTranslations, exampleTranslations);

  @override
  int get hashCode => Object.hash(
        id,
        word,
        transcription,
        translation,
        example,
        exampleRu,
        type,
        translations.length,
        exampleTranslations.length,
      );

  @override
  String toString() => 'WordEntry(#$id ${type.jsonValue} "$word")';
}
