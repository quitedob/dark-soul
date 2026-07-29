import 'package:ashen_hollow_app/src/model/game_settings_v1.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GameSettingsV1 round-trips without mutation', () {
    const GameSettingsV1 settings = GameSettingsV1(
      locale: GameSettingsV1.supportedLocaleSimplifiedChinese,
      masterVolume: 0.6,
      musicVolume: 0.4,
      effectsVolume: 0.8,
      cameraSensitivity: 1.25,
      subtitlesEnabled: false,
      reducedMotion: true,
    );

    expect(GameSettingsV1.fromJson(settings.toJson()), settings);
    expect(settings.copyWith(masterVolume: 0.2), isNot(same(settings)));
    expect(settings.masterVolume, 0.6);
    expect(
      GameSettingsV1.fromJson(settings.toJson()).locale,
      GameSettingsV1.supportedLocaleSimplifiedChinese,
    );
  });

  test('GameSettingsV1 rejects unsupported schemas and invalid ranges', () {
    expect(
      () => GameSettingsV1.fromJson(<String, Object?>{
        ...const GameSettingsV1().toJson(),
        'schemaVersion': 2,
      }),
      throwsFormatException,
    );
    expect(
      () => GameSettingsV1.fromJson(<String, Object?>{
        ...const GameSettingsV1().toJson(),
        'masterVolume': 2.0,
      }),
      throwsFormatException,
    );
    expect(
      () => GameSettingsV1.fromJson(<String, Object?>{
        ...const GameSettingsV1().toJson(),
        'locale': 'fr',
      }),
      throwsFormatException,
    );
  });
}
