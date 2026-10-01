import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:eng_widget_app/services/word_image_service.dart';

/// Фейк image_picker: сценарий задаётся хендлером, все запросы помнятся.
class FakeImagePicker implements ImagePickerBackend {
  FakeImagePicker(this.handler);

  final Future<File?> Function(WordImageSource source) handler;
  final List<WordImageSource> asked = <WordImageSource>[];

  @override
  Future<File?> pick(WordImageSource source) {
    asked.add(source);
    return handler(source);
  }
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('word_image_service_test');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  WordImageService buildService(FakeImagePicker picker) => WordImageService(
        picker: picker,
        documentsDirectory: () async => tmp,
      );

  /// «Снимок» — временный файл, как его отдаёт image_picker из своего кэша.
  File makeShot(String content) =>
      File('${tmp.path}${Platform.pathSeparator}cache_shot.jpg')
        ..writeAsStringSync(content);

  test('capture(camera): копия в word_images/{id}.jpg, кэш удалён', () async {
    final shot = makeShot('photo-1');
    final picker = FakeImagePicker((_) async => shot);
    final service = buildService(picker);

    final path = await service.capture(7, WordImageSource.camera);

    expect(path, isNotNull);
    expect(picker.asked, [WordImageSource.camera]);
    expect(path, contains(WordImageService.dirName));
    final saved = File(path!);
    expect(await saved.exists(), isTrue,
        reason: 'файл сохранён в documents/word_images');
    expect(await saved.readAsString(), 'photo-1');
    expect(await shot.exists(), isFalse,
        reason: 'временный файл кэша image_picker удаляется');
  });

  test('capture(gallery): источник передаётся плагину как есть', () async {
    final picker = FakeImagePicker((_) async => null);
    final service = buildService(picker);

    await service.capture(42, WordImageSource.gallery);

    expect(picker.asked, [WordImageSource.gallery]);
  });

  test('отмена пользователя (null от плагина) → null, файлов нет', () async {
    final service = buildService(FakeImagePicker((_) async => null));

    expect(await service.capture(7, WordImageSource.camera), isNull);
    expect(await Directory('${tmp.path}${Platform.pathSeparator}'
            '${WordImageService.dirName}')
        .exists(), isFalse,
        reason: 'без снимка подкаталог не создаётся');
  });

  test('сбой плагина → тихий null (карточка не падает)', () async {
    final service = buildService(
      FakeImagePicker((_) async => throw Exception('no camera')),
    );

    expect(await service.capture(7, WordImageSource.camera), isNull);
  });

  test('imageFor: null без файла; путь сохранённого — после capture',
      () async {
    final service =
        buildService(FakeImagePicker((_) async => makeShot('p')));

    expect(await service.imageFor(7), isNull);

    final path = await service.capture(7, WordImageSource.camera);
    final found = await service.imageFor(7);

    expect(found, isNotNull);
    expect(found!.path, path);
  });

  test('remove удаляет файл; повторный remove и imageFor → null', () async {
    final service =
        buildService(FakeImagePicker((_) async => makeShot('p')));
    await service.capture(7, WordImageSource.camera);

    await service.remove(7);

    expect(await service.imageFor(7), isNull);
    // Не ошибка, если файла уже нет.
    await service.remove(7);
  });

  test('замена фото: тот же путь (id), содержимое новое', () async {
    int n = 0;
    final service = buildService(
      FakeImagePicker((_) async => makeShot('v${n++}')),
    );

    final first = await service.capture(7, WordImageSource.camera);
    final second = await service.capture(7, WordImageSource.gallery);

    expect(second, first, reason: 'одно фото на запись — перезапись');
    expect(await File(second!).readAsString(), 'v1');
  });

  test('ключ — id записи, не дата: разные записи — разные файлы', () async {
    final service = buildService(
      FakeImagePicker((_) async => makeShot('same-shot')),
    );

    final forWord = await service.capture(7, WordImageSource.camera);
    final forOtherWord = await service.capture(8, WordImageSource.camera);

    expect(forWord, isNot(forOtherWord));
    expect(forWord, contains('7'));
    expect(forOtherWord, contains('8'));
  });

  test('хранилище недоступно → imageFor тихо null (мягкая деградация)',
      () async {
    final service = WordImageService(
      picker: FakeImagePicker((_) async => null),
      documentsDirectory: () async => throw Exception('no path_provider'),
    );

    expect(await service.imageFor(7), isNull);
  });
}
