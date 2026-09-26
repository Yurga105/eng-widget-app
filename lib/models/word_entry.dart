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
class WordEntry {
  const WordEntry({
    required this.id,
    required this.word,
    required this.transcription,
    required this.translation,
    required this.example,
    required this.exampleRu,
    required this.type,
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
    );
  }

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

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'word': word,
        'transcription': transcription,
        'translation': translation,
        'example': example,
        'example_ru': exampleRu,
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
      other.type == type;

  @override
  int get hashCode => Object.hash(
        id,
        word,
        transcription,
        translation,
        example,
        exampleRu,
        type,
      );

  @override
  String toString() => 'WordEntry(#$id ${type.jsonValue} "$word")';
}
