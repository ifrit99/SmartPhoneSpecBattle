import '../models/character.dart';
import '../models/stats.dart';
import 'character_generator.dart';
import 'enemy_generator.dart';
import '../../data/device_info_service.dart';

/// 戦闘力ティア（強い順）
enum PowerTier { ss, s, a, b, c, d }

extension PowerTierExtension on PowerTier {
  /// ティアの表示ラベル
  String get label {
    return switch (this) {
      PowerTier.ss => 'SS',
      PowerTier.s => 'S',
      PowerTier.a => 'A',
      PowerTier.b => 'B',
      PowerTier.c => 'C',
      PowerTier.d => 'D',
    };
  }

  /// ティアの一言評価（新規プレイヤーが強弱を即座に判断するための文言）
  String get verdict {
    return switch (this) {
      PowerTier.ss => '最強クラス！',
      PowerTier.s => 'かなり強い！',
      PowerTier.a => '強い',
      PowerTier.b => '平均的',
      PowerTier.c => 'やや控えめ',
      PowerTier.d => '伸びしろ十分',
    };
  }
}

/// ランキングの1行分（端末名と戦闘力）
class PowerRankingEntry {
  final String name;
  final int score;
  final bool isPlayer;

  const PowerRankingEntry({
    required this.name,
    required this.score,
    required this.isPlayer,
  });
}

/// 戦闘力の相対評価結果
class PowerRating {
  /// プレイヤー端末（Lv1素体）の戦闘力スコア
  final int score;

  /// 母集団内の順位（1 = 最強）
  final int rank;

  /// プレイヤーを含めた母集団のサイズ
  final int populationSize;

  /// 上位何%か（0.0〜100.0、小さいほど強い）
  final double topPercent;

  final PowerTier tier;

  /// スコア降順のランキング（プレイヤー行を含む）
  final List<PowerRankingEntry> entries;

  /// ローカル推定かどうか（将来サーバーランキング導入時に false にする）
  final bool isEstimated;

  const PowerRating({
    required this.score,
    required this.rank,
    required this.populationSize,
    required this.topPercent,
    required this.tier,
    required this.entries,
    this.isEstimated = true,
  });
}

/// 端末スペック由来の戦闘力を算出し、全登場端末との相対評価を推定するサービス。
///
/// 現在はゲーム内の架空端末カタログ（EnemyGenerator）を母集団とする
/// ローカル推定。将来サーバーランキングを導入する際は、本クラスの
/// [estimate] と同じ [PowerRating] を返す実装に差し替える。
class PowerRatingService {
  /// 戦闘力スコア（編成画面の PWR と同一式）
  static int powerScore(Stats stats) {
    return (stats.maxHp * 0.35 +
            stats.atk * 3.0 +
            stats.def * 2.1 +
            stats.spd * 1.6)
        .round();
  }

  /// プレイヤー端末の Lv1 素体を全登場端末（Lv1 素体）と比較した相対評価。
  ///
  /// レベルや覚醒を含めず端末スペック由来の基礎値同士で比較することで、
  /// 「自分のスマホそのものの強さ」を表す。
  PowerRating estimate(Character player) {
    final playerScore = powerScore(player.baseStats);

    final entries = <PowerRankingEntry>[
      PowerRankingEntry(name: 'あなた', score: playerScore, isPlayer: true),
      for (final device in EnemyGenerator.allEnemyDevices)
        PowerRankingEntry(
          name: device.deviceName,
          score: _deviceScore(device),
          isPlayer: false,
        ),
    ]..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        // 同点はプレイヤーを前に並べ、rank（プレイヤー有利）と表示順を一致させる
        if (a.isPlayer) return -1;
        if (b.isPlayer) return 1;
        return 0;
      });

    // 同点はプレイヤー有利に扱う（自分より高スコアの端末数 + 1 が順位）
    final rank =
        entries.where((e) => !e.isPlayer && e.score > playerScore).length + 1;
    final populationSize = entries.length;
    final topPercent = rank / populationSize * 100;

    return PowerRating(
      score: playerScore,
      rank: rank,
      populationSize: populationSize,
      topPercent: topPercent,
      tier: _tierFor(topPercent),
      entries: entries,
    );
  }

  /// 架空端末の Lv1 素体スコア（プレイヤーと同じ生成パイプラインを使用）
  int _deviceScore(EnemyDeviceSpec device) {
    final specs = DeviceSpecs(
      osVersion: device.osVersion,
      deviceModel: device.deviceName,
      cpuCores: device.cpuCores,
      ramMB: device.ramMB,
      storageFreeGB: device.storageFreeGB,
      batteryLevel: device.batteryLevel,
    );
    return powerScore(CharacterGenerator.generate(specs).baseStats);
  }

  PowerTier _tierFor(double topPercent) {
    if (topPercent <= 12) return PowerTier.ss;
    if (topPercent <= 25) return PowerTier.s;
    if (topPercent <= 50) return PowerTier.a;
    if (topPercent <= 75) return PowerTier.b;
    if (topPercent <= 90) return PowerTier.c;
    return PowerTier.d;
  }
}
