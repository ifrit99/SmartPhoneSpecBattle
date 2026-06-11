import '../enums/battle_tactic.dart';
import '../enums/element_type.dart';
import '../models/character.dart';
import 'battle_engine.dart';

/// リザルト画面に表示する勝因・敗因の1項目
class BattleInsightItem {
  final String icon; // 絵文字アイコン
  final String title; // 短い見出し
  final String detail; // 1〜2行の説明

  const BattleInsightItem({
    required this.icon,
    required this.title,
    required this.detail,
  });
}

/// バトル統計から勝因ハイライト／敗北時の対策を導く分析サービス。
///
/// 勝利時は「自分の選択（属性・戦術・支援）がどれだけ効いたか」を定量表示し、
/// 敗北時は「次はどうすれば勝てるか」の具体的な対策を提示する。
class BattleInsightService {
  /// 表示する項目の最大数
  static const int maxItems = 3;

  /// バトル結果を分析し、勝因（勝利時）または対策（敗北時）を返す
  static List<BattleInsightItem> analyze({
    required BattleResult result,
    required Character player,
    required Character enemy,
  }) {
    final items = result.playerWon
        ? _buildHighlights(result, player, enemy)
        : _buildAdvices(result, player, enemy);
    return items.take(maxItems).toList();
  }

  /// 勝利時: 選択の貢献度が大きい順にハイライトを並べる
  static List<BattleInsightItem> _buildHighlights(
    BattleResult result,
    Character player,
    Character enemy,
  ) {
    final stats = result.statistics;
    final items = <BattleInsightItem>[];

    if (stats.elementBonusDamage > 0) {
      items.add(BattleInsightItem(
        icon: '🔥',
        title: '属性アドバンテージ',
        detail: '有利属性の攻撃で与ダメージを +${stats.elementBonusDamage} 上乗せした',
      ));
    }

    if (stats.tacticBonusDamage > 0) {
      items.add(BattleInsightItem(
        icon: '⚙️',
        title: '戦術「${result.playerTactic.label}」が的中',
        detail: '戦術ボーナスで与ダメージを +${stats.tacticBonusDamage} 押し上げた',
      ));
    } else if (stats.tacticGuardedDamage > 0) {
      items.add(BattleInsightItem(
        icon: '🛡️',
        title: '戦術「${result.playerTactic.label}」で堅守',
        detail: '戦術の防御補正で被ダメージを ${stats.tacticGuardedDamage} 軽減した',
      ));
    }

    if (result.supportCommand == BattleSupportCommand.barrier &&
        stats.supportHealing > 0) {
      items.add(BattleInsightItem(
        icon: '💠',
        title: '防御支援で粘り勝ち',
        detail: '支援のリジェネで合計 ${stats.supportHealing} 回復して攻撃を凌いだ',
      ));
    } else if (result.supportCommand == BattleSupportCommand.overdrive) {
      items.add(const BattleInsightItem(
        icon: '⚡',
        title: '攻撃支援が加速',
        detail: '開幕の攻撃力・素早さ強化で序盤の主導権を握った',
      ));
    }

    if (stats.playerSkillCount > 0 &&
        stats.playerDamageDealt > 0 &&
        stats.playerSkillDamage >= stats.playerDamageDealt * 0.4) {
      final ratio =
          (stats.playerSkillDamage / stats.playerDamageDealt * 100).round();
      items.add(BattleInsightItem(
        icon: '✨',
        title: 'スキルが主役',
        detail: 'スキル${stats.playerSkillCount}回で総ダメージの $ratio% を叩き出した',
      ));
    }

    if (stats.playerCriticalHits >= 2) {
      items.add(BattleInsightItem(
        icon: '💥',
        title: 'クリティカル ×${stats.playerCriticalHits}',
        detail: '素早さと相性を活かした会心の一撃が流れを引き寄せた',
      ));
    }

    if (items.isEmpty) {
      items.add(BattleInsightItem(
        icon: '🏆',
        title: '地力で押し切った',
        detail: '${result.turnsPlayed}ターンの安定勝利。基礎スペックが相手を上回っている',
      ));
    }
    return items;
  }

  /// 敗北時: 次に繋がる具体的な対策を優先度順に並べる
  static List<BattleInsightItem> _buildAdvices(
    BattleResult result,
    Character player,
    Character enemy,
  ) {
    final stats = result.statistics;
    final items = <BattleInsightItem>[];
    final enemyMaxHp = enemy.battleStats.maxHp;

    // 惜敗: 相手の残HPが2割以下なら、あと一押しを伝える
    if (enemyMaxHp > 0 && result.finalEnemyHp <= enemyMaxHp * 0.2) {
      items.add(BattleInsightItem(
        icon: '🔥',
        title: 'あと一歩だった',
        detail: '相手の残りHPはわずか ${result.finalEnemyHp}。'
            '与ダメージ+15%の「オーバークロック」なら届く可能性が高い',
      ));
    }

    // 属性不利: 有利を取れる属性を具体的に提案する
    final playerMult = player.element.multiplierAgainst(enemy.element);
    final enemyMult = enemy.element.multiplierAgainst(player.element);
    if (playerMult < 1.0 || enemyMult > 1.0) {
      final counter = ElementType.values.firstWhere(
        (e) => e.multiplierAgainst(enemy.element) > 1.0,
      );
      final penalty = stats.elementPenaltyDamage + stats.enemyElementBonusDamage;
      items.add(BattleInsightItem(
        icon: '🧭',
        title: '属性相性を見直そう',
        detail: '相手は${enemy.element.label}属性。${counter.label}属性なら与ダメージ1.5倍を狙える'
            '${penalty > 0 ? '（今回は相性で $penalty 損していた）' : ''}',
      ));
    }

    // 火力不足 or 被ダメ過多: バトルの形に応じて戦術を提案する
    if (enemyMaxHp > 0 && result.finalEnemyHp >= enemyMaxHp * 0.5) {
      items.add(const BattleInsightItem(
        icon: '⚔️',
        title: '火力が足りていない',
        detail: '相手のHPを半分も削れなかった。'
            '「オーバークロック」やスキル重視の「バースト」で火力を底上げしよう',
      ));
    } else if (stats.enemyDamageDealt > 0 &&
        stats.enemyDamageDealt >= stats.playerDamageDealt * 1.25) {
      items.add(BattleInsightItem(
        icon: '🛡️',
        title: '被ダメージが多すぎた',
        detail: result.playerTactic == BattleTactic.firewall
            ? '防御支援（バリア）を併用すれば防御+35%とリジェネでさらに粘れる'
            : '「ファイアウォール」戦術＋防御支援で被ダメージを大きく抑えられる',
      ));
    }

    // レベル差: 育成導線を示す
    final levelGap = enemy.level - player.level;
    if (levelGap >= 2) {
      items.add(BattleInsightItem(
        icon: '📈',
        title: 'レベル差を埋めよう',
        detail: 'レベル差が $levelGap。EASY周回やデイリーミッションで経験値を稼いでから再挑戦しよう',
      ));
    }

    // 支援未使用: 無料の支援コマンドを案内する
    if (result.supportCommand == BattleSupportCommand.none) {
      items.add(const BattleInsightItem(
        icon: '🎁',
        title: '支援コマンドを活用しよう',
        detail: 'バトル開始時に無料で選べる攻撃支援／防御支援が未使用だった',
      ));
    }

    if (items.isEmpty) {
      items.add(const BattleInsightItem(
        icon: '🔁',
        title: '戦術を変えて再挑戦',
        detail: '同じ相手でも戦術と支援の組み合わせ次第で結果は変わる',
      ));
    }
    return items;
  }
}
