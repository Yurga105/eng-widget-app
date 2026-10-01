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
}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
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
}
