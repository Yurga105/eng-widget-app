import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import 'platform_widgets.dart';

/// Платформенный выбор источника фото-ассоциации (этап 12): iOS —
/// `CupertinoActionSheet` (HIG), Android — modal bottom sheet (Material).
///
/// Возвращает **true** — камера, **false** — галерея, **null** — отмена
/// (кнопка Cancel / тап мимо). Смысл bool соответствует
/// `WordImageSource` в `word_image_service.dart`.
Future<bool?> showImageSourcePicker(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  if (isAppleStyle(context)) {
    return showCupertinoModalPopup<bool>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(l10n.imageSourceTitle),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext, true),
            child: Text(l10n.imageSourceCamera),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext, false),
            child: Text(l10n.imageSourceGallery),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: Text(l10n.cancel),
        ),
      ),
    );
  }
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.imageSourceCamera),
            onTap: () => Navigator.pop(sheetContext, true),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.imageSourceGallery),
            onTap: () => Navigator.pop(sheetContext, false),
          ),
        ],
      ),
    ),
  );
}
