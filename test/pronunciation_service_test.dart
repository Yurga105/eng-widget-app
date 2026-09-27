import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eng_widget_app/services/pronunciation_service.dart';

/// Записывает вызовы бэкенда; поведение задаётся полями.
///
/// `speak` не завершается сам — только по [finishSpeech], имитируя
/// `awaitSpeakCompletion(true)` реального плагина.
class FakeTtsBackend implements TtsBackend {
  bool languageAvailable = true;
  Object? initError;
  Object? speakError;

  /// Порядок вызовов по имени — проверяем «initialize до available».
  final List<String> calls = <String>[];

  VoidCallback? finishHandler;
  void Function(String message)? failHandler;
  String? lastSpoken;
  Completer<void>? _speechDone;

  @override
  Future<void> initialize({
    required VoidCallback onSpeechFinished,
    required void Function(String message) onSpeechFailed,
  }) async {
    if (initError != null) {
      throw initError!;
    }
    finishHandler = onSpeechFinished;
    failHandler = onSpeechFailed;
    calls.add('initialize');
  }

  @override
  Future<bool> isLanguageAvailable(String language) async {
    calls.add('available:$language');
    return languageAvailable;
  }

  @override
  Future<void> speak(String text) async {
    if (speakError != null) {
      throw speakError!;
    }
    calls.add('speak:$text');
    lastSpoken = text;
    _speechDone = Completer<void>();
    await _speechDone!.future;
  }

  @override
  Future<void> stop() async => calls.add('stop');

  /// «Движок договорил» — завершает зависший speak().
  void finishSpeech() => _speechDone?.complete();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PronunciationService — start/доступность', () {
    test('start: initialize, затем проверка голоса en-US; доступен',
        () async {
      final fake = FakeTtsBackend();
      final service = PronunciationService(backend: fake);

      expect(service.isAvailable, isFalse, reason: 'до start — кнопки нет');

      await service.start();

      expect(fake.calls.first, 'initialize');
      expect(fake.calls,
          contains('available:${PronunciationService.language}'));
      expect(PronunciationService.language, 'en-US',
          reason: 'транскрипции базы — американская IPA (§4)');
      expect(service.isAvailable, isTrue);
    });

    test('нет голоса en-US → isAvailable false (кнопка будет скрыта)',
        () async {
      final fake = FakeTtsBackend()..languageAvailable = false;
      final service = PronunciationService(backend: fake);

      await service.start();

      expect(service.isAvailable, isFalse);
    });

    test('сбой initialize (нет движка) — мягкая деградация: не бросает',
        () async {
      final fake = FakeTtsBackend()..initError = Exception('нет движка');
      final service = PronunciationService(backend: fake);

      await service.start(); // не должен бросить

      expect(service.isAvailable, isFalse);
      expect(fake.calls, isNot(contains(startsWith('available:'))),
          reason: 'движок не поднялся — язык не спрашиваем');
    });
  });

  group('PronunciationService — воспроизведение', () {
    test('speak: слово уходит в бэкенд; isSpeaking по концу речи сбрасывается',
        () async {
      final fake = FakeTtsBackend();
      final service = PronunciationService(backend: fake);
      await service.start();

      final speaking = service.speak('no-brainer');
      expect(service.isSpeaking.value, isTrue, reason: 'речь идёт');
      expect(fake.lastSpoken, 'no-brainer');

      fake.finishSpeech();
      await speaking;

      expect(service.isSpeaking.value, isFalse);
    });

    test('toggle во время речи → stop вместо нового speak', () async {
      final fake = FakeTtsBackend();
      final service = PronunciationService(backend: fake);
      await service.start();

      final speaking = service.speak('hang out');
      final toggled = service.toggle('hang out'); // говорит → остановить
      await toggled;

      expect(fake.calls, contains('stop'));
      expect(fake.calls.where((c) => c == 'speak:hang out').length, 1,
          reason: 'повторного speak быть не должно');

      fake.finishSpeech(); // завершаем зависший speak
      await speaking;
      expect(service.isSpeaking.value, isFalse);
    });

    test('speak при недоступном языке — no-op', () async {
      final fake = FakeTtsBackend()..languageAvailable = false;
      final service = PronunciationService(backend: fake);
      await service.start();

      await service.speak('no-brainer');

      expect(fake.lastSpoken, isNull);
      expect(service.isSpeaking.value, isFalse);
    });

    test('ошибка бэкенда в speak — не бросает, isSpeaking сброшен', () async {
      final fake = FakeTtsBackend()..speakError = Exception('движок занят');
      final service = PronunciationService(backend: fake);
      await service.start();

      await service.speak('no-brainer'); // не должен бросить

      expect(service.isSpeaking.value, isFalse);
    });

    test('колбэк ошибки платформы сбрасывает isSpeaking', () async {
      final fake = FakeTtsBackend();
      final service = PronunciationService(backend: fake);
      await service.start();

      service.isSpeaking.value = true; // «речь идёт»
      fake.failHandler!('audio focus loss');

      expect(service.isSpeaking.value, isFalse);
    });
  });

  group('PronunciationService — освобождение', () {
    test('dispose глушит речь', () async {
      final fake = FakeTtsBackend();
      final service = PronunciationService(backend: fake);
      await service.start();

      service.dispose();

      expect(fake.calls, contains('stop'));
    });

    test('после dispose платформенные колбэки не роняют сервис', () async {
      final fake = FakeTtsBackend();
      final service = PronunciationService(backend: fake);
      await service.start();

      service.dispose();
      // Платформа ответила поздно: ни throw, ни запись в освобожденный
      // ValueNotifier («used after dispose»).
      fake.finishHandler!();
      fake.failHandler!('late error');
    });
  });
}
