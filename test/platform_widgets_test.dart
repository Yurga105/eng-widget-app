import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eng_widget_app/ui/widgets/platform_widgets.dart';

/// Прогоняет scaffold с навбаром и [body] на заданной платформе темы —
/// так адаптивные ветки проверяются без реального устройства
/// (дефолт flutter_test — Android, iOS задаём явно).
Future<void> _pump(
  WidgetTester tester, {
  required TargetPlatform platform,
  String title = 'Word of Day',
  Widget? body,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      home: Scaffold(
        appBar: PlatformAppBar(title: title),
        body: body,
      ),
    ),
  );
}

void main() {
  testWidgets(
      'iOS: навбар Cupertino, индикатор и кнопка Cupertino (этап 11)',
      (tester) async {
    await _pump(
      tester,
      platform: TargetPlatform.iOS,
      body: const Column(
        children: [
          PlatformProgressIndicator(),
          PlatformIconActionButton(
            onPressed: null,
            materialIcon: Icons.volume_up_rounded,
            cupertinoIcon: CupertinoIcons.volume_up,
          ),
        ],
      ),
    );

    expect(find.text('Word of Day'), findsOneWidget);
    expect(find.byType(CupertinoNavigationBar), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(CupertinoButton), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.volume_up), findsOneWidget);
    // Material-иконка на iOS не должна дублировать Cupertino-иконку.
    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
  });

  testWidgets('Android (дефолт тестов): навбар AppBar, всё Material',
      (tester) async {
    await _pump(
      tester,
      platform: TargetPlatform.android,
      body: const Column(
        children: [
          PlatformProgressIndicator(),
          PlatformIconActionButton(
            onPressed: null,
            materialIcon: Icons.volume_up_rounded,
            cupertinoIcon: CupertinoIcons.volume_up,
          ),
        ],
      ),
    );

    expect(find.text('Word of Day'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(CupertinoNavigationBar), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    expect(find.byType(IconButton), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
  });

  testWidgets('Тап по Cupertino-кнопке срабатывает (iOS)', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      platform: TargetPlatform.iOS,
      body: Center(
        child: PlatformIconActionButton(
          onPressed: () => taps++,
          materialIcon: Icons.add,
          cupertinoIcon: CupertinoIcons.add,
        ),
      ),
    );

    await tester.tap(find.byIcon(CupertinoIcons.add));
    expect(taps, 1);
  });

  testWidgets('Тап по IconButton срабатывает (Android)', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      platform: TargetPlatform.android,
      body: Center(
        child: PlatformIconActionButton(
          onPressed: () => taps++,
          materialIcon: Icons.add,
          cupertinoIcon: CupertinoIcons.add,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add));
    expect(taps, 1);
  });

  testWidgets('platformErrorIcon: SF Symbols на iOS', (tester) async {
    await _pump(tester, platform: TargetPlatform.iOS);
    final context = tester.element(find.byType(Scaffold));
    expect(
      platformErrorIcon(context),
      CupertinoIcons.exclamationmark_triangle_fill,
    );
  });

  testWidgets('platformErrorIcon: Material на Android', (tester) async {
    await _pump(tester, platform: TargetPlatform.android);
    final context = tester.element(find.byType(Scaffold));
    expect(platformErrorIcon(context), Icons.error_outline_rounded);
  });
}
