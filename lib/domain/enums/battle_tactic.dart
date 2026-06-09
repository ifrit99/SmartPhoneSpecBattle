/// バトル前に選択するプレイヤー戦術。
enum BattleTactic {
  balanced,
  overclock,
  firewall,
  burst,
}

extension BattleTacticExtension on BattleTactic {
  String get label {
    switch (this) {
      case BattleTactic.balanced:
        return 'バランス';
      case BattleTactic.overclock:
        return 'オーバークロック';
      case BattleTactic.firewall:
        return 'ファイアウォール';
      case BattleTactic.burst:
        return 'バースト';
    }
  }

  String get description {
    switch (this) {
      case BattleTactic.balanced:
        return '標準的な行動で安定して戦う';
      case BattleTactic.overclock:
        return '攻撃重視。与ダメージ増、被ダメージ増';
      case BattleTactic.firewall:
        return '防御重視。被ダメージ減、与ダメージ少し減';
      case BattleTactic.burst:
        return 'スキル重視。スキル使用率増、被ダメージ少し増';
    }
  }

  double get rewardMultiplier {
    switch (this) {
      case BattleTactic.balanced:
      case BattleTactic.firewall:
        return 1.0;
      case BattleTactic.overclock:
        return 1.2;
      case BattleTactic.burst:
        return 1.1;
    }
  }

  double get outgoingDamageMultiplier {
    switch (this) {
      case BattleTactic.balanced:
      case BattleTactic.burst:
        return 1.0;
      case BattleTactic.overclock:
        return 1.15;
      case BattleTactic.firewall:
        return 0.95;
    }
  }

  double get incomingDamageMultiplier {
    switch (this) {
      case BattleTactic.balanced:
        return 1.0;
      case BattleTactic.overclock:
        return 1.1;
      case BattleTactic.firewall:
        return 0.9;
      case BattleTactic.burst:
        return 1.05;
    }
  }

  double get lowHpDefendChance {
    switch (this) {
      case BattleTactic.balanced:
        return 0.4;
      case BattleTactic.overclock:
        return 0.2;
      case BattleTactic.firewall:
        return 0.6;
      case BattleTactic.burst:
        return 0.3;
    }
  }

  double get skillChance {
    switch (this) {
      case BattleTactic.balanced:
        return 0.45;
      case BattleTactic.overclock:
        return 0.5;
      case BattleTactic.firewall:
        return 0.35;
      case BattleTactic.burst:
        return 0.7;
    }
  }

  double get defendChance {
    switch (this) {
      case BattleTactic.balanced:
        return 0.15;
      case BattleTactic.overclock:
        return 0.05;
      case BattleTactic.firewall:
        return 0.25;
      case BattleTactic.burst:
        return 0.1;
    }
  }

  bool get hasRewardBonus => rewardMultiplier > 1.0;
}
