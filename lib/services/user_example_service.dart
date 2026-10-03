import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Свои примеры употребления избранных слов — этап 16 (идея B-003 из
/// `docs/ideas/BACKLOG.md`): личная ассоциация «где я встретил это слово»
/// цепляет сильнее словарного примера.
///
/// Хранение — JSON-файл `documents/user_examples.json` по паттерну
/// `FavoriteService` (этап 13): инжектируемый каталог documents, после
/// его резолва — синхронный файловый IO (детерминирован в fake-async
/// тестах), «тихие» ошибки — чтение/запись не должны ронять карточку.
/// Ключ — id записи словаря, а не членство в избранном: пример переживает
/// удаление слова из избранного и его повторное добавление (как
/// фото-ассоциации этапа 12). Схему `favorites.json` (этап 13) не трогаем.
///
/// Состояние — публичная [examples] (`ValueNotifier`, карта «id → текст»):
/// экран карточки избранного слушает её `ValueListenableBuilder`-ом и
/// перерисовывается сразу после сохранения/удаления.
class UserExampleService {
  UserExampleService({Future<Directory> Function()? documentsDirectory})
    : _documentsDirectory =
          documentsDirectory ?? getApplicationDocumentsDirectory {
    // Читаем файл сразу при создании: нотифаер заполнится и экран
    // перестроится, когда данные готовы.
    unawaited(load());
  }

  /// Имя файла хранения в каталоге documents.
  static const String fileName = 'user_examples.json';

  /// Максимальная длина примера: личная ассоциация — это пара фраз,
  /// не сочинение; лимит заодно страхует файл от разрастания.
  static const int maxLength = 300;

  final Future<Directory> Function() _documentsDirectory;

  /// Свой пример по id записи словаря; пустая карта — примеров нет.
  final ValueNotifier<Map<int, String>> examples =
      ValueNotifier<Map<int, String>>(const <int, String>{});

  /// Стартовое чтение: выполняется один раз; повторные вызовы [load]
  /// ждут тот же future (детерминизм в тестах).
  Future<void>? _loading;

  /// Пример слова [wordId]; null — примера нет.
  String? textFor(int wordId) => examples.value[wordId];

  /// Сохранить/обновить пример. Текст обрезается по краям и ограничивается
  /// [maxLength]; пустой текст — то же, что [remove] (пустых записей в
  /// файле не бывает).
  Future<void> save(int wordId, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return remove(wordId);
    }
    final bounded = trimmed.length > maxLength
        ? trimmed.substring(0, maxLength)
        : trimmed;
    return _mutate(() => <int, String>{...examples.value, wordId: bounded});
  }

  /// Удалить пример слова; нет записи — no-op.
  Future<void> remove(int wordId) =>
      _mutate(() => <int, String>{...examples.value}..remove(wordId));

  /// Прочитать сохранённые примеры (перезапуск приложения). Битый файл,
  /// ошибки плагина — тихая пустая карта (мягкая деградация, §9).
  Future<void> load() => _loading ??= _loadFromFile();

  Future<void> _loadFromFile() async {
    try {
      final file = await _fileFor();
      if (!file.existsSync()) {
        return;
      }
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('верхний уровень — не объект');
      }
      final items = decoded['items'];
      if (items is! List) {
        throw const FormatException('нет массива "items"');
      }
      final parsed = <int, String>{};
      for (final item in items) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final id = item['id'];
        if (id is! int) {
          continue;
        }
        final text = item['text'];
        if (text is! String || text.trim().isEmpty) {
          continue; // пустышки и не-строки не восстанавливаем
        }
        parsed[id] = text; // дубли id — побеждает последний
      }
      examples.value = Map.unmodifiable(parsed);
    } catch (e) {
      debugPrint('UserExamples: $fileName не прочитан ($e) — примеров нет');
      examples.value = const <int, String>{};
    }
  }

  /// Обновить нотифаер и сохранить файл. Нотифаер обновляется сразу —
  /// UI отзывчив; при сбое записи файл отстанет от экрана (мягкая
  /// деградация: после перезапуска вернёмся к последней успешной
  /// записи), ошибка логируется.
  Future<void> _mutate(Map<int, String> Function() change) async {
    await load(); // стартовое чтение завершилось до первой мутации
    final next = change();
    examples.value = Map.unmodifiable(next);
    try {
      final file = await _fileFor();
      file.writeAsStringSync(_encode(next), flush: true);
    } catch (e) {
      debugPrint('UserExamples: $fileName не записан ($e)');
    }
  }

  String _encode(Map<int, String> map) =>
      const JsonEncoder.withIndent('  ').convert(<String, Object>{
        'version': 1,
        'items': <Map<String, Object>>[
          for (final entry in map.entries)
            <String, Object>{'id': entry.key, 'text': entry.value},
        ],
      });

  Future<File> _fileFor() async {
    final dir = await _documentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  /// Освободить слушателей; вызывается из `dispose` экрана-владельца.
  void dispose() => examples.dispose();
}
