import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eng_widget_app/l10n/generated/app_localizations.dart';
import 'package:eng_widget_app/services/dictionary_service.dart';
import 'package:eng_widget_app/services/favorite_service.dart';
import 'package:eng_widget_app/services/quiz_service.dart';
import 'package:eng_widget_app/ui/screens/quiz_screen.dart';

/// Мини-словарь из 6 записей (этап 14): слова alpha…zeta с уникальными
/// переводами «перевод-N» — правильная кнопка вычислима в тестах.
final String miniDb = jsonEncode(<String, Object>{
  'words': <Map<String, Object>>[
    <String, Object>{
      'id': 1,
      'word': 'alpha',
      'transcription': '/ˈælfə/',
      'translation': 'перевод-1',
      'example': 'Alpha example.',
      'example_ru': 'Пример альфы.',
      'type': 'word',
    },
    <String, Object>{
      'id': 2,
      'word': 'beta',
      'transcription': '/ˈbeɪtə/',
      'translation': 'перевод-2',
      'example': 'Beta example.',
      'example_ru': 'Пример беты.',
      'type': 'word',
    },
    <String, Object>{
      'id': 3,
      'word': 'gamma',
      'transcription': '/ˈɡæmə/',
      'translation': 'перевод-3',
      'example': 'Gamma example.',
      'example_ru': 'Пример гаммы.',
      'type': 'word',
    },
    <String, Object>{
      'id': 4,
      'word': 'delta',
      'transcription': '/ˈdɛltə/',
      'translation': 'перевод-4',
      'example': 'Delta example.',
      'example_ru': 'Пример дельты.',
      'type': 'idiom',
    },
    <String, Object>{
      'id': 5,
      'word': 'epsilon',
      'transcription': '/ˈɛpsɪlɒn/',
      'translation': 'перевод-5',
      'example': 'Epsilon example.',
      'example_ru': 'Пример эпсилона.',
      'type': 'idiom',
    },
    <String, Object>{
      'id': 6,
      'word': 'zeta',
      'transcription': '/ˈzeɪtə/',
      'translation': 'перевод-6',
      'example': 'Zeta example.',
      'example_ru': 'Пример дзеты.',
      'type': 'phrasal_verb',
    },
  ],
});

/// Мини-словарь, на который не хватает 4 уникальных переводов.
final String tinyDb = jsonEncode(<String, Object>{
  'words': <Map<String, Object>>[
    for (var i = 1; i <= 3; i++)
      <String, Object>{
        'id': i,
        'word': 'word$i',
        'transcription': '/w/',
        'translation': 'перевод-$i',
        'example': 'Example $i.',
        'example_ru': 'Пример $i.',
        'type': 'word',
      },
  ],
});

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('quiz_screen_test');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  FavoriteService buildFavorites() =>
      FavoriteService(documentsDirectory: () async => tmp);

  QuizService buildQuiz() => QuizService(documentsDirectory: () async => tmp);

  DictionaryService buildDictionary([String? db]) =>
      DictionaryService(assetLoader: (_) async => db ?? miniDb);

  Future<void> pumpQuiz(
    WidgetTester tester, {
    required FavoriteService favorites,
    required QuizService quiz,
    DictionaryService? dictionary,
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          platform: platform,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4CAF50)),
        ),
        home: QuizScreen(
          dictionary: dictionary ?? buildDictionary(),
          favorites: favorites,
          quiz: quiz,
        ),
      ),
    );
    // Вопросы строятся после загрузки словаря — ждём ухода спиннера
    // (Material или Cupertino — PlatformProgressIndicator ветвится).
    var attempts = 0;
    while ((find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
            find.byType(CupertinoActivityIndicator).evaluate().isNotEmpty) &&
        attempts < 10) {
      await tester.pump(const Duration(milliseconds: 50));
      attempts++;
    }
  }

  /// Слово текущего вопроса: единственное из шести, видимое на экране.
  String visibleWord(WidgetTester tester) {
    const words = <String>[
      'alpha',
      'beta',
      'gamma',
      'delta',
      'epsilon',
      'zeta',
    ];
    return words.firstWhere((w) => find.text(w).evaluate().isNotEmpty);
  }

  /// Правильный ответ для видимого слова (переводы «перевод-N»).
  Finder correctOptionFor(String word) {
    final id = <String, int>{
      'alpha': 1,
      'beta': 2,
      'gamma': 3,
      'delta': 4,
      'epsilon': 5,
      'zeta': 6,
    }[word]!;
    return find.text('перевод-$id');
  }

  testWidgets(
    'Вопрос: слово, прогресс и 4 варианта (пустое избранное — добор)',
    (tester) async {
      final favorites = buildFavorites();
      await favorites.load();
      await pumpQuiz(tester, favorites: favorites, quiz: buildQuiz());

      expect(find.text('Quiz'), findsOneWidget);
      expect(find.text('Question 1 of 5'), findsOneWidget);
      expect(find.text(visibleWord(tester)), findsOneWidget);
      // 4 варианта-кнопки (FilledButton.tonal — это FilledButton).
      expect(find.byType(FilledButton), findsNWidgets(4));
      favorites.dispose();
    },
  );

  testWidgets('Верный ответ подсвечивается и ведёт к следующему вопросу', (
    tester,
  ) async {
    final favorites = buildFavorites();
    await favorites.load();
    await pumpQuiz(tester, favorites: favorites, quiz: buildQuiz());

    final word = visibleWord(tester);
    await tester.tap(correctOptionFor(word));
    await tester.pump();

    expect(
      find.byIcon(Icons.check_rounded),
      findsOneWidget,
      reason: 'верный вариант отмечен галочкой',
    );
    // Кнопки заблокированы: повторные тапы выбор не меняют.
    await tester.tap(correctOptionFor(word));
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 900));
    expect(
      find.text('Question 2 of 5'),
      findsOneWidget,
      reason: 'пауза истекла — следующий вопрос',
    );
    favorites.dispose();
  });

  testWidgets('Полный проход: результат, файл, дата следующего квиза', (
    tester,
  ) async {
    final favorites = buildFavorites();
    await favorites.load();
    final quiz = buildQuiz();
    await pumpQuiz(tester, favorites: favorites, quiz: quiz);

    for (var i = 0; i < 5; i++) {
      await tester.tap(correctOptionFor(visibleWord(tester)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
    }

    expect(find.text('Your result'), findsOneWidget);
    expect(find.text('5 of 5 correct'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    final file = File(
      '${tmp.path}${Platform.pathSeparator}${QuizService.fileName}',
    );
    expect(file.existsSync(), isTrue, reason: 'результат сохранён');
    expect(file.readAsStringSync(), contains('"correct": 5'));
    expect(quiz.nextQuizDate, isNotNull, reason: 'напоминание получит дату');
    favorites.dispose();
    quiz.dispose();
  });

  testWidgets('Ошибка — слово в «повторении», счёт 4 из 5', (tester) async {
    final favorites = buildFavorites();
    await favorites.load();
    final quiz = buildQuiz();
    await pumpQuiz(tester, favorites: favorites, quiz: quiz);

    // Первый вопрос — отвечаем неверным вариантом: собираем тексты всех
    // кнопок и берём любой, не равный правильному переводу.
    final firstWord = visibleWord(tester);
    final correctData = tester.widget<Text>(correctOptionFor(firstWord)).data;
    final optionTexts = find
        .descendant(of: find.byType(FilledButton), matching: find.byType(Text))
        .evaluate()
        .map((element) => (element.widget as Text).data);
    final wrongText = optionTexts.firstWhere((t) => t != correctData);
    await tester.tap(find.text(wrongText!));
    await tester.pump();
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 900));

    // Остальные 4 — верно.
    for (var i = 0; i < 4; i++) {
      await tester.tap(correctOptionFor(visibleWord(tester)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
    }

    expect(find.text('4 of 5 correct'), findsOneWidget);
    expect(find.text('Words to repeat'), findsOneWidget);
    expect(
      find.text(firstWord),
      findsOneWidget,
      reason: 'ошибленное слово — в списке повторения',
    );
    expect(quiz.lastResult.value!.wrongIds, isNotEmpty);
    favorites.dispose();
    quiz.dispose();
  });

  testWidgets('«Try again» — новый квиз с первого вопроса', (tester) async {
    final favorites = buildFavorites();
    await favorites.load();
    final quiz = buildQuiz();
    await pumpQuiz(tester, favorites: favorites, quiz: quiz);

    for (var i = 0; i < 5; i++) {
      await tester.tap(correctOptionFor(visibleWord(tester)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
    }

    await tester.tap(find.text('Try again'));
    await tester.pump(); // кадр со спиннером загрузки нового квиза
    var attempts = 0;
    while (find.byType(CircularProgressIndicator).evaluate().isNotEmpty &&
        attempts < 10) {
      await tester.pump(const Duration(milliseconds: 50));
      attempts++;
    }
    expect(find.text('Question 1 of 5'), findsOneWidget);
    expect(find.text('Your result'), findsNothing);
    favorites.dispose();
    quiz.dispose();
  });

  testWidgets('Крошечный словарь — пустое состояние с подсказкой', (
    tester,
  ) async {
    final favorites = buildFavorites();
    await favorites.load();
    await pumpQuiz(
      tester,
      favorites: favorites,
      quiz: buildQuiz(),
      dictionary: buildDictionary(tinyDb),
    );

    expect(
      find.textContaining('Not enough words for a quiz yet'),
      findsOneWidget,
    );
    favorites.dispose();
  });

  testWidgets('iOS: тот же вопрос — Cupertino-навбар не ломает экран', (
    tester,
  ) async {
    final favorites = buildFavorites();
    await favorites.load();
    await pumpQuiz(
      tester,
      favorites: favorites,
      quiz: buildQuiz(),
      platform: TargetPlatform.iOS,
    );

    expect(find.text('Question 1 of 5'), findsOneWidget);
    expect(find.byType(FilledButton), findsNWidgets(4));
    favorites.dispose();
  });
}
