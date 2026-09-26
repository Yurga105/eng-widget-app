import 'dart:async';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import 'services/widget_sync_service.dart';
import 'ui/screens/home_screen.dart';

void main() {
  runApp(const WordOfTheDayApp());
}

/// Корневой виджет приложения «Слово дня» — этап 4: мост с виджетом.
///
/// Здесь живёт «проводка» этапа 4 (PLAN.md §8):
///  - при старте и возврате на передний план — синхронизация слова дня
///    в виджет ([WidgetSyncService.syncToday]);
///  - таймер на локальную полуночь — смена слова, пока приложение живо
///    (полностью автономная смена — этап 5);
///  - приём тапов виджета: URI `wordoftheday://word?date=…` при холодном
///    старте ([HomeWidget.initiallyLaunchedFromHomeWidget]) и в тёплом
///    режиме (стрим [HomeWidget.widgetClicked]) → [HomeScreen] показывает
///    карточку этой даты.
///
/// Темы Material 3 со seed-цветом «индиго» (PLAN.md §1), светлая и тёмная
/// следуют за системной настройкой.
class WordOfTheDayApp extends StatefulWidget {
  const WordOfTheDayApp({super.key});

  @override
  State<WordOfTheDayApp> createState() => _WordOfTheDayAppState();
}

class _WordOfTheDayAppState extends State<WordOfTheDayApp>
    with WidgetsBindingObserver {
  final WidgetSyncService _widgetSync = WidgetSyncService();

  /// Дата из последнего тапа по виджету; null — показываем сегодня.
  final ValueNotifier<DateTime?> _widgetTapDate = ValueNotifier<DateTime?>(null);

  Timer? _midnightTimer;
  StreamSubscription<Uri?>? _tapSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_syncTodayQuietly());
    _scheduleMidnightSync();
    _listenToWidgetTaps();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    _tapSubscription?.cancel();
    _widgetTapDate.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Возврат из «недавних»/с фона: время могло перевалить за полночь —
    // обновляем виджет (риск №2 в PLAN.md §9).
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncTodayQuietly());
      _scheduleMidnightSync();
    }
  }

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
      home: HomeScreen(widgetTapDate: _widgetTapDate),
    );
  }

  /// Синхронизация без падения UI: ошибки плагина (например, отсутствие
  /// платформенной реализации в тестах) логируем и глотаем.
  Future<void> _syncTodayQuietly() async {
    try {
      await _widgetSync.syncToday();
    } catch (e) {
      debugPrint('WidgetSync: не удалось синхронизировать виджет: $e');
    }
  }

  /// Перезапускает таймер на следующую локальную полночь.
  void _scheduleMidnightSync() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    // Конструктор DateTime нормализует «32 января» → 1 февраля.
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now), () {
      unawaited(_syncTodayQuietly());
      _scheduleMidnightSync();
    });
  }

  void _listenToWidgetTaps() {
    _tapSubscription = HomeWidget.widgetClicked.listen(
      _handleWidgetUri,
      onError: (Object error) =>
          debugPrint('WidgetSync: ошибка стрима тапов виджета: $error'),
    );
    HomeWidget.initiallyLaunchedFromHomeWidget()
        .then(_handleWidgetUri)
        .catchError((Object error) {
      debugPrint('WidgetSync: не удалось прочитать стартовый URI: $error');
    });
  }

  void _handleWidgetUri(Uri? uri) {
    final date = WidgetSyncService.dateFromWidgetUri(uri);
    if (date != null) {
      _widgetTapDate.value = date;
    }
  }
}

