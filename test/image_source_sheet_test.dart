import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eng_widget_app/l10n/generated/app_localizations.dart';
import 'package:eng_widget_app/ui/widgets/image_source_sheet.dart';

/// Качает экран с кнопкой, открывающей пикер источника; результат
/// уходит в [onResult] (строка-сентинел 'unset' — ещё не отвечено).
Future<void> _pumpHost(
  WidgetTester tester,
  TargetPlatform platform,
  void Function(Object? value) onResult,
) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(platform: platform),
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                onResult(await showImageSourcePicker(context));
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Android: bottom sheet — камера true, галерея false, тап мимо null',
      (tester) async {
    Object? result = 'unset';
    await _pumpHost(tester, TargetPlatform.android, (value) => result = value);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);

    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();
    expect(result, true, reason: 'камера');

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    expect(result, false, reason: 'галерея');

    // Тап по барьеру вне шита — отмена.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(result, isNull, reason: 'отмена тапом мимо');
  });

  testWidgets('iOS: CupertinoActionSheet — камера/галерея/отмена',
      (tester) async {
    Object? result = 'unset';
    await _pumpHost(tester, TargetPlatform.iOS, (value) => result = value);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Photo source'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();
    expect(result, true);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    expect(result, false);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull, reason: 'кнопка Cancel');
  });
}
