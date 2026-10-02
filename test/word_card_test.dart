import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eng_widget_app/l10n/generated/app_localizations.dart';
import 'package:eng_widget_app/models/word_entry.dart';
import 'package:eng_widget_app/ui/widgets/type_badge.dart';
import 'package:eng_widget_app/ui/widgets/word_card.dart';

/// Идиома из примера контракта PLAN.md §4.
const WordEntry _kIdiom = WordEntry(
  id: 7,
  word: 'no-brainer',
  transcription: '/ˌnoʊˈbreɪnər/',
  translation: 'очевидное решение, дело ясное',
  example: 'Skipping that meeting was a no-brainer.',
  exampleRu: 'Пропустить эту встречу было очевидным решением.',
  type: WordType.idiom,
);

/// Длинный «фразовый глагол» — проверка переносов и бейджа с длинной
/// подписью на маленьком экране.
const WordEntry _kPhrasalVerb = WordEntry(
  id: 8,
  word: 'hang out with somebody',
  transcription: '/hæŋ ˈaʊt/',
  translation: 'проводить время вместе, тусоваться',
  example: 'We usually hang out at the weekend and play board games.',
  exampleRu: 'Мы обычно тусуемся на выходных и играем в настолки.',
  type: WordType.phrasalVerb,
);

/// Минимальный валидный PNG 1×1 (RGBA) — реальный файл для `Image.file`
/// в тестах секции фото (этап 12).
const List<int> kTinyPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, //
  0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, //
  0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, //
  0x0D, 0x0A, 0x2D, 0xB4, //
  0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

/// Прокачивает карточку в том же окружении, что и HomeScreen: M3-палитра
/// от зелёного семени (редизайн), скролл, внешние отступы экрана и
/// делегаты локализации — дефолтная локаль тестов en.
Future<void> _pumpCard(
  WidgetTester tester, {
  WordEntry entry = _kIdiom,
  Brightness brightness = Brightness.light,
  String? dateLabel = '27 сентября 2026',
  bool fromWidget = false,
  VoidCallback? onListen,
  bool isListening = false,
  TargetPlatform platform = TargetPlatform.android,
  String? imagePath,
  VoidCallback? onPickImage,
  VoidCallback? onRemoveImage,
  bool isFavorite = false,
  VoidCallback? onToggleFavorite,
}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        // Этап 11: платформа темы выбирает Material/Cupertino-ветки.
        platform: platform,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          brightness: brightness,
        ),
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: WordCard(
            entry: entry,
            dateLabel: dateLabel,
            fromWidget: fromWidget,
            onListen: onListen,
            isListening: isListening,
            imagePath: imagePath,
            onPickImage: onPickImage,
            onRemoveImage: onRemoveImage,
            isFavorite: isFavorite,
            onToggleFavorite: onToggleFavorite,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('WordCard показывает все поля записи, дату и бейдж типа',
      (tester) async {
    await _pumpCard(tester);

    expect(find.text('no-brainer'), findsOneWidget);
    expect(find.text('/ˌnoʊˈbreɪnər/'), findsOneWidget);
    expect(find.text('очевидное решение, дело ясное'), findsOneWidget);
    expect(find.text('Skipping that meeting was a no-brainer.'),
        findsOneWidget);
    expect(find.text('Пропустить эту встречу было очевидным решением.'),
        findsOneWidget);
    expect(find.text('idiom'), findsOneWidget);
    expect(find.text('27 сентября 2026'), findsOneWidget);
    // Без тапа по виджету метки быть не должно.
    expect(find.text('from widget'), findsNothing);
  });

  testWidgets('WordCard в тёмной палитре рендерит те же данные', (tester) async {
    await _pumpCard(tester, brightness: Brightness.dark);

    // Карточка не зависит от схемы: любая тема рендерит её без ошибок
    // переполнения и с теми же данными (само приложение теперь всегда
    // светлое — ThemeMode.light, но виджет остаётся переиспользуемым).
    expect(find.text('no-brainer'), findsOneWidget);
    expect(find.text('idiom'), findsOneWidget);
  });

  testWidgets('Метка «from widget» появляется только при открытии с виджета',
      (tester) async {
    await _pumpCard(tester, fromWidget: true);
    expect(find.text('from widget'), findsOneWidget);

    await _pumpCard(tester, fromWidget: false);
    expect(find.text('from widget'), findsNothing);
  });

  testWidgets('Бейджи трёх типов: локализованные подписи (en) и цвета',
      (tester) async {
    for (final type in WordType.values) {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Center(child: TypeBadge(type: type))),
        ),
      );

      final context = tester.element(find.byType(TypeBadge));
      expect(find.text(TypeBadge.labelFor(context, type)), findsOneWidget);

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(TypeBadge),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, TypeBadge.backgroundFor(type));
    }

    // Контракт подписей этапа 6 (PLAN.md §8) — явно, чтобы деградация
    // не прошла незамеченной. Тестовое окружение — локаль en.
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Center(child: TypeBadge(type: WordType.word)),
        ),
      ),
    );
    final context = tester.element(find.byType(TypeBadge));
    expect(TypeBadge.labelFor(context, WordType.word), 'word');
    expect(TypeBadge.labelFor(context, WordType.idiom), 'idiom');
    expect(TypeBadge.labelFor(context, WordType.phrasalVerb), 'phrasal verb');
  });

  testWidgets('Карточка с фразовым глаголом вмещается на экране 320×480',
      (tester) async {
    // Критерий приёмки этапа 6: карточка вмещается на маленьких экранах.
    // Этап 9: прогоняем с кнопкой прослушивания — строка слова стала
    // плотнее (слово + динамик), проверяем тот же критерий.
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpCard(
      tester,
      entry: _kPhrasalVerb,
      dateLabel: '27 сентября 2026',
      fromWidget: true,
      onListen: () {},
    );

    expect(find.text('hang out with somebody'), findsOneWidget);
    expect(find.text('phrasal verb'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Кнопка прослушивания: тап вызывает onListen (этап 9)',
      (tester) async {
    var taps = 0;
    await _pumpCard(tester, onListen: () => taps++);

    expect(find.byTooltip('Listen'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.volume_up_rounded));

    expect(taps, 1);
  });

  testWidgets('TTS недоступен (onListen == null) — кнопки нет (этап 9)',
      (tester) async {
    await _pumpCard(tester);

    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
    expect(find.byTooltip('Listen'), findsNothing);
    expect(find.text('no-brainer'), findsOneWidget,
        reason: 'карточка работает и без произношения');
  });

  testWidgets('Во время воспроизведения кнопка показывает «стоп» (этап 9)',
      (tester) async {
    await _pumpCard(tester, onListen: () {}, isListening: true);

    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
    expect(find.byTooltip('Stop'), findsOneWidget);

    // Речь закончилась — снова динамик.
    await _pumpCard(tester, onListen: () {}, isListening: false);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
  });

  testWidgets('iOS: кнопка прослушивания — CupertinoButton (этап 11)',
      (tester) async {
    var taps = 0;
    await _pumpCard(
      tester,
      onListen: () => taps++,
      platform: TargetPlatform.iOS,
    );

    // На iOS кнопка — Cupertino с иконкой SF Symbols, Material-иконки нет.
    expect(find.byType(CupertinoButton), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.volume_up), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);

    await tester.tap(find.byIcon(CupertinoIcons.volume_up));
    expect(taps, 1, reason: 'тап по Cupertino-кнопке должен дойти');
  });

  testWidgets('Нет фото — кнопка «Add a photo association» (этап 12)',
      (tester) async {
    var taps = 0;
    await _pumpCard(tester, onPickImage: () => taps++);

    expect(find.text('Add a photo association'), findsOneWidget);
    expect(find.byType(Image), findsNothing,
        reason: 'без фото картинки в карточке нет');

    await tester.tap(find.text('Add a photo association'));
    expect(taps, 1);
  });

  testWidgets('Без колбэков секции фото нет вовсе (этап 12)', (tester) async {
    await _pumpCard(tester);

    expect(find.text('Add a photo association'), findsNothing);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('Есть фото — картинка + «заменить»/«убрать», тапы работают '
      '(этап 12)', (tester) async {
    // createTempSync, а не await createTemp: реальный async-IO внутри
    // fake-async зоны testWidgets никогда не резолвится (как в widget_test,
    // где файловый IO оборачивают runAsync). Синхронные вызовы — можно.
    final tmp = Directory.systemTemp.createTempSync('word_card_img');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final png = File('${tmp.path}${Platform.pathSeparator}7.jpg')
      ..writeAsBytesSync(kTinyPng);

    var replaced = 0;
    var removed = 0;
    await _pumpCard(
      tester,
      imagePath: png.path,
      onPickImage: () => replaced++,
      onRemoveImage: () => removed++,
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Add a photo association'), findsNothing);

    // Карточка с фото выше экрана — прокручиваем кнопки в вьюпорт.
    await tester.ensureVisible(find.byTooltip('Change photo'));
    await tester.tap(find.byTooltip('Change photo'));
    expect(replaced, 1);
    await tester.ensureVisible(find.byTooltip('Remove photo'));
    await tester.tap(find.byTooltip('Remove photo'));
    expect(removed, 1);
  });

  testWidgets('Битый путь фото — заглушка ошибки вместо падения (этап 12)',
      (tester) async {
    await _pumpCard(
      tester,
      imagePath: 'Z:/definitely/missing/7.jpg',
      onPickImage: () {},
    );

    // Декодирование падает асинхронно — прокручиваем кадры и ждём
    // errorBuilder; исключений быть не должно.
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget,
        reason: 'виджет-картинка остаётся с errorBuilder-заглушкой');
  });

  testWidgets('Звезда избранного: нет колбэка — нет звезды (этап 13)',
      (tester) async {
    await _pumpCard(tester, onListen: () {});

    expect(find.byIcon(Icons.star_outline_rounded), findsNothing);
    expect(find.byIcon(Icons.star_rounded), findsNothing);
  });

  testWidgets('Звезда: контур ↔ залитая янтарная, тап зовёт колбэк '
      '(этап 13)', (tester) async {
    var taps = 0;
    await _pumpCard(
      tester,
      onListen: () {},
      onToggleFavorite: () => taps++,
    );

    expect(find.byTooltip('Add to favorites'), findsOneWidget);
    expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.star_outline_rounded));
    expect(taps, 1);

    await _pumpCard(
      tester,
      onListen: () {},
      isFavorite: true,
      onToggleFavorite: () => taps++,
    );

    expect(find.byTooltip('Remove from favorites'), findsOneWidget);
    final starIcon = find.byIcon(Icons.star_rounded);
    expect(starIcon, findsOneWidget);
    // Контракт цвета — параметр color самой кнопки: M3-IconButton красит
    // глиф через свой style, а не через IconTheme контекста иконки,
    // поэтому IconTheme.of на элементе Icon янтарный не увидит.
    final button = tester.widget<IconButton>(
      find.ancestor(of: starIcon, matching: find.byType(IconButton)),
    );
    expect(button.color, const Color(0xFFFFB300),
        reason: 'залитая звезда — янтарный акцент палитры §1');

    await tester.tap(starIcon);
    expect(taps, 2);
  });

  testWidgets('iOS: звезда — CupertinoButton с SF-иконкой (этап 13)',
      (tester) async {
    var taps = 0;
    await _pumpCard(
      tester,
      onListen: () {},
      onToggleFavorite: () => taps++,
      platform: TargetPlatform.iOS,
    );

    expect(find.byIcon(CupertinoIcons.star), findsOneWidget);
    expect(find.byIcon(Icons.star_outline_rounded), findsNothing);

    await tester.tap(find.byIcon(CupertinoIcons.star));
    expect(taps, 1, reason: 'тап по Cupertino-звезде должен дойти');
  });
}
