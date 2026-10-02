import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';

import 'package:eng_widget_app/l10n/generated/app_localizations.dart';
import 'package:eng_widget_app/models/word_entry.dart';
import 'package:eng_widget_app/services/card_share_service.dart';
import 'package:eng_widget_app/ui/widgets/share_poster.dart';

/// Слово дня из плейсхолдера виджета (запись №1 базы) — этап 15.
const WordEntry _kWord = WordEntry(
  id: 1,
  word: 'accomplish',
  transcription: '/əˈkɑːmplɪʃ/',
  translation: 'выполнять, достигать',
  example: 'You can accomplish anything if you keep practising.',
  exampleRu: 'Можно достичь чего угодно, если продолжать практиковаться.',
  type: WordType.word,
);

/// Длинный «фразовый глагол» — FittedBox обязан ужать его на постере.
const WordEntry _kPhrasalVerb = WordEntry(
  id: 8,
  word: 'hang out with somebody',
  transcription: '/hæŋ ˈaʊt/',
  translation: 'проводить время вместе, тусоваться',
  example: 'We usually hang out at the weekend and play board games.',
  exampleRu: 'Мы обычно тусуемся на выходных и играем в настолки.',
  type: WordType.phrasalVerb,
);

/// Фейк бэкенда: фиксирует вызовы, ничего платформенного не трогает.
class _FakeShareBackend implements ShareBackend {
  final List<(String, String?)> calls = [];

  @override
  Future<void> shareFile(String path, {String? text}) async {
    calls.add((path, text));
  }
}

/// Каталог для тестов: настоящий temp ОС. Создаётся СИНХРОННО — реальный
/// async-IO (`createTemp`) внутри testWidgets виснет (урок БЗ, этап 12).
Directory _tempDir() {
  final dir =
      Directory.systemTemp.createTempSync('card_share_test');
  addTearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });
  return dir;
}

/// Прогоняет [poster] в тестовом приложении с делегатами локализации.
Future<void> _pumpPoster(WidgetTester tester, SharePoster poster) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: poster)),
    ),
  );
}

void main() {
  test('sharePngBytes: байты пишутся в temp-файл, бэкенд получает путь '
      'и текст (этап 15)', () async {
    final dir = _tempDir();
    final backend = _FakeShareBackend();
    final service = CardShareService(
      backend: backend,
      temporaryDirectory: () async => dir,
    );
    final bytes = Uint8List.fromList(List<int>.filled(64, 0x89));

    await service.sharePngBytes(bytes, text: 'accomplish — выполнять');

    expect(backend.calls, hasLength(1));
    final (path, text) = backend.calls.single;
    expect(path, endsWith(CardShareService.fileName));
    expect(text, 'accomplish — выполнять');
    final saved = File(path);
    expect(saved.existsSync(), isTrue, reason: 'PNG должен лежать в temp');
    expect(saved.readAsBytesSync(), bytes);
  });

  testWidgets('Постер: бейдж типа, слово, транскрипция, перевод и бренд '
      '(этап 15)', (tester) async {
    await _pumpPoster(tester, const SharePoster(entry: _kWord));

    // Дефолтная локаль тестов — en: подпись бейджа «word».
    expect(find.text('word'), findsOneWidget);
    expect(find.text('accomplish'), findsOneWidget);
    expect(find.text('/əˈkɑːmplɪʃ/'), findsOneWidget);
    expect(find.text('выполнять, достигать'), findsOneWidget);
    expect(find.text('Word of Day'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Постер: длинный фразовый глагол не переполняет макет '
      '(этап 15)', (tester) async {
    await _pumpPoster(tester, const SharePoster(entry: _kPhrasalVerb));

    expect(find.text('hang out with somebody'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'FittedBox ужимает слово, maxLines — перевод');
  });

  testWidgets('Полный пайплайн сервиса: постер → PNG-файл → share-бэкенд '
      '(этап 15)', (tester) async {
    final dir = _tempDir();
    final backend = _FakeShareBackend();
    // Фейк-рендерер: движковое toImage — реальный async, в fake-async зоне
    // widget-тестов его ждать нельзя (проверяется отдельным тестом ниже),
    // поэтому растеризацию подменяем боевыми PNG-байтами.
    final png = Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]);
    var posterBuilt = false;
    final service = CardShareService(
      backend: backend,
      temporaryDirectory: () async => dir,
      renderer: (context, poster) async {
        posterBuilt = true;
        return png;
      },
    );
    var finished = false;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => service
                  .sharePoster(
                    context: context,
                    poster: (_) => const SharePoster(entry: _kWord),
                    text: 'accomplish — выполнять',
                  )
                  .whenComplete(() => finished = true),
              child: const Text('share'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('share'));
    await tester.pump();

    expect(finished, isTrue, reason: 'цепочка должна дойти до конца');
    expect(posterBuilt, isTrue, reason: 'билдер постера должен быть вызван');
    expect(backend.calls, hasLength(1));
    final (path, text) = backend.calls.single;
    expect(text, 'accomplish — выполнять');
    expect(path, endsWith(CardShareService.fileName));
    final saved = File(path);
    expect(saved.existsSync(), isTrue, reason: 'PNG должен лежать в temp');
    expect(saved.readAsBytesSync(), png);
  });

  testWidgets('Растеризация renderPosterPng: RepaintBoundary → PNG-байты '
      '(этап 15)', (tester) async {
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: const SharePoster(entry: _kWord),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    // toImage/toByteData — движковый реальный async: штатный паттерн —
    // прокачать его в `tester.runAsync` (вне fake-async зоны).
    final bytes = await tester.runAsync(() async {
      final boundary = boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(
        pixelRatio: CardShareService.pixelRatio,
      );
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data?.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    });

    // Постер 360×450 @3x — сотни КБ; в тестовом окружении картинка может
    // быть скромнее, но это настоящий PNG-заголовок и заметный объём.
    expect(bytes, isNotNull);
    expect(bytes!.lengthInBytes, greaterThan(1000));
    expect(bytes.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47]);
  });
}
