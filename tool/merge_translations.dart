// ОДНОКРАТНЫЙ скрипт миграции assets/words_db.json до формата v2
// (этап 19, идея B-005 «слово-перевод на языке интерфейса»).
//
// Источник данных — tool/v2_words.txt и tool/v2_examples.txt, по строке на
// запись в формате:  id|перевод_id|перевод_de|перевод_fr|перевод_es
// Скрипт добавляет в каждую запись словаря карты translations и
// example_translations (ключи ru,id,de,fr,es; ru копируется из v1-полей
// translation / example_ru), проверяет полноту и лимиты длины, бампит
// version до 2 и перезаписывает assets/words_db.json.
//
// Запуск из корня проекта:  dart run tool/merge_translations.dart
// Скрипт идемпотентен: повторный запуск перезаписывает карты теми же
// значениями (ru всегда берётся из актуальных v1-полей).
import 'dart:convert';
import 'dart:io';

const _langs = <String>['id', 'de', 'fr', 'es'];
const _maxTranslationLength = 60; // влезает в карточку виджета
const _maxExampleLength = 90; // уложились все 5 языков

Map<int, List<String>> _parseDataFile(String path) {
  final result = <int, List<String>>{};
  final lines = File(path).readAsLinesSync();
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    final parts = line.split('|');
    if (parts.length != 5) {
      throw StateError(
        '$path:${i + 1}: ожидалось 5 полей (id + 4 языка), получено ${parts.length}',
      );
    }
    final id = int.parse(parts[0]);
    if (result.containsKey(id)) {
      throw StateError('$path:${i + 1}: дубликат id=$id');
    }
    result[id] = parts.sublist(1);
  }
  return result;
}

void main() {
  final words = _parseDataFile('tool/v2_words.txt');
  final examples = _parseDataFile('tool/v2_examples.txt');

  final dbFile = File('assets/words_db.json');
  final db = jsonDecode(dbFile.readAsStringSync()) as Map<String, dynamic>;
  final list = (db['words'] as List).cast<Map<String, dynamic>>();

  final problems = <String>[];
  for (final w in list) {
    final id = w['id'] as int;
    final name = w['word'] as String;
    final tw = words[id];
    final te = examples[id];
    if (tw == null) {
      problems.add('v2_words.txt: нет строки для id=$id ($name)');
      continue;
    }
    if (te == null) {
      problems.add('v2_examples.txt: нет строки для id=$id ($name)');
      continue;
    }

    final t = <String, String>{'ru': w['translation'] as String};
    final et = <String, String>{'ru': w['example_ru'] as String};
    for (var i = 0; i < _langs.length; i++) {
      final tv = tw[i].trim();
      final ev = te[i].trim();
      if (tv.isEmpty) problems.add('id=$id ($name): пустой перевод ${_langs[i]}');
      if (tv.length > _maxTranslationLength) {
        problems.add(
          'id=$id ($name): перевод ${_langs[i]} длиннее '
          '$_maxTranslationLength (${tv.length}): "$tv"',
        );
      }
      if (ev.isEmpty) problems.add('id=$id ($name): пустой пример ${_langs[i]}');
      if (ev.length > _maxExampleLength) {
        problems.add(
          'id=$id ($name): пример ${_langs[i]} длиннее '
          '$_maxExampleLength (${ev.length}): "$ev"',
        );
      }
      t[_langs[i]] = tv;
      et[_langs[i]] = ev;
    }
    w['translations'] = t;
    w['example_translations'] = et;
  }

  // Лишние строки в файлах данных (id, которых нет в словаре).
  final ids = list.map((w) => w['id'] as int).toSet();
  for (final id in words.keys) {
    if (!ids.contains(id)) problems.add('v2_words.txt: лишний id=$id');
  }
  for (final id in examples.keys) {
    if (!ids.contains(id)) problems.add('v2_examples.txt: лишний id=$id');
  }

  if (problems.isNotEmpty) {
    for (final p in problems) {
      stderr.writeln(p);
    }
    stderr.writeln('Итого проблем: ${problems.length} — файл НЕ перезаписан.');
    exit(1);
  }

  db['version'] = 2;
  const encoder = JsonEncoder.withIndent('  ');
  dbFile.writeAsStringSync('${encoder.convert(db)}\n');
  stdout.writeln(
    'OK: ${list.length} записей словаря переведены на формат v2 '
    '(version=2, языки: ru + ${_langs.join(", ")})',
  );
}
