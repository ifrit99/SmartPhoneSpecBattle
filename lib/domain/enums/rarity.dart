/// ガチャキャラクターのレアリティ
enum Rarity {
  n,   // ノーマル
  r,   // レア
  sr,  // スーパーレア
  ssr, // スーパースーパーレア
}

extension RarityExtension on Rarity {
  /// レアリティの表示ラベル
  String get label {
    switch (this) {
      case Rarity.n:   return 'N';
      case Rarity.r:   return 'R';
      case Rarity.sr:  return 'SR';
      case Rarity.ssr: return 'SSR';
    }
  }

  /// ステータス補正倍率
  double get statMultiplier {
    switch (this) {
      case Rarity.n:   return 0.8;
      case Rarity.r:   return 1.0;
      case Rarity.sr:  return 1.2;
      case Rarity.ssr: return 1.5;
    }
  }

  /// レアリティのソート用数値（高い方がレア）
  int get sortOrder {
    switch (this) {
      case Rarity.n:   return 0;
      case Rarity.r:   return 1;
      case Rarity.sr:  return 2;
      case Rarity.ssr: return 3;
    }
  }
}

/// 文字列からRarityに変換
Rarity rarityFromString(String value) {
  switch (value.toLowerCase()) {
    case 'n':   return Rarity.n;
    case 'r':   return Rarity.r;
    case 'sr':  return Rarity.sr;
    case 'ssr': return Rarity.ssr;
    default:    return Rarity.n;
  }
}
