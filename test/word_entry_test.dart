import 'dart:convert';
import 'dart:io';

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

  group('WordEntry — переводы v2 (этап 19, идея B-005)', () {
    // База v1: карт переводов нет вообще.
    final v1 = WordEntry.fromJson(const <String, dynamic>{
      'id': 7,
      'word': 'avoid',
      'transcription': '/əˈvɔɪd/',
      'translation': 'избегать, уклоняться',
      'example': 'I avoid news before coffee.',
      'example_ru': 'Я не читаю новости до кофе.',
      'type': 'word',
    });

    // База v2: карты на все пять языков, ru — копия полей v1.
    final v2 = WordEntry.fromJson(const <String, dynamic>{
      'id': 7,
      'word': 'avoid',
      'transcription': '/əˈvɔɪd/',
      'translation': 'избегать, уклоняться',
      'translations': <String, dynamic>{
        'ru': 'избегать, уклоняться',
        'id': 'menghindari',
        'de': 'vermeiden',
        'fr': 'éviter',
        'es': 'evitar',
      },
      'example': 'I avoid news before coffee.',
      'example_ru': 'Я не читаю новости до кофе.',
      'example_translations': <String, dynamic>{
        'ru': 'Я не читаю новости до кофе.',
        'id': 'Saya tidak membaca berita sebelum kopi.',
        'de': 'Ich lese keine Nachrichten vor dem Kaffee.',
        'fr': "Je ne lis pas les actualités avant le café.",
        'es': 'No leo noticias antes del café.',
      },
      'type': 'word',
    });

    test('v1-запись без карт — фолбэк на русские поля v1', () {
      expect(v1.translations, isEmpty);
      expect(v1.exampleTranslations, isEmpty);
      expect(v1.translationFor('ru'), 'избегать, уклоняться');
      expect(v1.translationFor('id'), 'избегать, уклоняться');
      expect(v1.translationFor('de'), 'избегать, уклоняться');
      expect(v1.exampleTranslationFor('es'), 'Я не читаю новости до кофе.');
    });

    test('v2-запись отдаёт перевод выбранного языка', () {
      expect(v2.translationFor('ru'), 'избегать, уклоняться');
      expect(v2.translationFor('id'), 'menghindari');
      expect(v2.translationFor('de'), 'vermeiden');
      expect(v2.translationFor('fr'), 'éviter');
      expect(v2.translationFor('es'), 'evitar');
      expect(v2.exampleTranslationFor('de'),
          'Ich lese keine Nachrichten vor dem Kaffee.');
      expect(v2.exampleTranslationFor('es'), 'No leo noticias antes del café.');
    });

    test('языка нет в карте v2 — фолбэк на русское поле v1', () {
      const partial = WordEntry(
        id: 1,
        word: 'avoid',
        transcription: '/əˈvɔɪd/',
        translation: 'избегать',
        example: 'Example.',
        exampleRu: 'Пример.',
        type: WordType.word,
        translations: <String, String>{'ru': 'избегать', 'id': 'menghindari'},
      );

      expect(partial.translationFor('id'), 'menghindari');
      expect(partial.translationFor('de'), 'избегать',
          reason: 'de в карте нет — русский фолбэк');
    });

    test('lenient-разбор: кривые карты и пустые значения отбрасываются', () {
      final entry = WordEntry.fromJson(const <String, dynamic>{
        'id': 1,
        'word': 'avoid',
        'transcription': '/əˈvɔɪd/',
        'translation': 'избегать',
        'translations': <String, dynamic>{
          'id': 'menghindari',
          'de': '', // пустое значение — пропускается
          'fr': 7, // не строка-значение — пропускается
        },
        'example': 'Example.',
        'example_ru': 'Пример.',
        'example_translations': 'не карта',
        'type': 'word',
      });

      expect(entry.translations.keys, ['id']);
      expect(entry.exampleTranslations, isEmpty);
      expect(entry.translationFor('de'), 'избегать');
    });

    test('toJson: пустые карты не пишутся (v1-совместимость), полные — пишутся',
        () {
      expect(v1.toJson().containsKey('translations'), isFalse);
      expect(v1.toJson().containsKey('example_translations'), isFalse);

      final restored = WordEntry.fromJson(v2.toJson());
      expect(restored, v2);
      expect(restored.translationFor('fr'), 'éviter');
      expect(restored.toJson()['translations'], isA<Map>());
    });

    test('равенство учитывает карты переводов', () {
      expect(v2, isNot(v1), reason: 'разные карты переводов — разные записи');
      final copy = WordEntry.fromJson(v2.toJson());
      expect(copy, v2);
      // Одинаковая длина карт, разное содержание → разные записи.
      final other = WordEntry.fromJson(<String, dynamic>{
        ...v2.toJson(),
        'translations': <String, dynamic>{
          'ru': 'избегать, уклоняться',
          'id': 'lain',
          'de': 'anders',
          'fr': 'autre',
          'es': 'otro',
        },
      });
      expect(other, isNot(v2));
      // hashCode строится на длинах карт — совпадение хэшей при разном
      // содержимом допустимо (контракт == / hashCode не нарушен).
      expect(other.hashCode, v2.hashCode);
    });
  });

  group('words_db.json — целостность v2 (этап 19, идея B-005)', () {
    final raw = File('assets/words_db.json').readAsStringSync();
    final db = jsonDecode(raw) as Map<String, dynamic>;
    final entries =
        (db['words'] as List).cast<Map<String, dynamic>>().map(WordEntry.fromJson).toList();
    const langs = <String>['ru', 'id', 'de', 'fr', 'es'];

    test('словарь переведён на формат v2', () {
      expect(db['version'], 2);
      expect(entries, isNotEmpty);
    });

    test('каждая запись имеет переводы и примеры на всех 5 языках', () {
      final ids = <int>{};
      for (final entry in entries) {
        expect(ids.add(entry.id), isTrue, reason: 'дубликат id=${entry.id}');

        for (final lang in langs) {
          expect(
            entry.translations[lang],
            allOf(isA<String>(), isNotEmpty),
            reason: '${entry.word}: translations.$lang пуст',
          );
          expect(
            entry.exampleTranslations[lang],
            allOf(isA<String>(), isNotEmpty),
            reason: '${entry.word}: example_translations.$lang пуст',
          );
        }

        // ru-ключи обязаны совпадать с v1-полями.
        expect(entry.translations['ru'], entry.translation);
        expect(entry.exampleTranslations['ru'], entry.exampleRu);

        // Лимиты карточки виджета: перевод ≤ 60, пример ≤ 90 символов.
        for (final lang in const <String>['id', 'de', 'fr', 'es']) {
          expect(
            entry.translations[lang]!.length,
            lessThanOrEqualTo(60),
            reason: '${entry.word}: перевод $lang длиннее 60',
          );
          expect(
            entry.exampleTranslations[lang]!.length,
            lessThanOrEqualTo(90),
            reason: '${entry.word}: пример $lang длиннее 90',
          );
        }
      }
      expect(entries, hasLength(160));
    });
  });
}
