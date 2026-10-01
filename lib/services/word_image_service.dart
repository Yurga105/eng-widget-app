import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Откуда брать фото-ассоциацию (этап 12): выбор пользователя в пикере
/// источника — камера или галерея.
enum WordImageSource { camera, gallery }

/// Узкая обёртка над `image_picker` — только то, что нужно фото-ассоциации
/// (паттерн `HomeWidgetBackend`/`TtsBackend`: плагин скрыт за интерфейсом,
/// тесты работают с фейком).
abstract class ImagePickerBackend {
  /// Открывает системную камеру/галерею; null — пользователь отменил.
  /// Сжатие на месте: maxWidth 1600, imageQuality 85 (JPEG).
  Future<File?> pick(WordImageSource source);
}

/// Продакшн-реализация поверх плагина `image_picker`.
///
/// Android: права не нужны — галерея открывается системным Photo Picker
/// (ACTION_GET_CONTENT на старых), камера — интентом ACTION_IMAGE_CAPTURE
/// (без `CAMERA` в манифесте приложение не обязано запрашивать его в рантайме).
/// iOS: usage-описания — `NSCameraUsageDescription`/`NSPhotoLibraryUsageDescription`
/// в `Info.plist` (+ ru/id в `InfoPlist.strings`).
class PluginImagePickerBackend implements ImagePickerBackend {
  PluginImagePickerBackend({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<File?> pick(WordImageSource source) async {
    final xfile = await _picker.pickImage(
      source: source == WordImageSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    return xfile == null ? null : File(xfile.path);
  }
}

/// Фото-ассоциация к слову дня (этап 12, PLAN.md §1): картинка пользователя,
/// привязанная к записи словаря по её `id` (НЕ по дате) — ассоциация
/// переживает ежегодные повторы слова формулы §5.
///
/// Хранение: `documents/word_images/{id}.jpg` — одно фото на запись,
/// повторный выбор перезаписывает файл (замена). Временный файл кэша
/// image_picker копируется в целевой и удаляется.
///
/// Сервис «тихий»: ошибки плагина и файловой системы глотаются с
/// debugPrint (стиль `PronunciationService`): фото — необязательная
/// фича, карточка обязана работать без неё.
class WordImageService {
  WordImageService({
    ImagePickerBackend? picker,
    Future<Directory> Function()? documentsDirectory,
  })  : _picker = picker ?? PluginImagePickerBackend(),
        _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory;

  final ImagePickerBackend _picker;
  final Future<Directory> Function() _documentsDirectory;

  /// Имя подкаталога в documents — контракт хранения, менять вместе с докой.
  static const String dirName = 'word_images';

  Directory? _dirCache;

  /// Картинка записи, если файл существует; null — фото нет (или сервис
  /// хранения недоступен — тогда тоже null, мягкая деградация).
  ///
  /// Файловый IO здесь синхронный (existsSync): вызов исполняется в
  /// микрозадаче и детерминированно завершается даже в fake-async зоне
  /// widget-тестов, где реальный async-IO (`file.exists()`) повисает.
  Future<File?> imageFor(int wordId) async {
    try {
      final file = await _fileFor(wordId);
      return file.existsSync() ? file : null;
    } catch (e) {
      debugPrint('WordImage: не удалось прочитать фото слова $wordId ($e)');
      return null;
    }
  }

  /// Спрашивает фото [source] у пользователя и сохраняет как ассоциацию
  /// записи [wordId]. Возвращает путь сохранённого файла или null —
  /// пользователь отменил / сбой плагина или записи.
  Future<String?> capture(int wordId, WordImageSource source) async {
    final File picked;
    try {
      final result = await _picker.pick(source);
      if (result == null) {
        return null; // отмена пользователя — не ошибка
      }
      picked = result;
    } catch (e) {
      debugPrint('WordImage: ошибка image_picker ($e) — пропускаем');
      return null;
    }
    try {
      final target = await _fileFor(wordId, ensureDir: true);
      picked.copySync(target.path);
      // Временный файл кэша image_picker больше не нужен; неудачное
      // удаление не должно ронять сохранение.
      try {
        if (picked.existsSync()) {
          picked.deleteSync();
        }
      } catch (_) {/* кэш системы почистит сама */}
      return target.path;
    } catch (e) {
      debugPrint('WordImage: не удалось сохранить фото слова $wordId ($e)');
      return null;
    }
  }

  /// Удаляет ассоциацию записи; отсутствие файла — не ошибка.
  Future<void> remove(int wordId) async {
    try {
      final file = await _fileFor(wordId);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e) {
      debugPrint('WordImage: не удалось удалить фото слова $wordId ($e)');
    }
  }

  Future<File> _fileFor(int wordId, {bool ensureDir = false}) async {
    final dir = ensureDir ? await _ensureDir() : await _imagesDir();
    return File('${dir.path}${Platform.pathSeparator}$wordId.jpg');
  }

  /// Путь подкаталога без создания (для чтения).
  Future<Directory> _imagesDir() async {
    if (_dirCache != null) {
      return _dirCache!;
    }
    final base = await _documentsDirectory();
    return Directory('${base.path}${Platform.pathSeparator}$dirName');
  }

  /// Подкаталог с созданием (для записи) + кэш.
  Future<Directory> _ensureDir() async {
    if (_dirCache != null) {
      return _dirCache!;
    }
    final dir = await _imagesDir();
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _dirCache = dir;
    return dir;
  }
}
