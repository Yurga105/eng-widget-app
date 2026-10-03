import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eng_widget_app/l10n/generated/app_localizations.dart';
import 'package:eng_widget_app/models/word_entry.dart';
import 'package:eng_widget_app/services/favorite_service.dart';
import 'package:eng_widget_app/services/pronunciation_service.dart';
import 'package:eng_widget_app/services/user_example_service.dart';
import 'package:eng_widget_app/services/word_image_service.dart';
import 'package:eng_widget_app/ui/screens/word_detail_screen.dart';

/// Запись словаря для карточки избранного (формат words_db.json, §4).
const WordEntry _entry = WordEntry(
  id: 7,
  word: 'no-brainer',
  transcription: '/ˌnoʊˈbreɪnər/',
  translation: 'очевидное решение',
  example: "It's a no-brainer.",
  exampleRu: 'Это очевидное решение.',
  type: WordType.idiom,
);

/// Тесты секции «Свой пример» на карточке избранного слова — этап 16
/// (идея B-003): паттерн favorites_screen_test (временный documents).
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('user_example_section_test');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  UserExampleService buildExamples() =>
      UserExampleService(documentsDirectory: () async => tmp);

  FavoriteService buildFavorites() =>
      FavoriteService(documentsDirectory: () async => tmp);

  File storageFile() => File(
    '${tmp.path}${Platform.pathSeparator}${UserExampleService.fileName}',
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    required UserExampleService examples,
    required FavoriteService favorites,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4CAF50)),
        ),
        home: WordDetailScreen(
          entry: _entry,
          added: DateTime(2026, 10, 3),
          favorites: favorites,
          pronunciation: PronunciationService(),
          wordImages: WordImageService(documentsDirectory: () async => tmp),
          userExamples: examples,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Нет примера — заголовок секции и кнопка добавления (этап 16)', (
    tester,
  ) async {
    final examples = buildExamples();
    final favorites = buildFavorites();
    await examples.load();
    await pumpScreen(tester, examples: examples, favorites: favorites);

    expect(find.text('Your example'), findsOneWidget);
    expect(find.text('Add your own example'), findsOneWidget);
    // Слово видно дважды: заголовок детали и карточка.
    expect(find.text('no-brainer'), findsNWidgets(2));
    examples.dispose();
    favorites.dispose();
  });

  testWidgets('Ввод и сохранение: текст показан, файл создан', (tester) async {
    final examples = buildExamples();
    final favorites = buildFavorites();
    await pumpScreen(tester, examples: examples, favorites: favorites);

    await tester.tap(find.text('Add your own example'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Saw it on a menu in Bali');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Saw it on a menu in Bali'), findsOneWidget);
    expect(examples.textFor(7), 'Saw it on a menu in Bali');
    expect(
      storageFile().existsSync(),
      isTrue,
      reason: 'user_examples.json записан',
    );
    expect(
      storageFile().readAsStringSync(),
      contains('Saw it on a menu in Bali'),
    );
    examples.dispose();
    favorites.dispose();
  });

  testWidgets('Отмена: черновик не сохраняется, файла нет', (tester) async {
    final examples = buildExamples();
    final favorites = buildFavorites();
    await pumpScreen(tester, examples: examples, favorites: favorites);

    await tester.tap(find.text('Add your own example'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'draft');
    await tester.tap(find.text('Cancel'));
    await tester.pump();

    expect(find.text('Add your own example'), findsOneWidget);
    expect(examples.textFor(7), isNull);
    expect(
      storageFile().existsSync(),
      isFalse,
      reason: 'отмена не порождает файл',
    );
    examples.dispose();
    favorites.dispose();
  });

  testWidgets(
    'Редактирование: открывается со старым текстом, сохраняет новый',
    (tester) async {
      final examples = buildExamples();
      await examples.save(7, 'first version');
      final favorites = buildFavorites();
      await pumpScreen(tester, examples: examples, favorites: favorites);

      expect(find.text('first version'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pump();
      expect(
        find.widgetWithText(TextField, 'first version'),
        findsOneWidget,
        reason: 'редактор открыт со старым текстом',
      );

      await tester.enterText(find.byType(TextField), 'second version');
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(find.text('second version'), findsOneWidget);
      expect(examples.textFor(7), 'second version');
      examples.dispose();
      favorites.dispose();
    },
  );

  testWidgets('Удаление: секция возвращается к кнопке добавления', (
    tester,
  ) async {
    final examples = buildExamples();
    await examples.save(7, 'to be deleted');
    final favorites = buildFavorites();
    await pumpScreen(tester, examples: examples, favorites: favorites);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pump();

    expect(find.text('to be deleted'), findsNothing);
    expect(find.text('Add your own example'), findsOneWidget);
    expect(examples.textFor(7), isNull);
    expect(storageFile().readAsStringSync(), isNot(contains('"id": 7')));
    examples.dispose();
    favorites.dispose();
  });

  testWidgets('Стартовое чтение файла: сохранённый пример показан сразу', (
    tester,
  ) async {
    // Перезапуск приложения: пример в файле → секция показывает текст
    // без действий пользователя.
    storageFile().writeAsStringSync(
      jsonEncode(<String, Object>{
        'version': 1,
        'items': <Map<String, Object>>[
          <String, Object>{'id': 7, 'text': 'Heard it in a podcast'},
        ],
      }),
    );
    final examples = buildExamples();
    final favorites = buildFavorites();
    await examples.load();
    await pumpScreen(tester, examples: examples, favorites: favorites);

    expect(find.text('Heard it in a podcast'), findsOneWidget);
    expect(find.text('Add your own example'), findsNothing);
    examples.dispose();
    favorites.dispose();
  });
}
