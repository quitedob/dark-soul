import 'package:ashen_hollow_app/src/model/game_save_v1.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GameSaveV1 round-trips and copyWith preserves the original', () {
    const GameSaveV1 save = GameSaveV1(
      checkpointId: 'lower_arena',
      embers: 42,
      focus: 33,
      combatStyle: 3,
      lostEchoAmount: 17,
      lostEchoPosition: <double>[1, 2, 3],
      activatedShortcuts: <String>['ancient_gate'],
      shortcutOpen: true,
      guardianDefeated: false,
      playTimeMs: 999,
      updatedAtEpochMs: 123456,
    );

    expect(GameSaveV1.fromJson(save.toJson()), save);
    expect(save.copyWith(embers: 84).embers, 84);
    expect(save.embers, 42);
  });

  test('GameSaveV1 rejects invalid schema and counters', () {
    expect(
      () => GameSaveV1.fromJson(<String, Object?>{
        ...const GameSaveV1().toJson(),
        'schemaVersion': 7,
      }),
      throwsFormatException,
    );
    expect(
      () => GameSaveV1.fromJson(<String, Object?>{
        ...const GameSaveV1().toJson(),
        'embers': -1,
      }),
      throwsFormatException,
    );
  });
}
