import 'dart:convert';

import 'package:ashen_hollow_app/src/bridge/game_bridge.dart';
import 'package:ashen_hollow_app/src/controller/game_host_controller.dart';
import 'package:ashen_hollow_app/src/model/game_settings_v1.dart';
import 'package:ashen_hollow_web_host/ashen_hollow_web_host.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_game_host_client.dart';

void main() {
  late FakeGameHostClient host;
  late GameHostController controller;

  setUp(() {
    host = FakeGameHostClient();
    controller = GameHostController(host: host);
  });

  tearDown(() async {
    controller.dispose();
    await host.close();
  });

  test('launcher waits for the Godot bridge ready event', () async {
    controller.startGame();
    expect(controller.state, GameHostState.loading);

    await controller.attachPlatformView(7);
    expect(host.calls.first, 'attach:7');
    expect(host.calls.last, startsWith('load:'));
    expect(host.bridgeMessages, isEmpty);

    host.emit(const WebHostEvent(type: 'ready', viewId: 7));
    await Future<void>.delayed(Duration.zero);
    expect(controller.state, GameHostState.loading);
    expect(host.bridgeMessages, hasLength(1));

    final Map<String, Object?> initial =
        jsonDecode(host.bridgeMessages.single) as Map<String, Object?>;
    expect(initial['protocolVersion'], GameBridgeEnvelope.protocolVersion);
    expect(initial['type'], GameBridgeTypes.initialize);

    host.emit(
      WebHostEvent(
        type: 'bridgeMessage',
        viewId: 7,
        bridgeJson: const GameBridgeEnvelope(
          type: GameBridgeTypes.ready,
          requestId: 'godot-1',
        ).encode(),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.state, GameHostState.game);
  });

  test(
    'settings are immutable and forwarded through the JSON bridge',
    () async {
      controller.startGame();
      await controller.attachPlatformView(3);
      host.emit(const WebHostEvent(type: 'ready', viewId: 3));
      await Future<void>.delayed(Duration.zero);
      host.bridgeMessages.clear();

      const GameSettingsV1 updated = GameSettingsV1(reducedMotion: true);
      await controller.updateSettings(updated);

      expect(controller.settings, updated);
      final GameBridgeEnvelope command = GameBridgeEnvelope.decode(
        host.bridgeMessages.single,
      );
      expect(command.type, GameBridgeTypes.applySettings);
      expect(command.payload['settings'], updated.toJson());
    },
  );

  test('locale persists and is applied through settings.apply', () async {
    controller.startGame();
    await controller.attachPlatformView(4);
    host.emit(const WebHostEvent(type: 'ready', viewId: 4));
    await Future<void>.delayed(Duration.zero);
    host.bridgeMessages.clear();

    await controller.updateSettings(
      controller.settings.copyWith(
        locale: GameSettingsV1.supportedLocaleSimplifiedChinese,
      ),
    );

    expect(
      controller.settings.locale,
      GameSettingsV1.supportedLocaleSimplifiedChinese,
    );
    final GameBridgeEnvelope command = GameBridgeEnvelope.decode(
      host.bridgeMessages.single,
    );
    final Map<String, Object?> applied =
        command.payload['settings']! as Map<String, Object?>;
    expect(command.type, GameBridgeTypes.applySettings);
    expect(applied['locale'], GameSettingsV1.supportedLocaleSimplifiedChinese);
  });

  test('host failures enter recoverable error state', () async {
    host.failLoad = true;
    controller.startGame();
    await controller.attachPlatformView(5);

    expect(controller.state, GameHostState.error);
    expect(controller.errorMessage, contains('load failed'));

    controller.backToLauncher();
    expect(controller.state, GameHostState.launcher);
  });
}
