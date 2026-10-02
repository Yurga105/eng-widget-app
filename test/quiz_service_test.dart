import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:eng_widget_app/models/word_entry.dart';
import 'package:eng_widget_app/services/quiz_service.dart';

/// Запись словаря для тестов генерации.
WordEntry entry(
  int id,
  String word,
  String translation, {
  WordType type = WordType.word,
}) => WordEntry(
  id: id,
  word: word,
  transcription: '/t/',
  translation: translation,
  example: 'example',
  exampleRu: 'пример',
  type: type,
);

/// Словарь из 6 записей: 3 слова, 2 идиомы, 1 фразовый глагол.
List<WordEntry> dictionary() => <WordEntry>[
  entry(1, 'alpha', 'перевод-1'),
  entry(2, 'beta', 'перевод-2'),
  entry(3, 'gamma', 'перевод-3'),
  entry(4, 'delta', 'перевод-4', type: WordType.idiom),
  entry(5, 'epsilon', 'перевод-5', type: WordType.idiom),
  entry(6, 'zeta', 'перевод-6', type: WordType.phrasalVerb),
];

void main() {
  group('generate — сборка вопросов (этап 14)', () {
    test('пул достаточный — вопросы только из пула, count штук', () {
      final dict = dictionary();
      final pool = dict.take(5).toList();
      final questions = QuizService.generate(
        questionPool: pool,
        dictionary: dict,
        random: Random(1),
      );

      expect(questions, hasLength(QuizService.questionCount));
      final poolIds = pool.map((e) => e.id).toSet();
      expect(questions.every((q) => poolIds.contains(q.entry.id)), isTrue);
    });

    test('пул мал — добор случайными записями словаря, без дублей записей', () {
      final dict = dictionary();
      final questions = QuizService.generate(
        questionPool: <WordEntry>[dict.first],
        dictionary: dict,
        random: Random(1),
      );

      expect(questions, hasLength(QuizService.questionCount));
      final ids = questions.map((q) => q.entry.id).toList();
      expect(ids.toSet(), hasLength(ids.length), reason: 'дублей записей нет');
      expect(ids, contains(dict.first.id), reason: 'пул в вопросах сохранён');
      expect(ids.toSet().difference(dict.map((e) => e.id).toSet()), isEmpty);
    });

    test('вопрос: 4 уникальные опции, верный перевод на correctIndex', () {
      final dict = dictionary();
      final questions = QuizService.generate(
        questionPool: dict,
        dictionary: dict,
        random: Random(1),
      );

      for (final q in questions) {
        expect(q.options, hasLength(QuizService.optionsPerQuestion));
        expect(
          q.options.toSet(),
          hasLength(q.options.length),
          reason: 'опции уникальны',
        );
        expect(
          q.options[q.correctIndex],
          q.entry.translation,
          reason: 'correctIndex указывает на перевод записи',
        );
        expect(q.options.where((o) => o == q.entry.translation), hasLength(1));
      }
    });

    test('дистракторы предпочитают записи того же типа', () {
      // 4 идиомы + 1 слово: вопрос по идиоме должен набрать дистракторы
      // из идиом — перевод слова в опции не попадёт.
      final dict = <WordEntry>[
        entry(1, 'alpha', 'перевод-1'),
        entry(2, 'beta', 'перевод-2', type: WordType.idiom),
        entry(3, 'gamma', 'перевод-3', type: WordType.idiom),
        entry(4, 'delta', 'перевод-4', type: WordType.idiom),
        entry(5, 'epsilon', 'перевод-5', type: WordType.idiom),
      ];
      final questions = QuizService.generate(
        questionPool: <WordEntry>[dict[1]], // beta — идиома
        dictionary: dict,
        count: 1,
        random: Random(1),
      );

      final q = questions.single;
      expect(q.entry.id, 2);
      expect(
        q.options,
        isNot(contains('перевод-1')),
        reason: 'слово (другой тип) не нужно, пока есть идиомы',
      );
      expect(
        q.options,
        containsAll(<String>['перевод-3', 'перевод-4', 'перевод-5']),
      );
    });

    test('детерминизм: одинаковый Random — одинаковые вопросы', () {
      final dict = dictionary();
      final a = QuizService.generate(
        questionPool: dict,
        dictionary: dict,
        random: Random(7),
      );
      final b = QuizService.generate(
        questionPool: dict,
        dictionary: dict,
        random: Random(7),
      );

      expect(
        a.map((q) => <Object>[q.entry.id, q.options, q.correctIndex]).toList(),
        b.map((q) => <Object>[q.entry.id, q.options, q.correctIndex]).toList(),
      );
    });

    test('крошечный словарь (< 4 уникальных переводов) — вопросов нет', () {
      final dict = <WordEntry>[
        entry(1, 'alpha', 'перевод-1'),
        entry(2, 'beta', 'перевод-2'),
        entry(3, 'gamma', 'перевод-3'),
      ];
      final questions = QuizService.generate(
        questionPool: dict,
        dictionary: dict,
        random: Random(1),
      );

      expect(questions, isEmpty, reason: 'честных 4 вариантов не собрать');
    });
  });

  group('QuizService — результаты и цикл «3 дня» (этап 14)', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('quiz_service_test');
    });

    tearDown(() {
      tmp.deleteSync(recursive: true);
    });

    QuizService buildService({void Function(DateTime)? onQuizFinished}) =>
        QuizService(
          documentsDirectory: () async => tmp,
          onQuizFinished: onQuizFinished,
        );

    File storageFile() =>
        File('${tmp.path}${Platform.pathSeparator}${QuizService.fileName}');

    test(
      'без прохождений: lastResult null, isDue true, напоминания нет',
      () async {
        final service = buildService();
        await service.load();

        expect(service.lastResult.value, isNull);
        expect(service.nextQuizDate, isNull);
        expect(
          service.isDue(DateTime(2026, 10, 2)),
          isTrue,
          reason: 'первый квиз доступен сразу',
        );
        expect(storageFile().existsSync(), isFalse);
        service.dispose();
      },
    );

    test('recordResult: файл, lastResult, цикл и колбэк напоминания', () async {
      DateTime? notified;
      final service = buildService(onQuizFinished: (next) => notified = next);
      await service.recordResult(
        total: 5,
        correct: 4,
        wrongIds: <int>[7],
        now: DateTime(2026, 10, 2, 18, 30),
      );

      expect(service.lastResult.value!.correct, 4);
      expect(service.lastResult.value!.wrongIds, [7]);
      expect(
        service.nextQuizDate,
        DateTime(2026, 10, 5),
        reason: 'следующий квиз через 3 дня',
      );
      expect(
        notified,
        DateTime(2026, 10, 5),
        reason: 'колбэк получил дату напоминания',
      );

      // Цикл: 3-го и 4-го ещё рано, 5-го — пора.
      expect(service.isDue(DateTime(2026, 10, 4, 23, 59)), isFalse);
      expect(service.isDue(DateTime(2026, 10, 5)), isTrue);

      expect(storageFile().existsSync(), isTrue);
      expect(storageFile().readAsStringSync(), contains('"correct": 4'));
      service.dispose();
    });

    test(
      'персистентность: история переживает новый экземпляр сервиса',
      () async {
        final first = buildService();
        await first.recordResult(
          total: 5,
          correct: 1,
          wrongIds: const <int>[],
          now: DateTime(2026, 9, 30, 9),
        );
        await first.recordResult(
          total: 5,
          correct: 3,
          wrongIds: const <int>[4],
          now: DateTime(2026, 10, 2, 20),
        );
        first.dispose();

        final second = buildService();
        await second.load();
        expect(
          second.lastResult.value!.correct,
          3,
          reason: 'последний результат — свежий',
        );
        expect(second.nextQuizDate, DateTime(2026, 10, 5));
        second.dispose();
      },
    );

    test('история дописывается, а не перезаписывается', () async {
      final service = buildService();
      await service.recordResult(
        total: 5,
        correct: 2,
        wrongIds: const <int>[],
        now: DateTime(2026, 10, 1),
      );
      await service.recordResult(
        total: 5,
        correct: 5,
        wrongIds: const <int>[],
        now: DateTime(2026, 10, 2),
      );

      final decoded =
          jsonDecode(storageFile().readAsStringSync()) as Map<String, dynamic>;
      expect(
        decoded['history'],
        isA<List<dynamic>>().having((l) => l.length, 'length', 2),
        reason: 'оба прохождения в файле',
      );
      service.dispose();
    });

    test('битый JSON — тихий «квизов не было»', () async {
      storageFile().writeAsStringSync('{ не json');
      final service = buildService();
      await service.load();

      expect(service.lastResult.value, isNull);
      expect(service.nextQuizDate, isNull);
      service.dispose();
    });

    test('сбой каталога documents: результат в памяти, ошибки тихие', () async {
      DateTime? notified;
      final service = QuizService(
        documentsDirectory: () async => throw Exception('нет path_provider'),
        onQuizFinished: (next) => notified = next,
      );
      await service.recordResult(total: 5, correct: 5, wrongIds: const <int>[]);
      // Не бросает; состояние живо для UI, напоминание всё равно ставится.
      expect(service.lastResult.value!.correct, 5);
      expect(notified, isNotNull);
      service.dispose();
    });
  });
}
