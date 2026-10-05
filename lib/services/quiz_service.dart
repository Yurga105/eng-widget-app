import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/word_entry.dart';

/// Один вопрос квиза (этап 14, идея B-006): запись словаря + 4 варианта
/// перевода, один из которых верный.
@immutable
class QuizQuestion {
  const QuizQuestion({
    required this.entry,
    required this.options,
    required this.correctIndex,
  });

  /// Запись, перевод которой проверяем.
  final WordEntry entry;

  /// Варианты ответа (переводы); верный — [correctIndex].
  final List<String> options;

  /// Индекс верного варианта в [options].
  final int correctIndex;

  /// Текст верного варианта — подсветка ответа и экран результата.
  String get correctOption => options[correctIndex];

  /// Ответили ли верно на вариант [index].
  bool isCorrect(int index) => index == correctIndex;

  @override
  String toString() => 'QuizQuestion(${entry.word}, ${options.length} опций)';
}

/// Итог одного прохождения квиза (этап 14).
@immutable
class QuizResult {
  const QuizResult({
    required this.finishedAt,
    required this.total,
    required this.correct,
    required this.wrongIds,
  });

  /// Когда квиз завершили — основа цикла «каждые 3 дня».
  final DateTime finishedAt;

  /// Вопросов было / отвечено верно.
  final int total;
  final int correct;

  /// Id записей словаря с ошибками — «что повторить» (задел под SRS).
  final List<int> wrongIds;

  Map<String, Object> toJson() => <String, Object>{
    'finishedAt': finishedAt.toIso8601String(),
    'total': total,
    'correct': correct,
    'wrongIds': wrongIds,
  };

  factory QuizResult.fromJson(Map<String, dynamic> json) => QuizResult(
    finishedAt:
        DateTime.tryParse(json['finishedAt'] as String? ?? '') ??
        DateTime.now(), // кривая дата — не теряем результат
    total: json['total'] as int? ?? 0,
    correct: json['correct'] as int? ?? 0,
    wrongIds: <int>[
      for (final id in (json['wrongIds'] as List? ?? const <Never>[]))
        if (id is int) id,
    ],
  );
}

/// Квиз-повторение — этап 14 (PLAN.md §8; идея B-006 из
/// `docs/ideas/BACKLOG.md`): мини-квиз «слово → перевод из 4 вариантов»
/// каждые 3 дня; материал — избранное (этап 13) с добором из словаря.
///
/// Две зоны ответственности:
///  * **Цикл и результаты** — состояние экземпляра: файл
///    `documents/quiz_results.json` по паттерну `FavoriteService` (этап 13):
///    инжектируемый каталог documents, после резолва — синхронный файловый
///    IO, «тихие» ошибки (в окружении без path_provider — как будто квизов
///    не было). Публичный [lastResult] (`ValueNotifier`) слушает экран
///    квиза; [isDue]/[nextQuizDate] — расписание напоминания.
///  * **Генерация вопросов** — чистая статика [generate]: пул вопросов
///    (избранное, при нехватке — добор случайными записями словаря) и
///    варианты «1 верный + 3 дистрактора» (сначала того же типа записи).
///    Словарь экран передаёт сам — сервис не зависит от `DictionaryService`
///    и `FavoriteService`, поэтому один экземпляр живёт в `main.dart`
///    (напоминания) и передаётся в `HomeScreen`/квиз.
class QuizService {
  QuizService({
    Future<Directory> Function()? documentsDirectory,
    this.onQuizFinished,
  }) : _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory {
    // Читаем файл сразу: due-логика напоминаний доступна с первого кадра.
    unawaited(load());
  }

  /// Имя файла хранения в каталоге documents.
  static const String fileName = 'quiz_results.json';

  /// Вопросов в одном квизе (карточка B-006 — «мини-квиз»).
  static const int questionCount = 5;

  /// Вариантов ответа: 1 верный + 3 дистрактора.
  static const int optionsPerQuestion = 4;

  /// Пауза между квизами — 3 дня (суть идеи B-006).
  static const int intervalDays = 3;

  /// Сколько прохождений хранить в файле (история для будущей статистики;
  /// файл не растёт бесконечно).
  static const int maxHistory = 50;

  final Future<Directory> Function() _documentsDirectory;

  /// Колбэк «квиз завершён» — main.dart перепланирует напоминание.
  final void Function(DateTime nextQuizDate)? onQuizFinished;

  /// Последнее прохождение; null — квиз ещё не проходили.
  final ValueNotifier<QuizResult?> lastResult = ValueNotifier<QuizResult?>(
    null,
  );

  /// Стартовое чтение: один раз; повторные вызовы [load] ждут тот же
  /// future (детерминизм в тестах).
  Future<void>? _loading;

  /// Дата следующего квиза (дата без времени): последний результат
  /// + [intervalDays] дней. null — квизов ещё не было.
  DateTime? get nextQuizDate {
    final last = lastResult.value;
    if (last == null) {
      return null;
    }
    final finished = last.finishedAt;
    return DateTime(finished.year, finished.month, finished.day + intervalDays);
  }

  /// Наступило ли время следующего квиза. Без единого прохождения — true:
  /// первый квиз доступен сразу (вход по иконке), напоминание не ставится.
  bool isDue(DateTime now) {
    final next = nextQuizDate;
    if (next == null) {
      return true;
    }
    final today = DateTime(now.year, now.month, now.day);
    return !today.isBefore(next);
  }

  /// Прочитать сохранённую историю (перезапуск приложения). Битый файл и
  /// ошибки плагина — тихий «квизов не было» (мягкая деградация, §9).
  Future<void> load() => _loading ??= _loadFromFile();

  Future<void> _loadFromFile() async {
    try {
      final file = await _fileFor();
      if (!file.existsSync()) {
        return;
      }
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('верхний уровень — не объект');
      }
      final history = decoded['history'];
      if (history is! List) {
        throw const FormatException('нет массива "history"');
      }
      QuizResult? last;
      for (final item in history) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        last = QuizResult.fromJson(item);
      }
      lastResult.value = last;
    } catch (e) {
      debugPrint('Quiz: $fileName не прочитан ($e) — квизов не было');
      lastResult.value = null;
    }
  }

  /// Записать результат прохождения: обновить нотифаер (экран живой),
  /// сохранить историю в файл и оповестить [onQuizFinished] — `main.dart`
  /// по колбэку перепланирует напоминание на +3 дня.
  Future<void> recordResult({
    required int total,
    required int correct,
    required List<int> wrongIds,
    DateTime? now,
  }) async {
    await load(); // стартовое чтение завершилось до первой записи
    final result = QuizResult(
      finishedAt: now ?? DateTime.now(),
      total: total,
      correct: correct,
      wrongIds: List<int>.unmodifiable(wrongIds),
    );
    lastResult.value = result;
    try {
      final file = await _fileFor();
      file.writeAsStringSync(
        _encode(<QuizResult>[..._readHistory(file), result]),
        flush: true,
      );
    } catch (e) {
      debugPrint('Quiz: $fileName не записан ($e)');
    }
    final next = nextQuizDate; // уже от свежего результата
    if (next != null) {
      onQuizFinished?.call(next);
    }
  }

  /// Прошлая история из файла — для конкатенации при записи (файл —
  /// единственный источник: другой экран мог дописать прохождение).
  List<QuizResult> _readHistory(File file) {
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      final history = decoded is Map<String, dynamic>
          ? decoded['history']
          : null;
      if (history is! List) {
        return const <QuizResult>[];
      }
      return <QuizResult>[
        for (final item in history)
          if (item is Map<String, dynamic>) QuizResult.fromJson(item),
      ];
    } catch (_) {
      return const <QuizResult>[]; // битый файл перепишем заново
    }
  }

  String _encode(List<QuizResult> history) =>
      const JsonEncoder.withIndent('  ').convert(<String, Object>{
        'version': 1,
        'history': <Map<String, Object>>[
          for (final r
              in history.length > maxHistory
                  ? history.sublist(history.length - maxHistory)
                  : history)
            r.toJson(),
        ],
      });

  Future<File> _fileFor() async {
    final dir = await _documentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  /// Освободить слушателей; вызывается из `dispose` экрана-владельца.
  void dispose() => lastResult.dispose();

  /// Собрать вопросы квиза (чистая функция — легко тестировать).
  ///
  ///  * [questionPool] — записи для вопросов: экран подаёт избранное
  ///    (свежие первыми); при нехватке до [count] — добор случайными
  ///    записями [dictionary], которых нет в пуле (карточка B-006);
  ///  * каждый вопрос — [optionsPerQuestion] уникальных перевода: верный
  ///    и дистракторы, сначала записей того же типа («слово к слову» —
  ///    «желательно того же типа», B-006), затем любых;
  ///  * записи с переводом-дублем в дистракторы не попадают; если на
  ///    запись не набралось 3 дистракторов (крошечный словарь) — вопрос
  ///    пропускается; пустой результат = «мало слов» для экрана.
  ///
  /// [random] инжектируется тестами (детерминизм), прод — `Random()`.
  static List<QuizQuestion> generate({
    required List<WordEntry> questionPool,
    required List<WordEntry> dictionary,
    int count = questionCount,
    Random? random,

    /// Язык переводов-вариантов (этап 19, идея B-005): словарь v2 даёт
    /// id/de/fr/es; фолбэк внутри записи — русские поля v1.
    String translationLanguage = 'ru',
  }) {
    final rnd = random ?? Random();
    final pool = <WordEntry>[...questionPool];
    if (pool.length < count) {
      final extras = dictionary.where((entry) => !pool.contains(entry)).toList()
        ..shuffle(rnd);
      pool.addAll(extras.take(count - pool.length));
    }
    pool.shuffle(rnd);

    final questions = <QuizQuestion>[];
    for (final entry in pool.take(count)) {
      final question = _questionFor(entry, dictionary, rnd, translationLanguage);
      if (question != null) {
        questions.add(question);
      }
    }
    return List<QuizQuestion>.unmodifiable(questions);
  }

  /// Вопрос по записи: верный перевод + дистракторы того же типа (затем
  /// любые), уникальные; null — дистракторов не хватило.
  static QuizQuestion? _questionFor(
    WordEntry entry,
    List<WordEntry> dictionary,
    Random rnd,
    String translationLanguage,
  ) {
    final sameType =
        dictionary
            .where((e) => e.type == entry.type && e.id != entry.id)
            .toList()
          ..shuffle(rnd);
    final otherType =
        dictionary
            .where((e) => e.type != entry.type && e.id != entry.id)
            .toList()
          ..shuffle(rnd);

    final correct = entry.translationFor(translationLanguage);
    final options = <String>[correct];
    final used = <String>{correct};
    for (final candidate in <WordEntry>[...sameType, ...otherType]) {
      if (options.length >= optionsPerQuestion) {
        break;
      }
      final translation = candidate.translationFor(translationLanguage);
      if (used.contains(translation)) {
        continue;
      }
      used.add(translation);
      options.add(translation);
    }
    if (options.length < optionsPerQuestion) {
      return null; // словарь слишком мал для честных 4 вариантов
    }
    options.shuffle(rnd);
    return QuizQuestion(
      entry: entry,
      options: options,
      correctIndex: options.indexOf(correct),
    );
  }
}
