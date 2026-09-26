import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/word_entry.dart';

/// Загружает и кэширует локальный словарь `assets/words_db.json` (PLAN.md §3).
///
/// Ассет читается через [rootBundle], который декодирует данные как UTF-8
/// (защита от «кракозябр», риск №11 в PLAN.md §9).
class DictionaryService {
  DictionaryService({Future<String> Function(String path)? assetLoader})
      : _assetLoader = assetLoader ?? rootBundle.loadString;

  /// Путь к ассету со словарём.
  static const String assetPath = 'assets/words_db.json';

  final Future<String> Function(String path) _assetLoader;
  final List<WordEntry> _words = <WordEntry>[];
  bool _loaded = false;

  /// Неизменяемый список записей (пуст до первого вызова [load]).
  List<WordEntry> get words => List.unmodifiable(_words);

  /// Возвращает все записи словаря: при первом вызове читает и парсит
  /// ассет, дальше отдаёт результат из кэша.
  Future<List<WordEntry>> load() async {
    if (_loaded) return words;

    final String raw;
    try {
      raw = await _assetLoader(assetPath);
    } on Exception catch (e) {
      throw StateError('Не удалось прочитать $assetPath: $e');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw FormatException('$assetPath: некорректный JSON — ${e.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        '$assetPath: ожидается JSON-объект верхнего уровня',
      );
    }
    final Object? wordsJson = decoded['words'];
    if (wordsJson is! List) {
      throw FormatException('$assetPath: отсутствует массив "words"');
    }

    _words
      ..clear()
      ..addAll(
        wordsJson.map(
          (entry) => WordEntry.fromJson(entry as Map<String, dynamic>),
        ),
      );
    _loaded = true;
    return words;
  }
}
