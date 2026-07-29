import 'package:flutter/foundation.dart';

@immutable
class GameSettingsV1 {
  const GameSettingsV1({
    this.locale = supportedLocaleEnglish,
    this.masterVolume = 0.85,
    this.musicVolume = 0.70,
    this.effectsVolume = 0.85,
    this.cameraSensitivity = 1.0,
    this.subtitlesEnabled = true,
    this.reducedMotion = false,
  }) : assert(masterVolume >= 0 && masterVolume <= 1),
       assert(musicVolume >= 0 && musicVolume <= 1),
       assert(effectsVolume >= 0 && effectsVolume <= 1),
       assert(cameraSensitivity >= 0.25 && cameraSensitivity <= 2);

  static const int schemaVersion = 1;
  static const String supportedLocaleEnglish = 'en';
  static const String supportedLocaleSimplifiedChinese = 'zh_CN';
  static const Set<String> supportedLocales = <String>{
    supportedLocaleEnglish,
    supportedLocaleSimplifiedChinese,
  };

  final String locale;
  final double masterVolume;
  final double musicVolume;
  final double effectsVolume;
  final double cameraSensitivity;
  final bool subtitlesEnabled;
  final bool reducedMotion;

  GameSettingsV1 copyWith({
    String? locale,
    double? masterVolume,
    double? musicVolume,
    double? effectsVolume,
    double? cameraSensitivity,
    bool? subtitlesEnabled,
    bool? reducedMotion,
  }) {
    return GameSettingsV1(
      locale: locale ?? this.locale,
      masterVolume: masterVolume ?? this.masterVolume,
      musicVolume: musicVolume ?? this.musicVolume,
      effectsVolume: effectsVolume ?? this.effectsVolume,
      cameraSensitivity: cameraSensitivity ?? this.cameraSensitivity,
      subtitlesEnabled: subtitlesEnabled ?? this.subtitlesEnabled,
      reducedMotion: reducedMotion ?? this.reducedMotion,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'locale': locale,
    'masterVolume': masterVolume,
    'musicVolume': musicVolume,
    'effectsVolume': effectsVolume,
    'cameraSensitivity': cameraSensitivity,
    'subtitlesEnabled': subtitlesEnabled,
    'reducedMotion': reducedMotion,
  };

  factory GameSettingsV1.fromJson(Map<String, Object?> json) {
    _expectVersion(json);
    final String locale = _readString(json, 'locale');
    if (!supportedLocales.contains(locale)) {
      throw FormatException('Unsupported locale: $locale');
    }
    final double masterVolume = _readDouble(json, 'masterVolume');
    final double musicVolume = _readDouble(json, 'musicVolume');
    final double effectsVolume = _readDouble(json, 'effectsVolume');
    final double cameraSensitivity = _readDouble(json, 'cameraSensitivity');
    _expectRange(masterVolume, 'masterVolume', 0, 1);
    _expectRange(musicVolume, 'musicVolume', 0, 1);
    _expectRange(effectsVolume, 'effectsVolume', 0, 1);
    _expectRange(cameraSensitivity, 'cameraSensitivity', 0.25, 2);
    return GameSettingsV1(
      locale: locale,
      masterVolume: masterVolume,
      musicVolume: musicVolume,
      effectsVolume: effectsVolume,
      cameraSensitivity: cameraSensitivity,
      subtitlesEnabled: _readBool(json, 'subtitlesEnabled'),
      reducedMotion: _readBool(json, 'reducedMotion'),
    );
  }

  static void _expectVersion(Map<String, Object?> json) {
    if (json['schemaVersion'] != schemaVersion) {
      throw FormatException(
        'Unsupported GameSettings schema: ${json['schemaVersion']}',
      );
    }
  }

  static double _readDouble(Map<String, Object?> json, String key) {
    final Object? value = json[key];
    if (value is! num) {
      throw FormatException('$key must be numeric.');
    }
    return value.toDouble();
  }

  static bool _readBool(Map<String, Object?> json, String key) {
    final Object? value = json[key];
    if (value is! bool) {
      throw FormatException('$key must be boolean.');
    }
    return value;
  }

  static String _readString(Map<String, Object?> json, String key) {
    final Object? value = json[key];
    if (value is! String) {
      throw FormatException('$key must be a string.');
    }
    return value;
  }

  static void _expectRange(
    double value,
    String key,
    double minimum,
    double maximum,
  ) {
    if (value < minimum || value > maximum) {
      throw FormatException('$key must be between $minimum and $maximum.');
    }
  }

  @override
  bool operator ==(Object other) {
    return other is GameSettingsV1 &&
        other.locale == locale &&
        other.masterVolume == masterVolume &&
        other.musicVolume == musicVolume &&
        other.effectsVolume == effectsVolume &&
        other.cameraSensitivity == cameraSensitivity &&
        other.subtitlesEnabled == subtitlesEnabled &&
        other.reducedMotion == reducedMotion;
  }

  @override
  int get hashCode => Object.hash(
    locale,
    masterVolume,
    musicVolume,
    effectsVolume,
    cameraSensitivity,
    subtitlesEnabled,
    reducedMotion,
  );
}
