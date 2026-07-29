import 'package:ashen_hollow_app/src/l10n/app_strings.dart';
import 'package:ashen_hollow_app/src/model/game_settings_v1.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Chinese catalog exposes localized shell and save labels', () {
    final AppStrings strings = AppStrings.forLocale(
      GameSettingsV1.supportedLocaleSimplifiedChinese,
    );

    expect(strings.title, '灰烬幽谷');
    expect(strings.loading, '正在点燃余烬');
    expect(strings.settings, '设置');
    expect(strings.errorTitle, '余烬已熄灭');
    expect(strings.embers, '余烬');
    expect(strings.checkpoint, '存档点');
  });

  test('unknown locale falls back to English', () {
    final AppStrings strings = AppStrings.forLocale('unsupported');

    expect(strings.title, 'ASHEN HOLLOW');
    expect(strings.retry, 'RETRY');
  });
}
