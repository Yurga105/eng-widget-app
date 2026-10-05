import 'package:eng_widget_app/l10n/generated/app_localizations.dart';
import 'package:eng_widget_app/ui/screens/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Геометрия сплэша этапа 17 — отклик на жалобу приёмки «блок сместился
/// влево». Вместо оценки на глаз проверяем прямоугольники элементов через
/// движок вёрстки Flutter: глиф, бренд, теглайн и логотип студии обязаны
/// сидеть на горизонтальном центре экрана — и при обычном шрифте, и при
/// крупном системном масштабе, когда теглайн переносится на две строки.
void main() {
  Widget host() => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: WelcomeScreen(onFinished: () {}),
      );

  /// Экран среднего Android: 1080x2400 физических при dpr 3 —
  /// 360x800 логических, как у Realme RMX2001.
  void phoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  final Matcher centered = closeTo(180, 0.5);

  testWidgets(
    'Геометрия: глиф, бренд, теглайн и логотип — по горизонтальному центру',
    (tester) async {
      phoneSurface(tester);
      await tester.pumpWidget(host());
      // доигрываем анимацию появления (1,5 с одним контроллером)
      await tester.pumpAndSettle();

      final glyph = tester.getRect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).borderRadius ==
                  BorderRadius.circular(28),
        ),
      );
      final brand = tester.getRect(find.text('Word of Day'));
      final tagline = tester.getRect(
        find.text('A new English word every day'),
      );
      final logo = tester.getRect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).shape == BoxShape.circle,
        ),
      );

      // Дамп убран: после правки (SizedBox width: infinity) достаточно
      // ассертов — при регрессии снова включается распечатка прямоугольников.

      expect(glyph.center.dx, centered, reason: 'глиф «W.»');
      expect(brand.center.dx, centered, reason: 'бренд Word of Day');
      expect(tagline.center.dx, centered, reason: 'теглайн');
      expect(logo.center.dx, centered, reason: 'логотип студии');

      // Страховка ширины теглайна не потерялась.
      expect(tagline.width, lessThanOrEqualTo(320));
    },
  );

  testWidgets(
    'Геометрия при крупном системном шрифте (1.3): перенос теглайна держит центр',
    (tester) async {
      phoneSurface(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final brand = tester.getRect(find.text('Word of Day'));
      final tagline = tester.getRect(
        find.text('A new English word every day'),
      );
      final logo = tester.getRect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).shape == BoxShape.circle,
        ),
      );

      expect(brand.center.dx, centered, reason: 'бренд при fontScale 1.3');
      expect(tagline.center.dx, centered, reason: 'теглайн при fontScale 1.3');
      expect(logo.center.dx, centered, reason: 'логотип при fontScale 1.3');
    },
  );
}
