import 'dart:convert';
import 'character.dart';
import 'skill.dart';
import 'stats.dart';
import 'experience.dart';
import '../enums/rarity.dart';
import '../enums/element_type.dart';
import '../data/gacha_device_catalog.dart';
import '../services/character_generator.dart';
import '../../data/device_info_service.dart';

/// ガチャで入手したキャラクター（Characterをcompositionで保持）
class GachaCharacter {
  static const int maxAwakeningLevel = 5;

  final String id;
  final String deviceName;
  final Rarity rarity;
  final DateTime obtainedAt;
  final Character character;
  final int awakeningLevel;

  const GachaCharacter({
    required this.id,
    required this.deviceName,
    required this.rarity,
    required this.obtainedAt,
    required this.character,
    this.awakeningLevel = 0,
  });

  /// EmulatedDeviceSpecからGachaCharacterを生成
  factory GachaCharacter.fromDevice(EmulatedDeviceSpec device) {
    final specs = DeviceSpecs(
      osVersion: device.osVersion,
      deviceModel: device.deviceName,
      cpuCores: device.cpuCores,
      ramMB: device.ramMB,
      storageFreeGB: device.storageFreeGB,
      batteryLevel: device.batteryLevel,
    );

    final baseCharacter = CharacterGenerator.generate(specs);

    // レアリティ補正をステータスに適用
    final multiplier = device.rarity.statMultiplier;
    final bs = baseCharacter.baseStats;
    final boostedStats = Stats(
      hp: (bs.hp * multiplier).round(),
      maxHp: (bs.maxHp * multiplier).round(),
      atk: (bs.atk * multiplier).round(),
      def: (bs.def * multiplier).round(),
      spd: (bs.spd * multiplier).round(),
    );

    final character = baseCharacter.copyWith(
      baseStats: boostedStats,
      currentStats: boostedStats,
    );

    final now = DateTime.now();
    final id = '${device.deviceName.hashCode}_${now.millisecondsSinceEpoch}';

    return GachaCharacter(
      id: id,
      deviceName: device.deviceName,
      rarity: device.rarity,
      obtainedAt: now,
      character: character,
    );
  }

  bool get canAwaken => awakeningLevel < maxAwakeningLevel;
  String get awakeningLabel => awakeningLevel > 0 ? '+$awakeningLevel' : '';

  /// 同一レアリティ・同一端末は重複時に覚醒対象として扱う。
  bool isSameSeries(GachaCharacter other) {
    return deviceName == other.deviceName && rarity == other.rarity;
  }

  /// 重複入手時の覚醒。最大Lv到達後は変化しない。
  GachaCharacter awaken() {
    if (!canAwaken) return this;

    final nextLevel = awakeningLevel + 1;
    final boosted = _boostStats(character.baseStats, 1.06);
    final awakenedCharacter = character.copyWith(
      baseStats: boosted,
      currentStats: boosted.levelUp(character.level),
    );

    return GachaCharacter(
      id: id,
      deviceName: deviceName,
      rarity: rarity,
      obtainedAt: obtainedAt,
      character: awakenedCharacter,
      awakeningLevel: nextLevel,
    );
  }

  /// 経験値を加算した新しいGachaCharacterを返す
  GachaCharacter gainExp(int amount) {
    return GachaCharacter(
      id: id,
      deviceName: deviceName,
      rarity: rarity,
      obtainedAt: obtainedAt,
      character: character.gainExp(amount),
      awakeningLevel: awakeningLevel,
    );
  }

  /// バッテリーレベルを更新
  GachaCharacter withBattery(int batteryLevel) {
    return GachaCharacter(
      id: id,
      deviceName: deviceName,
      rarity: rarity,
      obtainedAt: obtainedAt,
      character: character.copyWith(batteryLevel: batteryLevel),
      awakeningLevel: awakeningLevel,
    );
  }

  static Stats _boostStats(Stats stats, double multiplier) {
    return Stats(
      hp: (stats.hp * multiplier).round(),
      maxHp: (stats.maxHp * multiplier).round(),
      atk: (stats.atk * multiplier).round(),
      def: (stats.def * multiplier).round(),
      spd: (stats.spd * multiplier).round(),
    );
  }

  /// JSON変換（永続化用）
  Map<String, dynamic> toJson() {
    final c = character;
    return {
      'id': id,
      'deviceName': deviceName,
      'rarity': rarity.label,
      'obtainedAt': obtainedAt.toIso8601String(),
      'awakeningLevel': awakeningLevel,
      'name': c.name,
      'element': c.element.name,
      'baseHp': c.baseStats.hp,
      'baseMaxHp': c.baseStats.maxHp,
      'baseAtk': c.baseStats.atk,
      'baseDef': c.baseStats.def,
      'baseSpd': c.baseStats.spd,
      'level': c.experience.level,
      'currentExp': c.experience.currentExp,
      'expToNext': c.experience.expToNext,
      'batteryLevel': c.batteryLevel,
      'seed': c.seed,
      'headIndex': c.headIndex,
      'bodyIndex': c.bodyIndex,
      'armIndex': c.armIndex,
      'legIndex': c.legIndex,
      'colorPaletteIndex': c.colorPaletteIndex,
    };
  }

  /// JSONからGachaCharacterを復元
  factory GachaCharacter.fromJson(Map<String, dynamic> json) {
    final elementValue = json['element'];
    final element = elementValue is int
        ? ElementType.values[elementValue] // 旧データとの後方互換
        : ElementType.values.byName(elementValue as String);
    final experience = Experience(
      level: json['level'] as int,
      currentExp: json['currentExp'] as int,
      expToNext: json['expToNext'] as int,
    );

    final baseStats = Stats(
      hp: json['baseHp'] as int,
      maxHp: json['baseMaxHp'] as int,
      atk: json['baseAtk'] as int,
      def: json['baseDef'] as int,
      spd: json['baseSpd'] as int,
    );

    // Characterのスキルは属性から復元
    final skills = getSkillsForElement(element);

    final character = Character(
      name: json['name'] as String,
      element: element,
      baseStats: baseStats,
      currentStats: baseStats.levelUp(experience.level),
      skills: skills,
      experience: experience,
      batteryLevel: json['batteryLevel'] as int? ?? 50,
      seed: json['seed'] as int,
      headIndex: json['headIndex'] as int,
      bodyIndex: json['bodyIndex'] as int,
      armIndex: json['armIndex'] as int,
      legIndex: json['legIndex'] as int,
      colorPaletteIndex: json['colorPaletteIndex'] as int,
    );

    return GachaCharacter(
      id: json['id'] as String,
      deviceName: json['deviceName'] as String,
      rarity: rarityFromString(json['rarity'] as String),
      obtainedAt: DateTime.parse(json['obtainedAt'] as String),
      character: character,
      awakeningLevel: json['awakeningLevel'] as int? ?? 0,
    );
  }

  /// JSON文字列にシリアライズ
  String toJsonString() => jsonEncode(toJson());

  /// JSON文字列からデシリアライズ
  factory GachaCharacter.fromJsonString(String jsonString) {
    return GachaCharacter.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }
}
