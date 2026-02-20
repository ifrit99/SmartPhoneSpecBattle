import 'dart:math';
import '../models/character.dart';
import '../models/stats.dart';
import '../models/skill.dart';
import '../models/experience.dart';
import '../enums/element_type.dart';
import '../../data/device_info_service.dart';

/// デバイススペックからキャラクターを生成するサービス
class CharacterGenerator {
  /// デバイススペックからシード値を生成
  static int generateSeed(DeviceSpecs specs) {
    // 各スペック値を組み合わせてハッシュを生成
    final combined = '${specs.cpuCores}_${specs.ramMB}_${specs.storageFreeGB}_'
        '${specs.screenWidth.toInt()}_${specs.screenHeight.toInt()}_'
        '${specs.osVersion}';
    return combined.hashCode;
  }

  /// スペックからキャラクターを生成
  static Character generate(DeviceSpecs specs, {Experience? experience}) {
    final seed = generateSeed(specs);
    final random = Random(seed);

    // 属性の決定
    final element = elementFromOsVersion(specs.osVersion);

    // 基礎ステータスの計算
    final baseStats = _calculateBaseStats(specs, random);

    // スキルの取得
    final skills = getSkillsForElement(element);

    // ビジュアルパーツの決定
    final headIndex = random.nextInt(8);
    final bodyIndex = random.nextInt(8);
    final armIndex = random.nextInt(8);
    final legIndex = random.nextInt(8);
    final colorPaletteIndex = random.nextInt(6);

    // キャラクター名の生成
    final name = _generateName(element, seed);

    final exp = experience ?? const Experience();

    return Character(
      name: name,
      element: element,
      baseStats: baseStats,
      currentStats: baseStats.levelUp(exp.level),
      skills: skills,
      experience: exp,
      seed: seed,
      headIndex: headIndex,
      bodyIndex: bodyIndex,
      armIndex: armIndex,
      legIndex: legIndex,
      colorPaletteIndex: colorPaletteIndex,
    );
  }

  /// CPU対戦相手のキャラクターを生成
  static Character generateOpponent(int playerLevel) {
    final random = Random();
    final seed = random.nextInt(999999);

    // ランダムな属性
    final element = ElementType.values[random.nextInt(ElementType.values.length)];

    // プレイヤーレベルに近いステータスで生成（±1レベルの範囲）
    final levelVariance = random.nextInt(3) - 1;
    final opponentLevel = max(1, playerLevel + levelVariance);

    // HPはhpとmaxHpを同一値で初期化
    final baseHp = 80 + random.nextInt(60);

    final baseStats = Stats(
      hp: baseHp,
      maxHp: baseHp,
      atk: 8 + random.nextInt(10),   // 8-17
      def: 8 + random.nextInt(10),   // 8-17
      spd: 8 + random.nextInt(10),   // 8-17
    );

    final skills = getSkillsForElement(element);
    final name = _generateName(element, seed);
    final exp = Experience(level: opponentLevel, currentExp: 0, expToNext: 100);

    return Character(
      name: name,
      element: element,
      baseStats: baseStats,
      currentStats: baseStats.levelUp(opponentLevel),
      skills: skills,
      experience: exp,
      seed: seed,
      headIndex: random.nextInt(8),
      bodyIndex: random.nextInt(8),
      armIndex: random.nextInt(8),
      legIndex: random.nextInt(8),
      colorPaletteIndex: random.nextInt(6),
    );
  }

  /// デバイススペックからベースステータスを計算
  static Stats _calculateBaseStats(DeviceSpecs specs, Random random) {
    // CPU コア数 → 攻撃力 (4コア=10, 8コア=18)
    final atk = (specs.cpuCores * 2 + 2).clamp(8, 25);

    // RAM容量 → HP (2GB=80, 8GB=160)
    final hp = ((specs.ramMB / 1024) * 20 + 40).round().clamp(60, 200);

    // ストレージ空き → 防御力 (16GB=10, 128GB=20)
    final def = ((specs.storageFreeGB / 8) + 6).round().clamp(8, 25);

    // バッテリー残量 → 素早さ (50%=10, 100%=15)
    final spd = ((specs.batteryLevel / 10) + 5).round().clamp(8, 25);

    // 少しランダム要素を追加（±2）
    int variance() => random.nextInt(5) - 2;

    final hpVal = hp + variance();
    return Stats(
      hp: hpVal,
      maxHp: hpVal,
      atk: atk + variance(),
      def: def + variance(),
      spd: spd + variance(),
    );
  }

  /// 属性とシードからキャラクター名を生成
  static String _generateName(ElementType element, int seed) {
    const prefixes = {
      ElementType.fire: ['フレア', 'イグニス', 'ブレイズ', 'バーン'],
      ElementType.water: ['アクア', 'ウェイブ', 'タイダル', 'リップル'],
      ElementType.earth: ['テラ', 'ロック', 'ガイア', 'グランド'],
      ElementType.wind: ['ゼファー', 'ブリーズ', 'ストーム', 'ガスト'],
      ElementType.light: ['ルミナ', 'レイ', 'シャイン', 'グロウ'],
      ElementType.dark: ['シャドウ', 'ノクス', 'ダスク', 'ヴォイド'],
    };
    const suffixes = ['ナイト', 'ガーディアン', 'ウォリアー', 'メイジ',
                      'スピリット', 'ファントム', 'チャンプ', 'キング'];

    final pList = prefixes[element]!;
    final prefix = pList[seed.abs() % pList.length];
    final suffix = suffixes[(seed.abs() ~/ 10) % suffixes.length];
    return '$prefix・$suffix';
  }
}
