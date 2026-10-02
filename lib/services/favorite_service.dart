import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Слово в избранном (этап 13, идея B-002): id записи словаря + дата
/// добавления. Идентификатор уникален в списке — равенство по [id].
@immutable
class Favorite {
  const Favorite({required this.id, required this.added});

  /// Идентификатор записи словаря ([WordEntry.id]) — ключ words_db.json.
  final int id;

  /// Когда слово добавили в избранное: подпись карточки в списке и
  /// основа порядка (свежие — вверху экрана).
  final DateTime added;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Favorite && other.id == id;

  @override
  int get hashCode => id;

  @override
  String toString() => 'Favorite($id, ${added.toIso8601String()})';
}

/// Избранное — коллекция слов, к которым пользователь хочет вернуться
/// (этап 13, PLAN.md §8; идея B-002 из `docs/ideas/BACKLOG.md`).
///
/// Хранение — JSON-файл `documents/favorites.json` по паттерну
/// `WordImageService` (этап 12): инжектируемый каталог documents, после
/// его резолва — синхронный файловый IO (детерминирован в fake-async
/// тестах), «тихие» ошибки — чтение/запись не должны ронять карточку
/// или список. В окружении без плагина path_provider (тесты виджетов)
/// сервис молча работает с пустым списком — как TTS и уведомления.
///
/// Состояние — публичный [favorites] (`ValueNotifier`, порядок «старые →
/// новые»): экраны слушают его `ValueListenableBuilder`-ом, поэтому
/// звёздочка в карточке и список избранного синхронны без ручных
/// перезагрузок — домашний паттерн `isSpeaking` у `PronunciationService`.
class FavoriteService {
  FavoriteService({Future<Directory> Function()? documentsDirectory})
      : _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory {
    // Читаем файл сразу при создании: нотифаер заполнится и экраны
    // перестроятся, когда данные готовы.
    unawaited(load());
  }

  /// Имя файла хранения в каталоге documents.
  static const String fileName = 'favorites.json';

  final Future<Directory> Function() _documentsDirectory;

  /// Избранные в порядке добавления (старые → новые).
  final ValueNotifier<List<Favorite>> favorites =
      ValueNotifier<List<Favorite>>(const <Favorite>[]);

  /// Стартовое чтение: выполняется один раз; повторные вызовы [load]
  /// ждут тот же future (детерминизм в тестах).
  Future<void>? _loading;

  /// Есть ли слово [wordId] в избранном (состояние звёздочки карточки).
  bool isFavorite(int wordId) => favorites.value.any((f) => f.id == wordId);

  /// Добавить слово в конец списка (экран списка показывает свежие
  /// сверху, переворачивая порядок). Повторное добавление — no-op:
  /// дублей id в файле не бывает.
  Future<void> add(int wordId) => _mutate(() {
        if (isFavorite(wordId)) {
          return favorites.value;
        }
        return <Favorite>[
          ...favorites.value,
          Favorite(id: wordId, added: DateTime.now()),
        ];
      });

  /// Убрать слово из избранного (свайп в списке, звёздочка карточки).
  Future<void> remove(int wordId) => _mutate(
      () => favorites.value.where((f) => f.id != wordId).toList());

  /// Поведение звёздочки: слова нет — добавить, есть — убрать.
  Future<void> toggle(int wordId) =>
      isFavorite(wordId) ? remove(wordId) : add(wordId);

  /// Прочитать сохранённый список (перезапуск приложения). Битый файл,
  /// ошибки плагина — тихий пустой список (мягкая деградация, §9).
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
      final parsed = <Favorite>[];
      for (final item in items) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final id = item['id'];
        if (id is! int) {
          continue;
        }
        final addedRaw = item['added'];
        final added = addedRaw is String && DateTime.tryParse(addedRaw) != null
            ? DateTime.parse(addedRaw)
            : DateTime.now(); // кривая дата — берём «сейчас», слово терять нельзя
        if (parsed.any((f) => f.id == id)) {
          continue; // дубли id в файле схлопываем
        }
        parsed.add(Favorite(id: id, added: added));
      }
      favorites.value = List.unmodifiable(parsed);
    } catch (e) {
      debugPrint('Favorites: $fileName не прочитан ($e) — список пуст');
      favorites.value = const <Favorite>[];
    }
  }

  /// Обновить нотифаер и сохранить файл. Нотифаер обновляется сразу —
  /// UI отзывчив; при сбое записи файл отстанет от экрана (мягкая
  /// деградация: после перезапуска вернёмся к последней успешной
  /// записи), ошибка логируется.
  Future<void> _mutate(List<Favorite> Function() change) async {
    await load(); // стартовое чтение завершилось до первой мутации
    final next = change();
    favorites.value = List.unmodifiable(next);
    try {
      final file = await _fileFor();
      file.writeAsStringSync(_encode(next), flush: true);
    } catch (e) {
      debugPrint('Favorites: $fileName не записан ($e)');
    }
  }

  String _encode(List<Favorite> list) =>
      const JsonEncoder.withIndent('  ').convert(<String, Object>{
        'version': 1,
        'items': <Map<String, Object>>[
          for (final f in list)
            <String, Object>{
              'id': f.id,
              'added': f.added.toIso8601String(),
            },
        ],
      });

  Future<File> _fileFor() async {
    final dir = await _documentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  /// Освободить слушателей; вызывается из `dispose` экрана-владельца.
  void dispose() => favorites.dispose();
}
