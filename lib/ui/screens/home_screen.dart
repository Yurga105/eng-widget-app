import 'package:flutter/material.dart';

import '../../services/dictionary_service.dart';

/// Временный экран этапов 0–1: подтверждает, что словарь зарегистрирован
/// в pubspec и парсится. Полноценный UI слова дня — этап 6 (PLAN.md §8).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DictionaryService _dictionary = DictionaryService();
  late final Future<int> _wordCount;

  @override
  void initState() {
    super.initState();
    _wordCount = _dictionary.load().then((words) => words.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Слово дня')),
      body: Center(
        child: FutureBuilder<int>(
          future: _wordCount,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Не удалось загрузить словарь:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              );
            }
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            }
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'База слов подключена: ${snapshot.data} записей.\n\n'
                'Полноценный интерфейс появится на этапе 6 (см. PLAN.md).',
                textAlign: TextAlign.center,
              ),
            );
          },
        ),
      ),
    );
  }
}
