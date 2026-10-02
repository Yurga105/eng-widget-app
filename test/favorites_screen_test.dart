import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eng_widget_app/l10n/generated/app_localizations.dart';
import 'package:eng_widget_app/services/dictionary_service.dart';
import 'package:eng_widget_app/services/favorite_service.dart';
import 'package:eng_widget_app/services/pronunciation_service.dart';
import 'package:eng_widget_app/services/word_image_service.dart';
import 'package:eng_widget_app/ui/screens/favorites_screen.dart';

/// Мини-словарь из двух записей (формат words_db.json, PLAN.md §4):
/// assetLoader-фейк по паттерну dictionary_service_test.
final String miniDb = jsonEncode(<String, Object>{
  'words': <Map<String, Object>>[
    <String, Object>{
      'id': 7,
      'word': 'no-brainer',
      'transcription': '/ˌnoʊˈbreɪnər/',
      'translation': 'очевидное решение',
      'example': "It's a no-brainer.",
      'example_ru': 'Это очевидное решение.',
      'type': 'idiom',
    },
    <String, Object>{
      'id': 42,
      'word': 'hang out',
      'transcription': '/hæŋ aʊt/',
      'translation': 'тусоваться',
      'example': 'We hang out a lot.',
      'example_ru': 'Мы часто тусуемся.',
      'type': 'phrasal_verb',
    },
  ],
});

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('favorites_screen_test');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  FavoriteService buildService() => FavoriteService(
        documentsDirectory: () async => tmp,
      );

  /// Качает экран избранного и ждёт, пока FutureBuilder словаря
  /// отпустит спиннер (индикатор анимируется — pumpAndSettle нельзя).
  Future<void> pumpScreen(
    WidgetTester tester, {
    required FavoriteService favorites,
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          platform: platform,
          colorScheme:
              ColorScheme.fromSeed(seedColor: const Color(0xFF4CAF50)),
        ),
        home: FavoritesScreen(
          dictionary: DictionaryService(assetLoader: (_) async => miniDb),
          favorites: favorites,
          pronunciation: PronunciationService(),
          wordImages: WordImageService(
            documentsDirectory: () async => tmp,
          ),
        ),
      ),
    );
    var attempts = 0;
    // На Android ждём Material-индикатор, на iOS — CupertinoActivityIndicator
    // (PlatformProgressIndicator ветвится по теме) — иначе iOS-тест уходит
    // на asserts раньше, чем словарь отпустит спиннер.
    while ((find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
            find.byType(CupertinoActivityIndicator).evaluate().isNotEmpty) &&
        attempts < 10) {
      await tester.pump(const Duration(milliseconds: 50));
      attempts++;
    }
  }

  testWidgets('Пустое избранное — звезда-заглушка и подсказка (этап 13)',
      (tester) async {
    final favorites = buildService();
    await favorites.load();
    await pumpScreen(tester, favorites: favorites);

    expect(find.text('Favorites'), findsOneWidget);
    expect(
      find.text('No favorite words yet — tap the star on a word card '
          'to save it'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
    favorites.dispose();
  });

  testWidgets('Список: свежие сверху, элементы со словом и переводом',
      (tester) async {
    final favorites = buildService();
    await favorites.add(7);
    await favorites.add(42); // добавлен позже — должен быть выше
    await pumpScreen(tester, favorites: favorites);

    expect(find.text('hang out'), findsOneWidget);
    expect(find.text('no-brainer'), findsOneWidget);
    expect(find.text('тусоваться'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('hang out')).dy,
      lessThan(tester.getTopLeft(find.text('no-brainer')).dy),
      reason: 'порядок «свежие сверху»',
    );
    // Тайлы переиспользуют бейдж типа.
    expect(find.text('idiom'), findsOneWidget);
    expect(find.text('phrasal verb'), findsOneWidget);
    favorites.dispose();
  });

  testWidgets('Свайп влево убирает слово из списка и файла (этап 13)',
      (tester) async {
    final favorites = buildService();
    await favorites.add(7);
    await favorites.add(42);
    await pumpScreen(tester, favorites: favorites);

    await tester.drag(find.text('hang out'), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('hang out'), findsNothing);
    expect(favorites.favorites.value.map((f) => f.id), [7]);
    final file = File('${tmp.path}${Platform.pathSeparator}'
        '${FavoriteService.fileName}');
    expect(file.existsSync(), isTrue, reason: 'файл перезаписан');
    expect(file.readAsStringSync(), contains('"id": 7'));
    expect(file.readAsStringSync(), isNot(contains('"id": 42')));
    favorites.dispose();
  });

  testWidgets('Тап по элементу — полная карточка с датой добавления',
      (tester) async {
    // Фиксированная дата добавления — из файла, чтобы подпись карточки
    // была предсказуемой («27 September 2026», локаль тестов en).
    File('${tmp.path}${Platform.pathSeparator}'
            '${FavoriteService.fileName}')
        .writeAsStringSync(jsonEncode(<String, Object>{
      'version': 1,
      'items': <Map<String, Object>>[
        <String, Object>{'id': 7, 'added': '2026-09-27T12:00:00'},
      ],
    }));
    final favorites = buildService();
    await favorites.load();
    await pumpScreen(tester, favorites: favorites);

    await tester.tap(find.text('no-brainer'));
    await tester.pumpAndSettle();

    // Слово видно дважды: заголовок детали и карточка.
    expect(find.text('no-brainer'), findsNWidgets(2));
    expect(find.text('/ˌnoʊˈbreɪnər/'), findsOneWidget);
    expect(find.text('27 September 2026'), findsOneWidget,
        reason: 'подпись карточки — дата добавления в избранное');
    expect(find.byIcon(Icons.star_rounded), findsOneWidget,
        reason: 'слово в избранном — звезда залита');

    // Снимаем звезду прямо в карточке — сервис обновился.
    await tester.tap(find.byIcon(Icons.star_rounded));
    await tester.pump();
    expect(favorites.isFavorite(7), isFalse);
    favorites.dispose();
  });

  testWidgets('iOS: пустое состояние — Cupertino-звезда (этап 13)',
      (tester) async {
    final favorites = buildService();
    await favorites.load();
    await pumpScreen(
      tester,
      favorites: favorites,
      platform: TargetPlatform.iOS,
    );

    expect(find.byIcon(CupertinoIcons.star), findsOneWidget);
    expect(find.byIcon(Icons.star_outline_rounded), findsNothing);
    favorites.dispose();
  });
}
