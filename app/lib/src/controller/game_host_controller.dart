import 'dart:async';

import 'package:ashen_hollow_app/src/bridge/game_bridge.dart';
import 'package:ashen_hollow_app/src/host/game_host_client.dart';
import 'package:ashen_hollow_app/src/model/game_save_v1.dart';
import 'package:ashen_hollow_app/src/model/game_save_v2.dart';
import 'package:ashen_hollow_app/src/model/game_settings_v1.dart';
import 'package:ashen_hollow_web_host/ashen_hollow_web_host.dart';
import 'package:flutter/foundation.dart';

enum GameHostState { launcher, loading, game, settings, error }

class GameHostController extends ChangeNotifier {
  GameHostController({
    required GameHostClient host,
    GameSettingsV1 settings = const GameSettingsV1(),
    Object save = const GameSaveV1(),
  }) : _host = host,
       _settings = settings,
       _save = _normalizeSave(save) {
    _eventSubscription = _host.events.listen(
      _onHostEvent,
      onError: (Object error, StackTrace stackTrace) {
        _fail('Native host event error: $error');
      },
    );
  }

  static const String defaultGameSource = 'resource://rawfile/game/index.html';

  static GameSaveV2 _normalizeSave(Object save) {
    return switch (save) {
      GameSaveV1 legacy => GameSaveV2.fromV1(legacy),
      GameSaveV2 canonical => canonical,
      _ => throw ArgumentError.value(
        save,
        'save',
        'must be a GameSaveV1 or GameSaveV2',
      ),
    };
  }

  final GameHostClient _host;
  late final StreamSubscription<WebHostEvent> _eventSubscription;
  GameHostState _state = GameHostState.launcher;
  GameHostState _settingsReturnState = GameHostState.launcher;
  GameSettingsV1 _settings;
  GameSaveV2 _save;
  String? _errorMessage;
  int _requestSequence = 0;
  bool _viewAttached = false;
  bool _startRequested = false;
  bool _pageReady = false;
  bool _initializationSent = false;
  bool _disposed = false;

  GameHostState get state => _state;
  GameSettingsV1 get settings => _settings;
  GameSaveV2 get save => _save;
  String? get errorMessage => _errorMessage;
  bool get hasActiveGame =>
      _state == GameHostState.loading ||
      _state == GameHostState.game ||
      (_state == GameHostState.settings &&
          _settingsReturnState == GameHostState.game);

  void startGame() {
    _errorMessage = null;
    _startRequested = true;
    _pageReady = false;
    _initializationSent = false;
    _setState(GameHostState.loading);
  }

  Future<void> attachPlatformView(int viewId) async {
    if (_disposed) {
      return;
    }
    try {
      await _host.attachView(viewId);
      _viewAttached = true;
      if (_startRequested) {
        await _host.load(defaultGameSource);
      }
    } catch (error) {
      _fail('Unable to attach the game surface: $error');
    }
  }

  void openSettings() {
    if (_state == GameHostState.game) {
      _settingsReturnState = GameHostState.game;
      unawaited(_host.pause());
    } else {
      _settingsReturnState = GameHostState.launcher;
    }
    _setState(GameHostState.settings);
  }

  void closeSettings() {
    final GameHostState destination = _settingsReturnState;
    _setState(destination);
    if (destination == GameHostState.game) {
      unawaited(_host.resume());
    }
  }

  Future<void> updateSettings(GameSettingsV1 settings) async {
    _settings = settings;
    notifyListeners();
    if (!_viewAttached) {
      return;
    }
    final GameBridgeEnvelope command = _command(
      GameBridgeTypes.applySettings,
      <String, Object?>{'settings': settings.toJson()},
    );
    try {
      await _host.sendBridgeJson(command.encode());
    } catch (error) {
      _fail('Unable to apply settings: $error');
    }
  }

  Future<void> handleLifecycle(bool resumed) async {
    if (!_viewAttached || !_startRequested) {
      return;
    }
    try {
      if (resumed) {
        await _host.resume();
      } else {
        await _host.pause();
      }
    } catch (error) {
      _fail('Unable to update game lifecycle: $error');
    }
  }

  void backToLauncher() {
    _startRequested = false;
    _viewAttached = false;
    _pageReady = false;
    _initializationSent = false;
    _setState(GameHostState.launcher);
    unawaited(_host.disposeHost());
  }

  void retry() {
    _viewAttached = false;
    startGame();
  }

  Future<void> _initializeHost() async {
    if (_initializationSent || !_pageReady || !_viewAttached) {
      return;
    }
    _initializationSent = true;
    try {
      await _host.sendBridgeJson(
        _command(GameBridgeTypes.initialize, <String, Object?>{
          'settings': _settings.toJson(),
          'save': _save.toJson(),
        }).encode(),
      );
    } catch (error) {
      _initializationSent = false;
      _fail('Unable to load Ashen Hollow: $error');
    }
  }

  void _onHostEvent(WebHostEvent event) {
    switch (event.type) {
      case 'ready':
        _pageReady = true;
        unawaited(_initializeHost());
        return;
      case 'error':
        _fail(
          event.payload['message']?.toString() ??
              'The native game host reported an error.',
        );
        return;
      case 'bridgeMessage':
        final String? json = event.bridgeJson;
        if (json == null) {
          _fail('Received an empty game bridge message.');
          return;
        }
        _handleBridgeMessage(json);
        return;
    }
  }

  void _handleBridgeMessage(String json) {
    try {
      final GameBridgeEnvelope envelope = GameBridgeEnvelope.decode(json);
      switch (envelope.type) {
        case GameBridgeTypes.ready:
          if (_state == GameHostState.loading) {
            _setState(GameHostState.game);
          }
          return;
        case GameBridgeTypes.saveChanged:
          final Object? rawSave = envelope.payload['save'];
          if (rawSave is! Map<String, Object?>) {
            throw const FormatException('save.changed requires a save object.');
          }
          _save = GameSaveV2.fromAnyJson(rawSave);
          notifyListeners();
          return;
        case GameBridgeTypes.error:
          _fail(
            envelope.payload['message']?.toString() ??
                'The game reported an unknown error.',
          );
          return;
      }
    } on FormatException catch (error) {
      _fail('Invalid game bridge message: ${error.message}');
    }
  }

  GameBridgeEnvelope _command(String type, Map<String, Object?> payload) {
    _requestSequence += 1;
    return GameBridgeEnvelope(
      type: type,
      requestId: 'flutter-$_requestSequence',
      payload: payload,
    );
  }

  void _fail(String message) {
    _errorMessage = message;
    _setState(GameHostState.error);
  }

  void _setState(GameHostState state) {
    if (_state == state) {
      return;
    }
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_eventSubscription.cancel());
    unawaited(_host.disposeHost());
    super.dispose();
  }
}
