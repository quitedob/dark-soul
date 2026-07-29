import 'package:flutter/foundation.dart';

@immutable
class GameSaveV1 {
  const GameSaveV1({
    this.checkpointId = 'ember_shrine',
    this.embers = 0,
    this.focus = 80,
    this.combatStyle = 0,
    this.lostEchoAmount = 0,
    this.lostEchoPosition = const <double>[0, 0, 0],
    this.activatedShortcuts = const <String>[],
    this.shortcutOpen = false,
    this.guardianDefeated = false,
    this.playTimeMs = 0,
    this.updatedAtEpochMs = 0,
  }) : assert(checkpointId != ''),
       assert(embers >= 0),
       assert(focus >= 0 && focus <= 80),
       assert(combatStyle >= 0 && combatStyle <= 4),
       assert(lostEchoAmount >= 0),
       assert(playTimeMs >= 0),
       assert(updatedAtEpochMs >= 0);

  static const int schemaVersion = 1;

  final String checkpointId;
  final int embers;
  final double focus;
  final int combatStyle;
  final int lostEchoAmount;
  final List<double> lostEchoPosition;
  final List<String> activatedShortcuts;
  final bool shortcutOpen;
  final bool guardianDefeated;
  final int playTimeMs;
  final int updatedAtEpochMs;

  GameSaveV1 copyWith({
    String? checkpointId,
    int? embers,
    double? focus,
    int? combatStyle,
    int? lostEchoAmount,
    List<double>? lostEchoPosition,
    List<String>? activatedShortcuts,
    bool? shortcutOpen,
    bool? guardianDefeated,
    int? playTimeMs,
    int? updatedAtEpochMs,
  }) {
    return GameSaveV1(
      checkpointId: checkpointId ?? this.checkpointId,
      embers: embers ?? this.embers,
      focus: focus ?? this.focus,
      combatStyle: combatStyle ?? this.combatStyle,
      lostEchoAmount: lostEchoAmount ?? this.lostEchoAmount,
      lostEchoPosition: lostEchoPosition ?? this.lostEchoPosition,
      activatedShortcuts: activatedShortcuts ?? this.activatedShortcuts,
      shortcutOpen: shortcutOpen ?? this.shortcutOpen,
      guardianDefeated: guardianDefeated ?? this.guardianDefeated,
      playTimeMs: playTimeMs ?? this.playTimeMs,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'checkpointId': checkpointId,
    'embers': embers,
    'focus': focus,
    'combatStyle': combatStyle,
    'lostEcho': <String, Object?>{
      'amount': lostEchoAmount,
      'position': lostEchoPosition,
    },
    'activatedShortcuts': <String>{
      ...activatedShortcuts,
      if (shortcutOpen) 'ancient_gate',
    }.toList(growable: false),
    'shortcutOpen': shortcutOpen,
    'guardianDefeated': guardianDefeated,
    'playTimeMs': playTimeMs,
    'updatedAtEpochMs': updatedAtEpochMs,
  };

  factory GameSaveV1.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != schemaVersion) {
      throw FormatException(
        'Unsupported GameSave schema: ${json['schemaVersion']}',
      );
    }
    final String checkpointId = _read<String>(json, 'checkpointId');
    final int embers = _read<int>(json, 'embers');
    final double focus = _readNumber(json, 'focus').toDouble();
    final int combatStyle = _read<int>(json, 'combatStyle');
    final Map<String, Object?> lostEcho = _readMap(json, 'lostEcho');
    final int lostEchoAmount = _read<int>(lostEcho, 'amount');
    final List<double> lostEchoPosition = _readVector3(lostEcho, 'position');
    final List<String> activatedShortcuts = _readStringList(
      json,
      'activatedShortcuts',
    );
    final bool shortcutOpen =
        _read<bool>(json, 'shortcutOpen') ||
        activatedShortcuts.contains('ancient_gate');
    final int playTimeMs = _read<int>(json, 'playTimeMs');
    final int updatedAtEpochMs = _read<int>(json, 'updatedAtEpochMs');
    if (checkpointId.isEmpty) {
      throw const FormatException('checkpointId cannot be empty.');
    }
    if (embers < 0 ||
        lostEchoAmount < 0 ||
        playTimeMs < 0 ||
        updatedAtEpochMs < 0) {
      throw const FormatException('Save counters cannot be negative.');
    }
    if (focus < 0 || focus > 80 || combatStyle < 0 || combatStyle > 4) {
      throw const FormatException('Save combat state is out of range.');
    }
    return GameSaveV1(
      checkpointId: checkpointId,
      embers: embers,
      focus: focus,
      combatStyle: combatStyle,
      lostEchoAmount: lostEchoAmount,
      lostEchoPosition: List<double>.unmodifiable(lostEchoPosition),
      activatedShortcuts: List<String>.unmodifiable(activatedShortcuts),
      shortcutOpen: shortcutOpen,
      guardianDefeated: _read<bool>(json, 'guardianDefeated'),
      playTimeMs: playTimeMs,
      updatedAtEpochMs: updatedAtEpochMs,
    );
  }

  static T _read<T>(Map<String, Object?> json, String key) {
    final Object? value = json[key];
    if (value is! T) {
      throw FormatException('$key must be a $T.');
    }
    return value;
  }

  static num _readNumber(Map<String, Object?> json, String key) {
    final Object? value = json[key];
    if (value is! num) {
      throw FormatException('$key must be numeric.');
    }
    return value;
  }

  static Map<String, Object?> _readMap(Map<String, Object?> json, String key) {
    final Object? value = json[key];
    if (value is! Map<String, Object?>) {
      throw FormatException('$key must be an object.');
    }
    return value;
  }

  static List<String> _readStringList(Map<String, Object?> json, String key) {
    final Object? value = json[key];
    if (value is! List<Object?> ||
        value.any((Object? item) => item is! String)) {
      throw FormatException('$key must be a string list.');
    }
    return value.cast<String>();
  }

  static List<double> _readVector3(Map<String, Object?> json, String key) {
    final Object? value = json[key];
    if (value is! List<Object?> ||
        value.length != 3 ||
        value.any((Object? item) => item is! num)) {
      throw FormatException('$key must be a three-number list.');
    }
    return value.cast<num>().map((num item) => item.toDouble()).toList();
  }

  @override
  bool operator ==(Object other) {
    return other is GameSaveV1 &&
        other.checkpointId == checkpointId &&
        other.embers == embers &&
        other.focus == focus &&
        other.combatStyle == combatStyle &&
        other.lostEchoAmount == lostEchoAmount &&
        listEquals(other.lostEchoPosition, lostEchoPosition) &&
        listEquals(other.activatedShortcuts, activatedShortcuts) &&
        other.shortcutOpen == shortcutOpen &&
        other.guardianDefeated == guardianDefeated &&
        other.playTimeMs == playTimeMs &&
        other.updatedAtEpochMs == updatedAtEpochMs;
  }

  @override
  int get hashCode => Object.hash(
    checkpointId,
    embers,
    focus,
    combatStyle,
    lostEchoAmount,
    Object.hashAll(lostEchoPosition),
    Object.hashAll(activatedShortcuts),
    shortcutOpen,
    guardianDefeated,
    playTimeMs,
    updatedAtEpochMs,
  );
}
