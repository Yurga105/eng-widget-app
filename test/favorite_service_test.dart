import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:eng_widget_app/services/favorite_service.dart';

/// Тесты FavoriteService (этап 13): каталог documents подменяется
/// временным — паттерн word_image_service_test.
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('favorite_service_test');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  FavoriteService buildService() => FavoriteService(
        documentsDirectory: () async => tmp,
      );

  File storageFile() => File(
      '${tmp.path}${Platform.pathSeparator}${FavoriteService.fileName}');

  test('load: файла нет → пустой список, файл не создаётся', () async {
    final service = buildService();
    await service.load();

    expect(service.favorites.value, isEmpty);
    expect(service.isFavorite(7), isFalse);
    expect(storageFile().existsSync(), isFalse,
        reason: 'пустой список не порождает файл');
    service.dispose();
  });

  test('add: порядок добавления сохраняется, дубликаты — no-op', () async {
    final service = buildService();
    await service.add(7);
    await service.add(42);
    await service.add(7); // повторное добавление — не дубль

    expect(service.favorites.value.map((f) => f.id), [7, 42]);
    expect(service.isFavorite(7), isTrue);
    expect(service.isFavorite(99), isFalse);
    service.dispose();
  });

  test('remove/toggle: слово убирается, toggle ходит туда-обратно',
      () async {
    final service = buildService();
    await service.add(7);
    await service.add(42);

    await service.remove(7);
    expect(service.favorites.value.map((f) => f.id), [42]);

    await service.toggle(42); // было — убираем
    expect(service.favorites.value, isEmpty);
    await service.toggle(42); // не было — добавляем
    expect(service.isFavorite(42), isTrue);
    service.dispose();
  });

  test('нотифаер оповещает слушателей (звёздочка карточки обновится)',
      () async {
    final service = buildService();
    final sizes = <int>[];
    void listen() => sizes.add(service.favorites.value.length);
    service.favorites.addListener(listen);

    await service.add(7);
    await service.remove(7);

    // load на пустом файле значение не меняет — листенер не дёргается;
    // дальше: add → список из одного, remove → пустой.
    expect(sizes, [1, 0]);
    service.favorites.removeListener(listen);
    service.dispose();
  });

  test('персистентность: файл переживает новый экземпляр сервиса',
      () async {
    final first = buildService();
    await first.add(7);
    await first.add(42);
    first.dispose();

    expect(storageFile().existsSync(), isTrue,
        reason: 'favorites.json создан в documents');

    final second = buildService();
    await second.load();

    final restored = second.favorites.value;
    expect(restored.map((f) => f.id), [7, 42],
        reason: 'порядок «старые → новые» сохранён');
    expect(restored.first.added, isA<DateTime>());
    expect(restored.first.added.isBefore(restored.last.added) ||
        restored.first.added == restored.last.added, isTrue);
    second.dispose();
  });

  test('битый JSON → тихий пустой список', () async {
    storageFile().writeAsStringSync('{ не json');
    final service = buildService();
    await service.load();

    expect(service.favorites.value, isEmpty);
    service.dispose();
  });

  test('мусорные элементы и дубли id отфильтровываются', () async {
    storageFile().writeAsStringSync(jsonEncode(<String, Object>{
      'version': 1,
      'items': <Object>[
        <String, Object>{'id': 7, 'added': '2026-10-02T10:00:00'},
        <String, Object>{'id': 'строка', 'added': '2026-10-02'}, // id не int
        'мусор', // не объект
        <String, Object>{'id': 7, 'added': 'кривая дата'}, // дубль id
        <String, Object>{'id': 42}, // без даты — дата восстановления
        <String, Object>{'id': 3, 'added': '2026-10-01T09:30:00'},
      ],
    }));
    final service = buildService();
    await service.load();

    expect(service.favorites.value.map((f) => f.id), [7, 42, 3]);
    expect(service.favorites.value[1].added.year, greaterThanOrEqualTo(2026),
        reason: 'отсутствующая дата заменена текущей');
    service.dispose();
  });

  test('сбой каталога documents → тихий пустой список, мутации не роняют',
      () async {
    final service = FavoriteService(
      documentsDirectory: () async => throw Exception('нет path_provider'),
    );
    await service.load();
    expect(service.favorites.value, isEmpty);

    await service.add(7); // запись упадёт — молча, UI живёт
    expect(service.isFavorite(7), isTrue);
    await service.remove(7);
    expect(service.favorites.value, isEmpty);
    service.dispose();
  });
}
