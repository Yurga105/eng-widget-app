import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../ui/widgets/share_poster.dart';

/// Узкая обёртка над `share_plus` — только то, что нужно шерингу карточки
/// (этап 15, идея B-001): отдать готовый PNG в системный share sheet.
///
/// Паттерн `TtsBackend` (этап 9) / `ImagePickerBackend` (этап 12):
/// продакшн-плагин скрыт за интерфейсом, сервис тестируется на фейке,
/// UI про пакет не знает.
abstract class ShareBackend {
  /// Открыть системный share sheet с файлом [path]; [text] — необязательное
  /// текстовое сопровождение (мессенджеры прикрепляют его к картинке).
  Future<void> shareFile(String path, {String? text});
}

/// Продакшн-реализация поверх `share_plus` (решение владельца 03.10.2026):
/// ACTION_SEND на Android и UIActivityViewController на iOS; FileProvider
/// плагин мержит в манифест сам, прав приложению не добавляет
/// (PLAN.md §10 — проверяется `aapt dump permissions`).
class SharePlusBackend implements ShareBackend {
  const SharePlusBackend();

  @override
  Future<void> shareFile(String path, {String? text}) async {
    await SharePlus.instance.share(
      ShareParams(files: <XFile>[XFile(path)], text: text),
    );
  }
}

/// Шеринг карточки слова картинкой — этап 15 (идея B-001, PLAN.md §8).
///
/// Проводка: `WordCard.onShare` → [sharePoster] — постер ([SharePoster])
/// рисуется один кадр через корневой оверлей ЗА правым краем экрана
/// (в дереве — значит есть слой для растеризации; невидим пользователю),
/// `RepaintBoundary.toImage` (pixelRatio 3) даёт PNG 1080×1350, байты
/// пишутся в temp ([fileName], перезапись) и уходят в системный share
/// sheet через [ShareBackend].
///
/// Сервис «тихий» (стиль `PronunciationService`, этап 9): ошибка рендера
/// или плагина логируется и глотается — карточка обязана работать.
/// Состояния не держит, поэтому экраны создают его полем без dispose.
class CardShareService {
  CardShareService({
    ShareBackend? backend,
    Future<Directory> Function()? temporaryDirectory,
    @visibleForTesting
    Future<Uint8List?> Function(BuildContext context, WidgetBuilder poster)?
        renderer,
  })  : _backend = backend ?? const SharePlusBackend(),
        _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
        _renderPng = renderer ?? renderPosterPng;

  final ShareBackend _backend;
  final Future<Directory> Function() _temporaryDirectory;

  /// Растеризация постера — точка подмены в тестах: движковое `toImage` —
  /// реальный async, который нельзя ждать в fake-async зоне widget-тестов.
  final Future<Uint8List?> Function(BuildContext, WidgetBuilder) _renderPng;

  /// Имя PNG во временном каталоге — контракт, менять вместе с докой.
  static const String fileName = 'wordofday_card.png';

  /// Плотность растеризации: логический постер 360×450 → PNG 1080×1350.
  static const double pixelRatio = 3;

  /// Отрисовать [poster] в PNG и отдать в системный share sheet;
  /// [text] — текстовое сопровождение картинки (слово — перевод).
  Future<void> sharePoster({
    required BuildContext context,
    required WidgetBuilder poster,
    String? text,
  }) =>
      _quietly('sharePoster', () async {
        final bytes = await _renderPng(context, poster);
        if (bytes == null) {
          return;
        }
        await sharePngBytes(bytes, text: text);
      });

  /// PNG-байты → файл в temp → share sheet. Публичный (@visibleForTesting)
  /// — файловая часть проверяется без живого пайплайна растеризации.
  @visibleForTesting
  Future<void> sharePngBytes(Uint8List bytes, {String? text}) async {
    final dir = await _temporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    // Запись синхронная: детерминированное завершение в fake-async зоне
    // widget-тестов, где реальный async-IO повисает (паттерн этапа 12).
    file.writeAsBytesSync(bytes, flush: true);
    await _backend.shareFile(file.path, text: text);
  }

  /// Растеризует [poster] в PNG-байты; null — слой не построился (тихо).
  ///
  /// Публичный статический метод: тестируется отдельно от файловой части
  /// (движковое `toImage` — реальный async, в fake-async зоне widget-тестов
  /// его оборачивают в `tester.runAsync`, см. `card_share_service_test`).
  static Future<Uint8List?> renderPosterPng(
    BuildContext context,
    WidgetBuilder poster,
  ) async {
    final boundaryKey = GlobalKey();
    final overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        // За правым краем экрана (+8 dp запаса): виджет в дереве и
        // рисуется — иначе toImage не найдёт слоя, но пользователь
        // вспышки постера не видит.
        right: -SharePoster.logicalSize.width - 8,
        top: 0,
        width: SharePoster.logicalSize.width,
        height: SharePoster.logicalSize.height,
        child: RepaintBoundary(
          key: boundaryKey,
          child: Builder(builder: poster),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(overlayEntry);
    try {
      // Даём кадру построиться и покраситься; если к концу кадра слой
      // всё ещё «грязный» (редко, например при загрузке шрифта) —
      // ждём ещё один.
      await SchedulerBinding.instance.endOfFrame;
      var boundary = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        return null;
      }
      if (boundary.debugNeedsPaint) {
        await SchedulerBinding.instance.endOfFrame;
        boundary = boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary == null || boundary.debugNeedsPaint) {
          return null;
        }
      }
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data?.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      overlayEntry.remove();
    }
  }

  /// Шеринг не должен ронять карточку: ошибки глотаем с логом.
  Future<void> _quietly(String what, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('CardShare: $what не удался: $e');
    }
  }
}
