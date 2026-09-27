import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// Прокачивает карточку в том же окружении, что и HomeScreen: M3-палитра
/// от индиго-семени (PLAN.md §1), скролл и внешние отступы экрана.
Future<void> _pumpCard(
  WidgetTester tester, {
  WordEntry entry = _kIdiom,
  Brightness brightness = Brightness.light,
  String? dateLabel = '27 сентября 2026',
  bool fromWidget = false,
  VoidCallback? onListen,
  bool isListening = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F51B5),
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
    expect(find.text('идиома'), findsOneWidget);
    expect(find.text('27 сентября 2026'), findsOneWidget);
    // Без тапа по виджету метки быть не должно.
    expect(find.text('из виджета'), findsNothing);
  });

  testWidgets('WordCard в тёмной теме рендерит те же данные', (tester) async {
    await _pumpCard(tester, brightness: Brightness.dark);

    // Тема следует системной (PLAN.md §8): обе темы рендерят карточку
    // без ошибок переполнения и с теми же данными.
    expect(find.text('no-brainer'), findsOneWidget);
    expect(find.text('идиома'), findsOneWidget);
  });

  testWidgets('Метка «из виджета» появляется только при открытии с виджета',
      (tester) async {
    await _pumpCard(tester, fromWidget: true);
    expect(find.text('из виджета'), findsOneWidget);

    await _pumpCard(tester, fromWidget: false);
    expect(find.text('из виджета'), findsNothing);
  });

  testWidgets('Бейджи трёх типов: русские подписи и цвета', (tester) async {
    for (final type in WordType.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: TypeBadge(type: type))),
        ),
      );

      expect(find.text(TypeBadge.labelFor(type)), findsOneWidget);

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
    // не прошла незамеченной.
    expect(TypeBadge.labelFor(WordType.word), 'слово');
    expect(TypeBadge.labelFor(WordType.idiom), 'идиома');
    expect(TypeBadge.labelFor(WordType.phrasalVerb), 'фразовый глагол');
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
    expect(find.text('фразовый глагол'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Кнопка прослушивания: тап вызывает onListen (этап 9)',
      (tester) async {
    var taps = 0;
    await _pumpCard(tester, onListen: () => taps++);

    expect(find.byTooltip('Прослушать'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.volume_up_rounded));

    expect(taps, 1);
  });

  testWidgets('TTS недоступен (onListen == null) — кнопки нет (этап 9)',
      (tester) async {
    await _pumpCard(tester);

    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
    expect(find.byTooltip('Прослушать'), findsNothing);
    expect(find.text('no-brainer'), findsOneWidget,
        reason: 'карточка работает и без произношения');
  });

  testWidgets('Во время воспроизведения кнопка показывает «стоп» (этап 9)',
      (tester) async {
    await _pumpCard(tester, onListen: () {}, isListening: true);

    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
    expect(find.byTooltip('Остановить'), findsOneWidget);

    // Речь закончилась — снова динамик.
    await _pumpCard(tester, onListen: () {}, isListening: false);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
  });
}
