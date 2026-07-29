import 'package:ashen_hollow_app/src/model/game_settings_v1.dart';

class AppStrings {
  const AppStrings._(this._values);

  static const AppStrings _english = AppStrings._(<String, String>{
    'title': 'ASHEN HOLLOW',
    'tagline': 'THE SHRINE REMEMBERS',
    'enter': 'ENTER THE HOLLOW',
    'settings': 'SETTINGS',
    'language': 'Language',
    'english': 'English',
    'chinese': '简体中文',
    'embers': 'Embers',
    'checkpoint': 'Checkpoint',
    'loading': 'KINDLING THE EMBERS',
    'masterVolume': 'Master volume',
    'music': 'Music',
    'effects': 'Effects',
    'cameraSensitivity': 'Camera sensitivity',
    'subtitles': 'Subtitles',
    'reducedMotion': 'Reduced motion',
    'reducedMotionHint':
        'Reduces shell transitions and requests calmer game motion.',
    'settingsTooltip': 'Settings',
    'exitTooltip': 'Return to launcher',
    'errorTitle': 'THE EMBER FADED',
    'unknownError': 'Unknown host error.',
    'back': 'BACK',
    'retry': 'RETRY',
  });

  static const AppStrings _simplifiedChinese = AppStrings._(<String, String>{
    'title': '灰烬幽谷',
    'tagline': '神龛铭记一切',
    'enter': '踏入幽谷',
    'settings': '设置',
    'language': '语言',
    'english': 'English',
    'chinese': '简体中文',
    'embers': '余烬',
    'checkpoint': '存档点',
    'loading': '正在点燃余烬',
    'masterVolume': '主音量',
    'music': '音乐',
    'effects': '音效',
    'cameraSensitivity': '镜头灵敏度',
    'subtitles': '字幕',
    'reducedMotion': '减少动态效果',
    'reducedMotionHint': '减少界面过渡，并请求游戏使用更平缓的动态效果。',
    'settingsTooltip': '设置',
    'exitTooltip': '返回启动页',
    'errorTitle': '余烬已熄灭',
    'unknownError': '未知的宿主错误。',
    'back': '返回',
    'retry': '重试',
  });

  final Map<String, String> _values;

  static AppStrings forLocale(String locale) {
    return switch (locale) {
      GameSettingsV1.supportedLocaleSimplifiedChinese => _simplifiedChinese,
      _ => _english,
    };
  }

  String _get(String key) => _values[key] ?? _english._values[key] ?? key;

  String get title => _get('title');
  String get tagline => _get('tagline');
  String get enter => _get('enter');
  String get settings => _get('settings');
  String get language => _get('language');
  String get english => _get('english');
  String get chinese => _get('chinese');
  String get embers => _get('embers');
  String get checkpoint => _get('checkpoint');
  String get loading => _get('loading');
  String get masterVolume => _get('masterVolume');
  String get music => _get('music');
  String get effects => _get('effects');
  String get cameraSensitivity => _get('cameraSensitivity');
  String get subtitles => _get('subtitles');
  String get reducedMotion => _get('reducedMotion');
  String get reducedMotionHint => _get('reducedMotionHint');
  String get settingsTooltip => _get('settingsTooltip');
  String get exitTooltip => _get('exitTooltip');
  String get errorTitle => _get('errorTitle');
  String get unknownError => _get('unknownError');
  String get back => _get('back');
  String get retry => _get('retry');
}
