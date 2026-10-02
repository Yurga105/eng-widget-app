import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Адаптивные строительные блоки UI — этап 11 (PLAN.md §2 «iOS»):
/// приложение выглядит нативно на обеих платформах без дублирования
/// экранов. Полная пара Material/Cupertino не нужна — экраны текстовые,
/// расходятся только эти четыре элемента.
///
/// Ветвление — по [ThemeData.platform] конкретного виджета (не
/// `dart:io`), поэтому iOS-варианты покрываются тестами через
/// `ThemeData(platform: TargetPlatform.iOS)`.
///
/// Состав:
///  * [PlatformAppBar] — навбар: CupertinoNavigationBar / AppBar;
///  * [PlatformProgressIndicator] — индикатор загрузки;
///  * [PlatformIconActionButton] — иконка-кнопка (динамик, камера…);
///  * [platformErrorIcon] — глиф экрана ошибки загрузки словаря.

/// true, если виджету положен стиль Apple (iOS).
bool isAppleStyle(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.iOS;

/// Заголовок экрана: iOS — [CupertinoNavigationBar], иначе [AppBar].
///
/// [trailing] — действие справа (этап 13: вход в «Избранное»);
/// null — навбар без действия.
class PlatformAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PlatformAppBar({super.key, required this.title, this.trailing});

  final String title;

  /// Действие в правой части навбара (одна иконка-кнопка).
  final Widget? trailing;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    if (!isAppleStyle(context)) {
      return AppBar(
        title: Text(title),
        actions: trailing == null ? null : <Widget>[trailing!],
      );
    }
    // Непрозрачная светлая плашка под цвет поверхности приложения
    // (контент не скроллится под навбар, размытие не нужно).
    return CupertinoNavigationBar(
      middle: Text(title),
      trailing: trailing,
      backgroundColor: Theme.of(context).colorScheme.surface,
    );
  }
}

/// Индикатор загрузки: iOS — [CupertinoActivityIndicator], иначе —
/// Material [CircularProgressIndicator].
class PlatformProgressIndicator extends StatelessWidget {
  const PlatformProgressIndicator({super.key});

  @override
  Widget build(BuildContext context) => isAppleStyle(context)
      ? const CupertinoActivityIndicator(radius: 14)
      : const CircularProgressIndicator();
}

/// Иконка-кнопка: iOS — [CupertinoButton] (зона тача 44 по HIG),
/// Android — [IconButton] (подсказка tooltip по долгому тапу; на iOS
/// тултипов нет — подпись не нужна, назначение иконки очевидно).
class PlatformIconActionButton extends StatelessWidget {
  const PlatformIconActionButton({
    super.key,
    required this.onPressed,
    required this.materialIcon,
    required this.cupertinoIcon,
    this.tooltip,
    this.color,
  });

  final VoidCallback? onPressed;

  /// Иконка Material-ветки (например, `Icons.volume_up_rounded`).
  final IconData materialIcon;

  /// Иконка iOS-ветки — SF Symbols (`CupertinoIcons.volume_up`).
  final IconData cupertinoIcon;

  /// Подсказка долгого тапа; применяется только на Android.
  final String? tooltip;

  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (!isAppleStyle(context)) {
      return IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        color: color,
        icon: Icon(materialIcon),
      );
    }
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      onPressed: onPressed,
      child: Icon(cupertinoIcon, color: color, size: 26),
    );
  }
}

/// Глиф ошибки (экран сбоя загрузки словаря): iOS — SF Symbols,
/// Android — Material.
IconData platformErrorIcon(BuildContext context) => isAppleStyle(context)
    ? CupertinoIcons.exclamationmark_triangle_fill
    : Icons.error_outline_rounded;
