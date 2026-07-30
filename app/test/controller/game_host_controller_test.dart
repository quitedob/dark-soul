import 'dart:convert';

import 'package:ashen_hollow_app/src/bridge/game_bridge.dart';
import 'package:ashen_hollow_app/src/controller/game_host_controller.dart';
import 'package:ashen_hollow_app/src/model/game_save_v1.dart';
import 'package:ashen_hollow_app/src/model/game_save_v2.dart';
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

  test('controller migrates v1 initialization and emits v2 JSON', () async {
    controller.dispose();
    await host.close();
    host = FakeGameHostClient();
    controller = GameHostController(
      host: host,
      save: const GameSaveV1(
        checkpointId: 'lower_arena',
        embers: 12,
        combatStyle: 1,
      ),
    );

    controller.startGame();
    await controller.attachPlatformView(8);
    host.emit(const WebHostEvent(type: 'ready', viewId: 8));
    await Future<void>.delayed(Duration.zero);

    final GameBridgeEnvelope initialize = GameBridgeEnvelope.decode(
      host.bridgeMessages.single,
    );
    final Map<String, Object?> save =
        initialize.payload['save']! as Map<String, Object?>;
    expect(save['schemaVersion'], GameSaveV2.schemaVersion);
    expect(save.keys, <String>{
      'schemaVersion',
      'location',
      'player',
      'inventory',
      'progression',
      'lostEcho',
      'playTimeMs',
      'updatedAtEpochMs',
    });
    expect(save['location'], <String, Object?>{
      'chapterId': 'chapter_01',
      'levelId': 'level_01_01',
      'checkpointId': 'lower_arena',
    });
    expect(controller.save.checkpointId, 'lower_arena');
    expect(controller.save.player.rightHand, 'xingtian_axe_right');
  });

  test('controller accepts canonical v2 construction unchanged', () async {
    controller.dispose();
    await host.close();
    host = FakeGameHostClient();
    final GameSaveV2 canonical = GameSaveV2(
      location: const GameSaveLocationV2(
        chapterId: 'chapter_03',
        levelId: 'level_03_02',
        checkpointId: 'sunken_bell',
      ),
      player: const GameSavePlayerV2(
        upgradeTier: 4,
        rightHand: 'bell_hammer',
        leftHand: 'bell_guard',
      ),
      progression: GameSaveProgressionV2(),
      lostEcho: GameSaveLostEchoV2(levelId: 'level_03_02'),
    );
    controller = GameHostController(host: host, save: canonical);

    expect(controller.save, same(canonical));
  });

  test('controller accepts and migrates a v1 save.changed payload', () async {
    const GameSaveV1 incoming = GameSaveV1(
      checkpointId: 'legacy_gate',
      embers: 31,
      combatStyle: 4,
    );

    host.emit(
      WebHostEvent(
        type: 'bridgeMessage',
        viewId: 9,
        bridgeJson: GameBridgeEnvelope(
          type: GameBridgeTypes.saveChanged,
          requestId: 'godot-save-1',
          payload: <String, Object?>{'save': incoming.toJson()},
        ).encode(),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.save.checkpointId, 'legacy_gate');
    expect(controller.save.embers, 31);
    expect(controller.save.player.rightHand, 'prayer_beads');
  });

  test('controller accepts a v2 save.changed payload', () async {
    final GameSaveV2 incoming = GameSaveV2(
      location: const GameSaveLocationV2(
        chapterId: 'chapter_02',
        levelId: 'level_02_01',
        checkpointId: 'guardian_gate',
      ),
      player: const GameSavePlayerV2(
        embers: 88,
        focus: 21,
        upgradeTier: 2,
        rightHand: 'custom_blade',
        leftHand: 'custom_chime',
      ),
      inventory: const <String, int>{'ember_shard': 3},
      progression: GameSaveProgressionV2(
        completedLevelIds: const <String>['level_01_01'],
        activatedCheckpointIds: const <String>['guardian_gate'],
        activatedShortcutIds: const <String>['ancient_gate'],
        defeatedBossIds: const <String>['boss_giant_gate'],
        completedPuzzleIds: const <String>['gate_seal'],
        collectedLootIds: const <String>['gate_key'],
        choiceFlags: const <String, bool>{'chapter_one_complete': true},
        values: const <String, int>{'deaths': 2},
      ),
      lostEcho: GameSaveLostEchoV2(
        amount: 15,
        levelId: 'level_02_01',
        position: const <double>[4, 5, 6],
      ),
      playTimeMs: 7000,
      updatedAtEpochMs: 9000,
    );

    host.emit(
      WebHostEvent(
        type: 'bridgeMessage',
        viewId: 9,
        bridgeJson: GameBridgeEnvelope(
          type: GameBridgeTypes.saveChanged,
          requestId: 'godot-save-2',
          payload: <String, Object?>{'save': incoming.toJson()},
        ).encode(),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.save, incoming);
    expect(controller.errorMessage, isNull);
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
