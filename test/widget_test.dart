import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eng_widget_app/main.dart';

void main() {
  testWidgets('Приложение запускается и показывает экран-заглушку',
      (tester) async {
    await tester.pumpWidget(const WordOfTheDayApp());

    // Ассет читается реальным асинхронным I/O, поэтому «оживляем» время
    // порциями через runAsync и ждём данные FutureBuilder'а. pumpAndSettle
    // здесь не годится: индикатор загрузки анимируется бесконечно.
    final loaded = find.textContaining('База слов подключена');
    var attempts = 0;
    while (loaded.evaluate().isEmpty && attempts < 50) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      attempts++;
    }

    expect(find.text('Слово дня'), findsOneWidget);
    expect(loaded, findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
