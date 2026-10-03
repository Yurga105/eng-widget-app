import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:eng_widget_app/services/user_example_service.dart';

/// Тесты UserExampleService (этап 16): каталог documents подменяется
/// временным — паттерн favorite_service_test (этап 13).
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('user_example_service_test');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  UserExampleService buildService() =>
      UserExampleService(documentsDirectory: () async => tmp);

  File storageFile() => File(
    '${tmp.path}${Platform.pathSeparator}${UserExampleService.fileName}',
  );

  test('load: файла нет → пустая карта, файл не создаётся', () async {
    final service = buildService();
    await service.load();

    expect(service.examples.value, isEmpty);
    expect(service.textFor(7), isNull);
    expect(
      storageFile().existsSync(),
      isFalse,
      reason: 'пустая карта не порождает файл',
    );
    service.dispose();
  });

  test('save: пример сохраняется по id и тримится по краям', () async {
    final service = buildService();
    await service.save(7, '  Saw it on a menu in Bali  ');

    expect(service.textFor(7), 'Saw it on a menu in Bali');
    expect(service.examples.value.length, 1);
    service.dispose();
  });

  test('save пустой строки — то же, что remove: пустых записей нет', () async {
    final service = buildService();
    await service.save(7, 'real example');
    await service.save(7, '   ');

    expect(service.textFor(7), isNull);
    expect(storageFile().readAsStringSync(), isNot(contains('"id": 7')));
    service.dispose();
  });

  test('save обрезает текст до maxLength', () async {
    final service = buildService();
    final long = 'a' * (UserExampleService.maxLength + 50);
    await service.save(7, long);

    expect(service.textFor(7)!.length, UserExampleService.maxLength);
    service.dispose();
  });

  test('remove: пример убирается; отсутствующий — no-op', () async {
    final service = buildService();
    await service.save(7, 'one');
    await service.save(42, 'two');

    await service.remove(7);
    expect(service.textFor(7), isNull);
    expect(service.textFor(42), 'two');

    await service.remove(99); // нет такого — не падает
    expect(service.examples.value.length, 1);
    service.dispose();
  });

  test('нотифаер оповещает слушателей (секция карточки обновится)', () async {
    final service = buildService();
    final sizes = <int>[];
    void listen() => sizes.add(service.examples.value.length);
    service.examples.addListener(listen);

    await service.save(7, 'one');
    await service.remove(7);

    // load на пустом файле значение не меняет — листенер не дёргается;
    // дальше: save → карта из одной записи, remove → пустая.
    expect(sizes, [1, 0]);
    service.examples.removeListener(listen);
    service.dispose();
  });

  test('персистентность: файл переживает новый экземпляр сервиса', () async {
    final first = buildService();
    await first.save(7, 'Saw it on a menu in Bali');
    await first.save(42, 'Heard it in a podcast');
    first.dispose();

    expect(
      storageFile().existsSync(),
      isTrue,
      reason: 'user_examples.json создан в documents',
    );

    final second = buildService();
    await second.load();

    expect(second.textFor(7), 'Saw it on a menu in Bali');
    expect(second.textFor(42), 'Heard it in a podcast');
    second.dispose();
  });

  test(
    'хранилище независимо от favorites.json (ключ — id, не избранное)',
    () async {
      // Файл избранного этапа 13 не затрагивается: свои примеры живут
      // отдельно и переживают удаление/повторное добавление слова.
      final service = buildService();
      await service.save(7, 'personal association');

      expect(storageFile().readAsStringSync(), isNot(contains('added')));
      expect(storageFile().readAsStringSync(), isNot(contains('favorites')));
      service.dispose();
    },
  );

  test('битый JSON → тихая пустая карта', () async {
    storageFile().writeAsStringSync('{ не json');
    final service = buildService();
    await service.load();

    expect(service.examples.value, isEmpty);
    service.dispose();
  });

  test(
    'мусорные элементы отфильтровываются, дубли id — побеждает последний',
    () async {
      storageFile().writeAsStringSync(
        jsonEncode(<String, Object>{
          'version': 1,
          'items': <Object>[
            <String, Object>{'id': 7, 'text': 'первый'},
            <String, Object>{'id': 'строка', 'text': 'x'}, // id не int
            'мусор', // не объект
            <String, Object>{'id': 42, 'text': '   '}, // пустой текст
            <String, Object>{'id': 3}, // без текста
            <String, Object>{'id': 7, 'text': 'второй'}, // дубль id
          ],
        }),
      );
      final service = buildService();
      await service.load();

      expect(service.examples.value, {7: 'второй'});
      service.dispose();
    },
  );

  test(
    'сбой каталога documents → тихая пустая карта, мутации не роняют',
    () async {
      final service = UserExampleService(
        documentsDirectory: () async => throw Exception('нет path_provider'),
      );
      await service.load();
      expect(service.examples.value, isEmpty);

      await service.save(7, 'текст'); // запись упадёт — молча, UI живёт
      expect(service.textFor(7), 'текст');
      await service.remove(7);
      expect(service.examples.value, isEmpty);
      service.dispose();
    },
  );
}
