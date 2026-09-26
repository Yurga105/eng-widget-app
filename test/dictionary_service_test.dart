import 'package:flutter_test/flutter_test.dart';

import 'package:eng_widget_app/models/word_entry.dart';
import 'package:eng_widget_app/services/dictionary_service.dart';

/// Мини-словарь для тестов кэша и обработки ошибок (не трогает ассеты).
const String miniDbJson = '{"version":1,"words":['
    '{"id":1,"word":"test","transcription":"/test/",'
    '"translation":"тест","example":"This is a test.",'
    '"example_ru":"Это тест.","type":"word"}]}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // доступ к реальным ассетам

  group('DictionaryService — реальный assets/words_db.json', () {
    late DictionaryService service;

    setUp(() {
      service = DictionaryService();
    });

    test('база содержит 150–200 записей', () async {
      final words = await service.load();

      expect(words.length, inInclusiveRange(150, 200));
    });

    test('каждая запись валидна (PLAN.md §4)', () async {
      final words = await service.load();

      for (final word in words) {
        expect(word.id, greaterThan(0), reason: 'id должен быть > 0');
        expect(
          word.word.trim(),
          isNotEmpty,
          reason: 'пустое слово, id=${word.id}',
        );
        expect(
          word.transcription.startsWith('/') &&
              word.transcription.endsWith('/'),
          isTrue,
          reason: 'IPA должна быть в слэшах, id=${word.id}',
        );
        expect(
          word.translation.trim(),
          isNotEmpty,
          reason: 'пустой перевод, id=${word.id}',
        );
        expect(
          word.translation.length,
          lessThanOrEqualTo(60),
          reason: 'перевод длиннее 60 символов, id=${word.id}',
        );
        expect(
          word.example.trim(),
          isNotEmpty,
          reason: 'пустой пример, id=${word.id}',
        );
        expect(
          word.example.length,
          lessThanOrEqualTo(90),
          reason: 'пример длиннее 90 символов, id=${word.id}',
        );
        expect(
          word.exampleRu.trim(),
          isNotEmpty,
          reason: 'пустой перевод примера, id=${word.id}',
        );
      }
    });

    test('id уникальны и идут подряд от 1', () async {
      final words = await service.load();
      final ids = words.map((word) => word.id).toList();

      expect(ids.toSet().length, ids.length, reason: 'найдены дубликаты id');
      expect(ids, equals(List<int>.generate(ids.length, (i) => i + 1)));
    });

    test('типы распределены ~50/50: слова против идиом и фразовых', () async {
      final words = await service.load();
      final singleWords =
          words.where((word) => word.type == WordType.word).length;
      final idiomsAndPhrasal = words.length - singleWords;

      expect(
        singleWords / words.length,
        inInclusiveRange(0.45, 0.55),
        reason: 'доля одиночных слов должна быть около 50%',
      );
      expect(idiomsAndPhrasal, greaterThan(0));
    });
  });

  group('DictionaryService — кэш и ошибки (фейковый загрузчик)', () {
    test('повторный load не читает ассет заново', () async {
      var calls = 0;
      final service = DictionaryService(
        assetLoader: (_) async {
          calls++;
          return miniDbJson;
        },
      );

      final first = await service.load();
      final second = await service.load();

      expect(calls, 1);
      expect(first, hasLength(1));
      expect(second, hasLength(1));
    });

    test('отсутствует массив words — FormatException', () async {
      final service =
          DictionaryService(assetLoader: (_) async => '{"version":1}');

      expect(service.load(), throwsFormatException);
    });

    test('верхний уровень не объект — FormatException', () async {
      final service = DictionaryService(assetLoader: (_) async => '[1,2,3]');

      expect(service.load(), throwsFormatException);
    });

    test('битый JSON — FormatException', () async {
      final service = DictionaryService(assetLoader: (_) async => '{oops');

      expect(service.load(), throwsFormatException);
    });
  });
}
