import 'package:flutter/material.dart';

import 'ui/screens/home_screen.dart';

void main() {
  runApp(const WordOfTheDayApp());
}

/// Корневой виджет приложения «Слово дня».
///
/// Темы Material 3 со seed-цветом «индиго» (PLAN.md §1), светлая и тёмная
/// следуют за системной настройкой.
class WordOfTheDayApp extends StatelessWidget {
  const WordOfTheDayApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF3F51B5); // индиго
    return MaterialApp(
      title: 'Слово дня',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
