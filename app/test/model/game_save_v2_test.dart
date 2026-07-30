import 'package:ashen_hollow_app/src/model/game_save_v1.dart';
import 'package:ashen_hollow_app/src/model/game_save_v2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GameSaveV1 migrates to canonical nested v2', () {
    const GameSaveV1 legacy = GameSaveV1(
      checkpointId: 'lower_arena',
      embers: 42,
      focus: 33,
      combatStyle: 2,
      lostEchoAmount: 17,
      lostEchoPosition: <double>[1, 2, 3],
      activatedShortcuts: <String>['lift_one'],
      shortcutOpen: true,
      guardianDefeated: true,
      playTimeMs: 999,
      updatedAtEpochMs: 123456,
    );

    final GameSaveV2 migrated = GameSaveV2.fromV1(legacy);

    expect(migrated.toJson(), <String, Object?>{
      'schemaVersion': 2,
      'location': <String, Object?>{
        'chapterId': 'chapter_01',
        'levelId': 'level_01_01',
        'checkpointId': 'lower_arena',
      },
      'player': <String, Object?>{
        'embers': 42,
        'focus': 33.0,
        'upgradeTier': 0,
        'rightHand': 'marksman_bow',
        'leftHand': 'marksman_dagger',
      },
      'inventory': <String, int>{},
      'progression': <String, Object?>{
        'completedLevelIds': <String>[],
        'defeatedBossIds': <String>['boss_giant_gate'],
        'activatedCheckpointIds': <String>['lower_arena'],
        'activatedShortcutIds': <String>['lift_one', 'ancient_gate'],
        'completedPuzzleIds': <String>[],
        'collectedLootIds': <String>[],
        'choiceFlags': <String, bool>{
          'shortcutOpen': true,
          'guardianDefeated': true,
        },
        'values': <String, int>{'legacyCombatStyle': 2},
      },
      'lostEcho': <String, Object?>{
        'amount': 17,
        'levelId': 'level_01_01',
        'position': <double>[1, 2, 3],
      },
      'playTimeMs': 999,
      'updatedAtEpochMs': 123456,
    });
    expect(GameSaveV2.fromJson(migrated.toJson()), migrated);
  });

  test('v1 defaults and combat styles use canonical IDs', () {
    const List<(String, String)> equipment = <(String, String)>[
      ('guardian_sword', 'reliquary_shield'),
      ('xingtian_axe_right', 'xingtian_axe_left'),
      ('marksman_bow', 'marksman_dagger'),
      ('five_elements_seal', 'spirit_stone'),
      ('prayer_beads', 'talisman_papers'),
    ];

    for (var style = 0; style < equipment.length; style += 1) {
      final GameSaveV2 migrated = GameSaveV2.fromV1(
        GameSaveV1(combatStyle: style),
      );

      expect(migrated.location.chapterId, 'chapter_01');
      expect(migrated.location.levelId, 'level_01_01');
      expect(migrated.location.checkpointId, 'ember_shrine');
      expect(migrated.player.upgradeTier, 0);
      expect(migrated.player.rightHand, equipment[style].$1);
      expect(migrated.player.leftHand, equipment[style].$2);
      expect(migrated.lostEcho.levelId, 'level_01_01');
      expect(migrated.progression.values['legacyCombatStyle'], style);
    }
  });

  test('GameSaveV2 accepts and preserves the canonical bridge shape', () {
    final Map<String, Object?> json = <String, Object?>{
      'schemaVersion': 2,
      'location': <String, Object?>{
        'chapterId': 'chapter_02',
        'levelId': 'level_02_03',
        'checkpointId': 'flooded_archive',
      },
      'player': <String, Object?>{
        'embers': 80,
        'focus': 25.5,
        'upgradeTier': 3,
        'rightHand': 'archive_blade',
        'leftHand': 'archive_lantern',
      },
      'inventory': <String, Object?>{'ember_shard': 2},
      'progression': <String, Object?>{
        'completedLevelIds': <Object?>['level_01_01'],
        'defeatedBossIds': <Object?>['boss_giant_gate'],
        'activatedCheckpointIds': <Object?>['flooded_archive'],
        'activatedShortcutIds': <Object?>['archive_lift'],
        'completedPuzzleIds': <Object?>['mirror_lock'],
        'collectedLootIds': <Object?>['archive_key'],
        'choiceFlags': <String, Object?>{'spared_keeper': true},
        'values': <String, Object?>{'archive_depth': 4},
      },
      'lostEcho': <String, Object?>{
        'amount': 12,
        'levelId': 'level_02_03',
        'position': <Object?>[4, 5.5, 6],
      },
      'playTimeMs': 7000,
      'updatedAtEpochMs': 9000,
    };

    final GameSaveV2 save = GameSaveV2.fromJson(json);

    expect(save.toJson(), json);
    expect(save.lostEcho.position, <double>[4, 5.5, 6]);
  });

  test('GameSaveV2 defensively copies collections', () {
    final Map<String, int> inventory = <String, int>{'ember_shard': 2};
    final List<String> shortcuts = <String>['ancient_gate'];
    final GameSaveV2 save = GameSaveV2(
      location: const GameSaveLocationV2(
        chapterId: 'chapter_01',
        levelId: 'level_01_01',
        checkpointId: 'ember_shrine',
      ),
      player: const GameSavePlayerV2(
        rightHand: 'guardian_sword',
        leftHand: 'reliquary_shield',
      ),
      inventory: inventory,
      progression: GameSaveProgressionV2(
        activatedShortcutIds: shortcuts,
      ),
      lostEcho: GameSaveLostEchoV2(levelId: 'level_01_01'),
    );

    inventory['ember_shard'] = 9;
    shortcuts.add('lift_one');

    expect(save.inventory, <String, int>{'ember_shard': 2});
    expect(save.progression.activatedShortcutIds, <String>['ancient_gate']);
    expect(() => save.inventory['new_item'] = 1, throwsUnsupportedError);
  });
}
