import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Тонкая обёртка над плагином `flutter_tts` — только то, что нужно
/// произношению слова дня (этап 9, PLAN.md §1 «Произношение»).
///
/// Как и `NotificationsBackend` (этап 7), продакшн-плагин скрыт за
/// интерфейсом: сервис тестируется на фейке, UI про движок не знает.
abstract class TtsBackend {
  /// Настраивает движок под язык [PronunciationService.language] и режим,
  /// при котором [speak] завершается вместе с концом речи
  /// (`awaitSpeakCompletion(true)`); [onSpeechFinished] и [onSpeechFailed] —
  /// колбэки платформы по ходу воспроизведения.
  Future<void> initialize({
    required VoidCallback onSpeechFinished,
    required void Function(String message) onSpeechFailed,
  });

  /// Есть ли у системного TTS-движка голос языка [language].
  Future<bool> isLanguageAvailable(String language);

  /// Произнести [text]; перебивает идущую речь.
  Future<void> speak(String text);

  /// Остановить воспроизведение.
  Future<void> stop();
}

/// Продакшн-реализация поверх системного TTS-движка Android.
///
/// Играет движок, предустановленный на устройстве (Google Speech Services
/// и т.п.): офлайн, без прав в манифесте (PLAN.md §10).
class FlutterTtsBackend implements TtsBackend {
  final FlutterTts _plugin = FlutterTts();

  @override
  Future<void> initialize({
    required VoidCallback onSpeechFinished,
    required void Function(String message) onSpeechFailed,
  }) async {
    await _plugin.setLanguage(PronunciationService.language);
    // 0.5 — «нормальная» скорость для en-US-голосов плагина.
    await _plugin.setSpeechRate(0.5);
    await _plugin.awaitSpeakCompletion(true);
    _plugin.setCompletionHandler(onSpeechFinished);
    // ErrorHandler плагина принимает dynamic — адаптируем под строгий
    // контракт интерфейса (строка).
    _plugin.setErrorHandler(
      (dynamic message) => onSpeechFailed(message.toString()),
    );
  }

  @override
  Future<bool> isLanguageAvailable(String language) async =>
      (await _plugin.isLanguageAvailable(language)) as bool;

  @override
  Future<void> speak(String text) => _plugin.speak(text);

  @override
  Future<void> stop() => _plugin.stop();
}

/// Произношение слова дня системным TTS-движком — этап 9
/// (PLAN.md §1 «Произношение», §8).
///
/// Владеет [TtsBackend] и состоянием воспроизведения [isSpeaking];
/// `HomeScreen` подключает их к карточке: `onListen` на кнопке-динамике
/// в [WordCard] (только внутри приложения — RemoteViews виджета звук
/// проигрывать не могут).
///
/// Мягкая деградация как у уведомлений (этап 7): нет движка/голоса en-US
/// или упал плагин — [isAvailable] остаётся false, кнопки в карточке нет,
/// остальное приложение работает (риск №13 в PLAN.md §9).
class PronunciationService {
  PronunciationService({TtsBackend? backend})
      : _backend = backend ?? FlutterTtsBackend();

  final TtsBackend _backend;

  /// Язык озвучивания: транскрипции базы — американская IPA (PLAN.md §4),
  /// поэтому и голос берём en-US.
  static const String language = 'en-US';

  /// Идёт ли воспроизведение прямо сейчас: кнопка карточки слушает
  /// (`ValueListenableBuilder`) и переключает иконку динамика на «стоп».
  final ValueNotifier<bool> isSpeaking = ValueNotifier<bool>(false);

  /// Доступно ли озвучивание: true только после успешного [start] и при
  /// наличии голоса [language] в системном движке. До [start] — false
  /// (кнопки в карточке нет).
  bool get isAvailable => _available;
  bool _available = false;

  /// Экземпляр освобожден ([dispose]) — платформенные колбэки игнорируем.
  bool _disposed = false;

  /// Стартовый прогон: настройка движка и проверка голоса en-US.
  Future<void> start() => _quietly('start', () async {
        await _backend.initialize(
          onSpeechFinished: () => _setSpeaking(false),
          onSpeechFailed: (message) {
            debugPrint('Pronunciation: ошибка TTS: $message');
            _setSpeaking(false);
          },
        );
        _available = await _backend.isLanguageAvailable(language);
        if (!_available) {
          debugPrint('Pronunciation: в системном TTS нет голоса $language — '
              'кнопка скрыта (риск №13 в PLAN.md §9)');
        }
      });

  /// Произнести [text] — слово/фразу дня целиком (для идиом и фразовых
  /// глаголов «произношение записи» — это вся фраза).
  ///
  /// Идущая речь перебивается — так ведёт себя `speak()` движка.
  Future<void> speak(String text) async {
    if (!_available) return;
    _setSpeaking(true);
    await _quietly('speak', () => _backend.speak(text));
    // awaitSpeakCompletion(true): future резолвится по концу речи, а не
    // по постановке в очередь; колбэки initialize — страховка от
    // «залипшего» true, если движок умер посреди фразы.
    _setSpeaking(false);
  }

  /// Остановить воспроизведение.
  Future<void> stop() async {
    await _quietly('stop', _backend.stop);
    _setSpeaking(false);
  }

  /// Поведение кнопки карточки: молчит — произнести, говорит — остановить.
  Future<void> toggle(String text) =>
      isSpeaking.value ? stop() : speak(text);

  /// Глушит речь и освобождает слушателей; вызывается из `dispose` экрана.
  void dispose() {
    _disposed = true;
    // Не ждём: экран уходит, а остановка речи в плагине — фоновой операцией.
    unawaited(_backendStopQuietly());
    isSpeaking.dispose();
  }

  Future<void> _backendStopQuietly() => _quietly('stop', _backend.stop);

  /// Запись в [isSpeaking] после [dispose] запрещена (ValueNotifier бросает
  /// «used after dispose»), а платформенные колбэки могут прийти поздно.
  void _setSpeaking(bool value) {
    if (_disposed) return;
    isSpeaking.value = value;
  }

  /// Все операции TTS не должны ронять UI: ошибки плагина (в том числе
  /// отсутствие платформенной реализации в тестах) логируем и глотаем —
  /// как в `NotificationService` (этап 7).
  Future<void> _quietly(String what, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('Pronunciation: $what не удался: $e');
    }
  }
}
