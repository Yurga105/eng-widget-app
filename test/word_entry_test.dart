import 'package:flutter_test/flutter_test.dart';

import 'package:eng_widget_app/models/word_entry.dart';

void main() {
  group('WordType.fromJsonValue', () {
    test('разбирает все допустимые значения из JSON', () {
      expect(WordType.fromJsonValue('word'), WordType.word);
      expect(WordType.fromJsonValue('idiom'), WordType.idiom);
      expect(WordType.fromJsonValue('phrasal_verb'), WordType.phrasalVerb);
    });

    test('неизвестное значение — ArgumentError', () {
      expect(() => WordType.fromJsonValue('slang'), throwsArgumentError);
    });
  });

  group('WordEntry', () {
    const source = WordEntry(
      id: 7,
      word: 'avoid',
      transcription: '/əˈvɔɪd/',
      translation: 'избегать, уклоняться',
      example: 'I avoid news before coffee.',
      exampleRu: 'Я не читаю новости до кофе.',
      type: WordType.word,
    );

    test('fromJson заполняет все поля', () {
      final entry = WordEntry.fromJson(const <String, dynamic>{
        'id': 7,
        'word': 'avoid',
        'transcription': '/əˈvɔɪd/',
        'translation': 'избегать, уклоняться',
        'example': 'I avoid news before coffee.',
        'example_ru': 'Я не читаю новости до кофе.',
        'type': 'word',
      });

      expect(entry, source);
    });

    test('toJson — полный обратный круг', () {
      final restored = WordEntry.fromJson(source.toJson());

      expect(restored, source);
      expect(source.toJson()['type'], 'word');
    });

    test('idiom и phrasal_verb маппятся в соответствующие типы', () {
      final idiom = WordEntry.fromJson(const <String, dynamic>{
        'id': 2,
        'word': 'piece of cake',
        'transcription': '/ˌpiːs əv ˈkeɪk/',
        'translation': 'проще простого',
        'example': 'The exam was a piece of cake.',
        'example_ru': 'Экзамен был проще простого.',
        'type': 'idiom',
      });
      final phrasal = WordEntry.fromJson(const <String, dynamic>{
        'id': 3,
        'word': 'give up',
        'transcription': '/ˌɡɪv ˈʌp/',
        'translation': 'сдаваться, бросать',
        'example': 'Never give up after the first attempt.',
        'example_ru': 'Никогда не сдавайся с первой попытки.',
        'type': 'phrasal_verb',
      });

      expect(idiom.type, WordType.idiom);
      expect(phrasal.type, WordType.phrasalVerb);
    });
  });
}
