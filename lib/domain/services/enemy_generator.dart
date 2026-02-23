import 'dart:math';
import '../models/character.dart';
import '../models/experience.dart';
import 'character_generator.dart';
import '../../data/device_info_service.dart';

/// 敵の難易度
enum EnemyDifficulty {
  easy,   // 弱い（古い端末）
  normal, // 普通（標準的な端末）
  hard,   // 強い（ハイエンド端末）
  boss,   // 最強（最新フラッグシップ）
}

extension EnemyDifficultyExtension on EnemyDifficulty {
  /// 難易度の日本語ラベル
  String get label {
    switch (this) {
      case EnemyDifficulty.easy:   return 'EASY';
      case EnemyDifficulty.normal: return 'NORMAL';
      case EnemyDifficulty.hard:   return 'HARD';
      case EnemyDifficulty.boss:   return 'BOSS';
    }
  }

  /// 難易度に対応したレベル補正（プレイヤーレベルへの加算値）
  int levelOffset(Random random) {
    switch (this) {
      case EnemyDifficulty.easy:   return -(1 + random.nextInt(2)); // -1 〜 -2
      case EnemyDifficulty.normal: return random.nextInt(3) - 1;    // -1 〜 +1
      case EnemyDifficulty.hard:   return 1 + random.nextInt(3);    // +1 〜 +3
      case EnemyDifficulty.boss:   return 3 + random.nextInt(3);    // +3 〜 +5
    }
  }
}

/// 架空デバイスの仕様（敵のフレーバー情報）
class EnemyDeviceSpec {
  final String deviceName;   // 端末名（例: "Galaxy S8"）
  final String osLabel;      // OS表示（例: "Android 8.0"）
  final String osVersion;    // 属性決定に使うバージョン文字列
  final int cpuCores;        // CPUコア数 → ATK に影響
  final int ramMB;           // RAM容量 → HP に影響
  final int storageFreeGB;   // ストレージ空き → DEF に影響
  final int batteryLevel;    // バッテリー残量 → SPD に影響
  final EnemyDifficulty difficulty;

  const EnemyDeviceSpec({
    required this.deviceName,
    required this.osLabel,
    required this.osVersion,
    required this.cpuCores,
    required this.ramMB,
    required this.storageFreeGB,
    required this.batteryLevel,
    required this.difficulty,
  });
}

/// 難易度ごとの架空デバイスカタログ
const _easyDevices = [
  EnemyDeviceSpec(
    deviceName: 'Galaxy J2 Prime',
    osLabel: 'Android 6.0',
    osVersion: '6',
    cpuCores: 4, ramMB: 1536, storageFreeGB: 8, batteryLevel: 40,
    difficulty: EnemyDifficulty.easy,
  ),
  EnemyDeviceSpec(
    deviceName: 'Redmi 4A',
    osLabel: 'Android 6.0',
    osVersion: '6',
    cpuCores: 4, ramMB: 2048, storageFreeGB: 8, batteryLevel: 30,
    difficulty: EnemyDifficulty.easy,
  ),
  EnemyDeviceSpec(
    deviceName: 'AQUOS sense2',
    osLabel: 'Android 8.1',
    osVersion: '8',
    cpuCores: 4, ramMB: 3072, storageFreeGB: 12, batteryLevel: 50,
    difficulty: EnemyDifficulty.easy,
  ),
  EnemyDeviceSpec(
    deviceName: 'iPhone 6s',
    osLabel: 'iOS 12.5',
    osVersion: '12',
    cpuCores: 2, ramMB: 2048, storageFreeGB: 10, batteryLevel: 45,
    difficulty: EnemyDifficulty.easy,
  ),
];

const _normalDevices = [
  EnemyDeviceSpec(
    deviceName: 'Pixel 5a',
    osLabel: 'Android 12.0',
    osVersion: '12',
    cpuCores: 8, ramMB: 6144, storageFreeGB: 48, batteryLevel: 70,
    difficulty: EnemyDifficulty.normal,
  ),
  EnemyDeviceSpec(
    deviceName: 'Galaxy A54',
    osLabel: 'Android 13.0',
    osVersion: '13',
    cpuCores: 8, ramMB: 8192, storageFreeGB: 64, batteryLevel: 65,
    difficulty: EnemyDifficulty.normal,
  ),
  EnemyDeviceSpec(
    deviceName: 'iPhone 13',
    osLabel: 'iOS 16.0',
    osVersion: '16',
    cpuCores: 6, ramMB: 4096, storageFreeGB: 50, batteryLevel: 75,
    difficulty: EnemyDifficulty.normal,
  ),
  EnemyDeviceSpec(
    deviceName: 'Xperia 10 V',
    osLabel: 'Android 13.0',
    osVersion: '13',
    cpuCores: 8, ramMB: 6144, storageFreeGB: 56, batteryLevel: 60,
    difficulty: EnemyDifficulty.normal,
  ),
];

const _hardDevices = [
  EnemyDeviceSpec(
    deviceName: 'Galaxy S24',
    osLabel: 'Android 14.0',
    osVersion: '14',
    cpuCores: 8, ramMB: 8192, storageFreeGB: 128, batteryLevel: 85,
    difficulty: EnemyDifficulty.hard,
  ),
  EnemyDeviceSpec(
    deviceName: 'Pixel 9 Pro',
    osLabel: 'Android 15.0',
    osVersion: '15',
    cpuCores: 9, ramMB: 16384, storageFreeGB: 180, batteryLevel: 90,
    difficulty: EnemyDifficulty.hard,
  ),
  EnemyDeviceSpec(
    deviceName: 'iPhone 16 Pro',
    osLabel: 'iOS 18.0',
    osVersion: '18',
    cpuCores: 6, ramMB: 8192, storageFreeGB: 200, batteryLevel: 88,
    difficulty: EnemyDifficulty.hard,
  ),
  EnemyDeviceSpec(
    deviceName: 'Xperia 1 VI',
    osLabel: 'Android 14.0',
    osVersion: '14',
    cpuCores: 8, ramMB: 12288, storageFreeGB: 150, batteryLevel: 80,
    difficulty: EnemyDifficulty.hard,
  ),
];

const _bossDevices = [
  EnemyDeviceSpec(
    deviceName: 'Galaxy S24 Ultra',
    osLabel: 'Android 15.0',
    osVersion: '15',
    cpuCores: 12, ramMB: 16384, storageFreeGB: 512, batteryLevel: 100,
    difficulty: EnemyDifficulty.boss,
  ),
  EnemyDeviceSpec(
    deviceName: 'iPhone 16 Pro Max',
    osLabel: 'iOS 18.2',
    osVersion: '18',
    cpuCores: 6, ramMB: 8192, storageFreeGB: 512, batteryLevel: 100,
    difficulty: EnemyDifficulty.boss,
  ),
  EnemyDeviceSpec(
    deviceName: 'Pixel 9 Pro XL',
    osLabel: 'Android 15.0',
    osVersion: '15',
    cpuCores: 9, ramMB: 16384, storageFreeGB: 512, batteryLevel: 100,
    difficulty: EnemyDifficulty.boss,
  ),
  EnemyDeviceSpec(
    deviceName: 'ROG Phone 9 Pro',
    osLabel: 'Android 15.0',
    osVersion: '15',
    cpuCores: 12, ramMB: 24576, storageFreeGB: 512, batteryLevel: 100,
    difficulty: EnemyDifficulty.boss,
  ),
];

/// 敵生成の結果（キャラクター＋フレーバー情報のセット）
class EnemyProfile {
  final Character character;
  final EnemyDeviceSpec deviceSpec;

  const EnemyProfile({
    required this.character,
    required this.deviceSpec,
  });
}

/// 架空のデバイススペックをもとに敵キャラクターを生成するサービス
class EnemyGenerator {
  static final Random _random = Random();

  /// 難易度とプレイヤーレベルをもとに敵を生成する
  static EnemyProfile generate({
    required EnemyDifficulty difficulty,
    required int playerLevel,
  }) {
    // 難易度に対応したデバイスカタログから1体をランダム選択
    final catalog = _catalogFor(difficulty);
    final deviceSpec = catalog[_random.nextInt(catalog.length)];

    // 架空スペックを DeviceSpecs に変換
    final specs = DeviceSpecs(
      osVersion: deviceSpec.osVersion,
      deviceModel: deviceSpec.deviceName,
      cpuCores: deviceSpec.cpuCores,
      ramMB: deviceSpec.ramMB,
      storageFreeGB: deviceSpec.storageFreeGB,
      batteryLevel: deviceSpec.batteryLevel,
    );

    // プレイヤーレベルに難易度補正を加えた敵レベルを決定
    final levelOffset = difficulty.levelOffset(_random);
    final enemyLevel = max(1, playerLevel + levelOffset);
    final experience = Experience(
      level: enemyLevel,
      currentExp: 0,
      expToNext: 100,
    );

    // CharacterGenerator で実際のキャラクターを生成（プレイヤーと同じパイプライン）
    final character = CharacterGenerator.generate(specs, experience: experience);

    return EnemyProfile(character: character, deviceSpec: deviceSpec);
  }

  /// ランダムな難易度で生成する（ノーマル寄りの確率分布）
  static EnemyProfile generateRandom({required int playerLevel}) {
    // easy:20%, normal:50%, hard:25%, boss:5%
    final roll = _random.nextDouble();
    final EnemyDifficulty difficulty;
    if (roll < 0.20) {
      difficulty = EnemyDifficulty.easy;
    } else if (roll < 0.70) {
      difficulty = EnemyDifficulty.normal;
    } else if (roll < 0.95) {
      difficulty = EnemyDifficulty.hard;
    } else {
      difficulty = EnemyDifficulty.boss;
    }
    return generate(difficulty: difficulty, playerLevel: playerLevel);
  }

  static List<EnemyDeviceSpec> _catalogFor(EnemyDifficulty difficulty) {
    switch (difficulty) {
      case EnemyDifficulty.easy:   return _easyDevices;
      case EnemyDifficulty.normal: return _normalDevices;
      case EnemyDifficulty.hard:   return _hardDevices;
      case EnemyDifficulty.boss:   return _bossDevices;
    }
  }

  /// 全ての難易度の架空デバイスカタログを統合して取得する（図鑑用）
  static List<EnemyDeviceSpec> get allEnemyDevices {
    return [
      ..._easyDevices,
      ..._normalDevices,
      ..._hardDevices,
      ..._bossDevices,
    ];
  }
}
