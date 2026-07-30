import 'package:ashen_hollow_app/src/model/game_save_v1.dart';
import 'package:flutter/foundation.dart';

@immutable
class GameSaveV2 {
  GameSaveV2({
    required this.location,
    required this.player,
    Map<String, int> inventory = const <String, int>{},
    required this.progression,
    required this.lostEcho,
    this.playTimeMs = 0,
    this.updatedAtEpochMs = 0,
  }) : inventory = Map<String, int>.unmodifiable(inventory) {
    if (playTimeMs < 0 || updatedAtEpochMs < 0) {
      throw ArgumentError('Save counters cannot be negative.');
    }
    if (inventory.entries.any(
      (MapEntry<String, int> entry) =>
          entry.key.isEmpty || entry.value < 0,
    )) {
      throw ArgumentError('Invalid inventory entry.');
    }
  }

  static const int schemaVersion = 2;

  final GameSaveLocationV2 location;
  final GameSavePlayerV2 player;
  final Map<String, int> inventory;
  final GameSaveProgressionV2 progression;
  final GameSaveLostEchoV2 lostEcho;
  final int playTimeMs;
  final int updatedAtEpochMs;

  String get checkpointId => location.checkpointId;
  int get embers => player.embers;
  double get focus => player.focus;

  GameSaveV2 copyWith({
    GameSaveLocationV2? location,
    GameSavePlayerV2? player,
    Map<String, int>? inventory,
    GameSaveProgressionV2? progression,
    GameSaveLostEchoV2? lostEcho,
    int? playTimeMs,
    int? updatedAtEpochMs,
  }) {
    return GameSaveV2(
      location: location ?? this.location,
      player: player ?? this.player,
      inventory: inventory ?? this.inventory,
      progression: progression ?? this.progression,
      lostEcho: lostEcho ?? this.lostEcho,
      playTimeMs: playTimeMs ?? this.playTimeMs,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'location': location.toJson(),
    'player': player.toJson(),
    'inventory': inventory,
    'progression': progression.toJson(),
    'lostEcho': lostEcho.toJson(),
    'playTimeMs': playTimeMs,
    'updatedAtEpochMs': updatedAtEpochMs,
  };

  factory GameSaveV2.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != schemaVersion) {
      throw FormatException(
        'Unsupported GameSave schema: ${json['schemaVersion']}',
      );
    }
    return GameSaveV2(
      location: GameSaveLocationV2.fromJson(_readMap(json, 'location')),
      player: GameSavePlayerV2.fromJson(_readMap(json, 'player')),
      inventory: _readIntMap(json, 'inventory'),
      progression: GameSaveProgressionV2.fromJson(
        _readMap(json, 'progression'),
      ),
      lostEcho: GameSaveLostEchoV2.fromJson(_readMap(json, 'lostEcho')),
      playTimeMs: _readNonNegativeInt(json, 'playTimeMs'),
      updatedAtEpochMs: _readNonNegativeInt(json, 'updatedAtEpochMs'),
    );
  }

  factory GameSaveV2.fromAnyJson(Map<String, Object?> json) {
    return switch (json['schemaVersion']) {
      GameSaveV1.schemaVersion => GameSaveV2.fromV1(GameSaveV1.fromJson(json)),
      schemaVersion => GameSaveV2.fromJson(json),
      final Object? version => throw FormatException(
        'Unsupported GameSave schema: $version',
      ),
    };
  }

  factory GameSaveV2.fromV1(GameSaveV1 save) {
    final List<String> shortcutIds = <String>{
      ...save.activatedShortcuts,
      if (save.shortcutOpen) 'ancient_gate',
    }.toList(growable: false);
    return GameSaveV2(
      location: GameSaveLocationV2(
        chapterId: 'chapter_01',
        levelId: 'level_01_01',
        checkpointId: save.checkpointId,
      ),
      player: GameSavePlayerV2(
        embers: save.embers,
        focus: save.focus,
        upgradeTier: 0,
        rightHand: legacyRightHandByCombatStyle[save.combatStyle]!,
        leftHand: legacyLeftHandByCombatStyle[save.combatStyle]!,
      ),
      progression: GameSaveProgressionV2(
        activatedCheckpointIds: <String>[save.checkpointId],
        activatedShortcutIds: shortcutIds,
        defeatedBossIds: save.guardianDefeated
            ? const <String>['boss_giant_gate']
            : const <String>[],
        choiceFlags: <String, bool>{
          'shortcutOpen': save.shortcutOpen,
          'guardianDefeated': save.guardianDefeated,
        },
        values: <String, int>{'legacyCombatStyle': save.combatStyle},
      ),
      lostEcho: GameSaveLostEchoV2(
        amount: save.lostEchoAmount,
        levelId: 'level_01_01',
        position: save.lostEchoPosition,
      ),
      playTimeMs: save.playTimeMs,
      updatedAtEpochMs: save.updatedAtEpochMs,
    );
  }

  static const Map<int, String> legacyRightHandByCombatStyle = <int, String>{
    0: 'guardian_sword',
    1: 'xingtian_axe_right',
    2: 'marksman_bow',
    3: 'five_elements_seal',
    4: 'prayer_beads',
  };

  static const Map<int, String> legacyLeftHandByCombatStyle = <int, String>{
    0: 'reliquary_shield',
    1: 'xingtian_axe_left',
    2: 'marksman_dagger',
    3: 'spirit_stone',
    4: 'talisman_papers',
  };

  @override
  bool operator ==(Object other) {
    return other is GameSaveV2 &&
        other.location == location &&
        other.player == player &&
        mapEquals(other.inventory, inventory) &&
        other.progression == progression &&
        other.lostEcho == lostEcho &&
        other.playTimeMs == playTimeMs &&
        other.updatedAtEpochMs == updatedAtEpochMs;
  }

  @override
  int get hashCode => Object.hash(
    location,
    player,
    Object.hashAllUnordered(
      inventory.entries.map(
        (MapEntry<String, int> entry) => Object.hash(entry.key, entry.value),
      ),
    ),
    progression,
    lostEcho,
    playTimeMs,
    updatedAtEpochMs,
  );
}

@immutable
class GameSaveLocationV2 {
  const GameSaveLocationV2({
    required this.chapterId,
    required this.levelId,
    required this.checkpointId,
  }) : assert(chapterId != ''),
       assert(levelId != ''),
       assert(checkpointId != '');

  final String chapterId;
  final String levelId;
  final String checkpointId;

  Map<String, Object?> toJson() => <String, Object?>{
    'chapterId': chapterId,
    'levelId': levelId,
    'checkpointId': checkpointId,
  };

  factory GameSaveLocationV2.fromJson(Map<String, Object?> json) {
    return GameSaveLocationV2(
      chapterId: _readNonEmptyString(json, 'chapterId'),
      levelId: _readNonEmptyString(json, 'levelId'),
      checkpointId: _readNonEmptyString(json, 'checkpointId'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GameSaveLocationV2 &&
      other.chapterId == chapterId &&
      other.levelId == levelId &&
      other.checkpointId == checkpointId;

  @override
  int get hashCode => Object.hash(chapterId, levelId, checkpointId);
}

@immutable
class GameSavePlayerV2 {
  const GameSavePlayerV2({
    this.embers = 0,
    this.focus = 80,
    this.upgradeTier = 0,
    required this.rightHand,
    required this.leftHand,
  }) : assert(embers >= 0),
       assert(focus >= 0 && focus <= 80),
       assert(upgradeTier >= 0),
       assert(rightHand != ''),
       assert(leftHand != '');

  final int embers;
  final double focus;
  final int upgradeTier;
  final String rightHand;
  final String leftHand;

  Map<String, Object?> toJson() => <String, Object?>{
    'embers': embers,
    'focus': focus,
    'upgradeTier': upgradeTier,
    'rightHand': rightHand,
    'leftHand': leftHand,
  };

  factory GameSavePlayerV2.fromJson(Map<String, Object?> json) {
    final double focus = _readNumber(json, 'focus').toDouble();
    if (focus < 0 || focus > 80) {
      throw const FormatException('focus must be between 0 and 80.');
    }
    return GameSavePlayerV2(
      embers: _readNonNegativeInt(json, 'embers'),
      focus: focus,
      upgradeTier: _readNonNegativeInt(json, 'upgradeTier'),
      rightHand: _readNonEmptyString(json, 'rightHand'),
      leftHand: _readNonEmptyString(json, 'leftHand'),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GameSavePlayerV2 &&
        other.embers == embers &&
        other.focus == focus &&
        other.upgradeTier == upgradeTier &&
        other.rightHand == rightHand &&
        other.leftHand == leftHand;
  }

  @override
  int get hashCode => Object.hash(
    embers,
    focus,
    upgradeTier,
    rightHand,
    leftHand,
  );
}

@immutable
class GameSaveProgressionV2 {
  GameSaveProgressionV2({
    List<String> completedLevelIds = const <String>[],
    List<String> defeatedBossIds = const <String>[],
    List<String> activatedCheckpointIds = const <String>[],
    List<String> activatedShortcutIds = const <String>[],
    List<String> completedPuzzleIds = const <String>[],
    List<String> collectedLootIds = const <String>[],
    Map<String, bool> choiceFlags = const <String, bool>{},
    Map<String, int> values = const <String, int>{},
  }) : completedLevelIds = List<String>.unmodifiable(completedLevelIds),
       defeatedBossIds = List<String>.unmodifiable(defeatedBossIds),
       activatedCheckpointIds = List<String>.unmodifiable(
         activatedCheckpointIds,
       ),
       activatedShortcutIds = List<String>.unmodifiable(activatedShortcutIds),
       completedPuzzleIds = List<String>.unmodifiable(completedPuzzleIds),
       collectedLootIds = List<String>.unmodifiable(collectedLootIds),
       choiceFlags = Map<String, bool>.unmodifiable(choiceFlags),
       values = Map<String, int>.unmodifiable(values) {
    if (completedLevelIds.any((String id) => id.isEmpty) ||
        defeatedBossIds.any((String id) => id.isEmpty) ||
        activatedCheckpointIds.any((String id) => id.isEmpty) ||
        activatedShortcutIds.any((String id) => id.isEmpty) ||
        completedPuzzleIds.any((String id) => id.isEmpty) ||
        collectedLootIds.any((String id) => id.isEmpty) ||
        choiceFlags.keys.any((String id) => id.isEmpty) ||
        values.keys.any((String id) => id.isEmpty)) {
      throw ArgumentError('Progression IDs must be non-empty.');
    }
  }

  final List<String> completedLevelIds;
  final List<String> defeatedBossIds;
  final List<String> activatedCheckpointIds;
  final List<String> activatedShortcutIds;
  final List<String> completedPuzzleIds;
  final List<String> collectedLootIds;
  final Map<String, bool> choiceFlags;
  final Map<String, int> values;

  Map<String, Object?> toJson() => <String, Object?>{
    'completedLevelIds': completedLevelIds,
    'defeatedBossIds': defeatedBossIds,
    'activatedCheckpointIds': activatedCheckpointIds,
    'activatedShortcutIds': activatedShortcutIds,
    'completedPuzzleIds': completedPuzzleIds,
    'collectedLootIds': collectedLootIds,
    'choiceFlags': choiceFlags,
    'values': values,
  };

  factory GameSaveProgressionV2.fromJson(Map<String, Object?> json) {
    return GameSaveProgressionV2(
      completedLevelIds: _readStringList(json, 'completedLevelIds'),
      defeatedBossIds: _readStringList(json, 'defeatedBossIds'),
      activatedCheckpointIds: _readStringList(
        json,
        'activatedCheckpointIds',
      ),
      activatedShortcutIds: _readStringList(json, 'activatedShortcutIds'),
      completedPuzzleIds: _readStringList(json, 'completedPuzzleIds'),
      collectedLootIds: _readStringList(json, 'collectedLootIds'),
      choiceFlags: _readBoolMap(json, 'choiceFlags'),
      values: _readIntMap(json, 'values'),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GameSaveProgressionV2 &&
        listEquals(other.completedLevelIds, completedLevelIds) &&
        listEquals(other.defeatedBossIds, defeatedBossIds) &&
        listEquals(other.activatedCheckpointIds, activatedCheckpointIds) &&
        listEquals(other.activatedShortcutIds, activatedShortcutIds) &&
        listEquals(other.completedPuzzleIds, completedPuzzleIds) &&
        listEquals(other.collectedLootIds, collectedLootIds) &&
        mapEquals(other.choiceFlags, choiceFlags) &&
        mapEquals(other.values, values);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(completedLevelIds),
    Object.hashAll(defeatedBossIds),
    Object.hashAll(activatedCheckpointIds),
    Object.hashAll(activatedShortcutIds),
    Object.hashAll(completedPuzzleIds),
    Object.hashAll(collectedLootIds),
    Object.hashAllUnordered(
      choiceFlags.entries.map(
        (MapEntry<String, bool> entry) => Object.hash(entry.key, entry.value),
      ),
    ),
    Object.hashAllUnordered(
      values.entries.map(
        (MapEntry<String, int> entry) => Object.hash(entry.key, entry.value),
      ),
    ),
  );
}

@immutable
class GameSaveLostEchoV2 {
  GameSaveLostEchoV2({
    this.amount = 0,
    required this.levelId,
    List<double> position = const <double>[0, 0, 0],
  }) : position = List<double>.unmodifiable(position) {
    if (amount < 0 || levelId.isEmpty || position.length != 3) {
      throw ArgumentError('Invalid lost echo state.');
    }
  }

  final int amount;
  final String levelId;
  final List<double> position;

  Map<String, Object?> toJson() => <String, Object?>{
    'amount': amount,
    'levelId': levelId,
    'position': position,
  };

  factory GameSaveLostEchoV2.fromJson(Map<String, Object?> json) {
    return GameSaveLostEchoV2(
      amount: _readNonNegativeInt(json, 'amount'),
      levelId: _readNonEmptyString(json, 'levelId'),
      position: _readVector3(json, 'position'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GameSaveLostEchoV2 &&
      other.amount == amount &&
      other.levelId == levelId &&
      listEquals(other.position, position);

  @override
  int get hashCode => Object.hash(amount, levelId, Object.hashAll(position));
}

Map<String, Object?> _readMap(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! Map<String, Object?>) {
    throw FormatException('$key must be an object.');
  }
  return value;
}

num _readNumber(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! num) {
    throw FormatException('$key must be numeric.');
  }
  return value;
}

int _readNonNegativeInt(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! int || value < 0) {
    throw FormatException('$key must be a non-negative integer.');
  }
  return value;
}

String _readNonEmptyString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

List<String> _readStringList(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! List<Object?> ||
      value.any((Object? item) => item is! String || item.isEmpty)) {
    throw FormatException('$key must be a non-empty string ID list.');
  }
  return value.cast<String>();
}

Map<String, int> _readIntMap(Map<String, Object?> json, String key) {
  final Map<String, Object?> value = _readMap(json, key);
  if (value.entries.any(
    (MapEntry<String, Object?> entry) =>
        entry.key.isEmpty || entry.value is! int || (entry.value! as int) < 0,
  )) {
    throw FormatException(
      '$key must map non-empty IDs to non-negative integers.',
    );
  }
  return value.cast<String, int>();
}

Map<String, bool> _readBoolMap(Map<String, Object?> json, String key) {
  final Map<String, Object?> value = _readMap(json, key);
  if (value.entries.any(
    (MapEntry<String, Object?> entry) =>
        entry.key.isEmpty || entry.value is! bool,
  )) {
    throw FormatException('$key must map non-empty IDs to booleans.');
  }
  return value.cast<String, bool>();
}

List<double> _readVector3(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! List<Object?> ||
      value.length != 3 ||
      value.any((Object? item) => item is! num)) {
    throw FormatException('$key must be a three-number list.');
  }
  return value.cast<num>().map((num item) => item.toDouble()).toList();
}
