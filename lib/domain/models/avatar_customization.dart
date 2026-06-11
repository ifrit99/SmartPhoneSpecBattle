import 'character.dart';

/// プレイヤーが選択した見た目カスタマイズ
///
/// 各スロットは [unset]（-1 = おまかせ）の場合、キャラクター本来の
/// 見た目（シード生成 or ガチャキャラの見た目）をそのまま使う。
class AvatarCustomization {
  /// 「おまかせ」を表す値（元の見た目を維持）
  static const int unset = -1;

  /// 各スロットの選択肢数（PixelCharacter の描画バリエーションと同期）
  static const int headVariations = 8;
  static const int bodyVariations = 6;
  static const int armVariations = 5;
  static const int legVariations = 5;
  static const int paletteVariations = 12;
  static const int accessoryVariations = 8; // 0 = なし
  static const int auraVariations = 6; // 0 = なし

  final int headIndex;
  final int bodyIndex;
  final int armIndex;
  final int legIndex;
  final int colorPaletteIndex;
  final int accessoryIndex;
  final int auraIndex;

  const AvatarCustomization({
    this.headIndex = unset,
    this.bodyIndex = unset,
    this.armIndex = unset,
    this.legIndex = unset,
    this.colorPaletteIndex = unset,
    this.accessoryIndex = unset,
    this.auraIndex = unset,
  });

  /// 全スロットがおまかせ（カスタマイズ未設定）かどうか
  bool get isEmpty =>
      headIndex == unset &&
      bodyIndex == unset &&
      armIndex == unset &&
      legIndex == unset &&
      colorPaletteIndex == unset &&
      accessoryIndex == unset &&
      auraIndex == unset;

  /// 設定済みスロット数
  int get customizedCount => [
        headIndex,
        bodyIndex,
        armIndex,
        legIndex,
        colorPaletteIndex,
        accessoryIndex,
        auraIndex,
      ].where((v) => v != unset).length;

  /// キャラクターに適用する（おまかせスロットは元の値を維持）
  Character applyTo(Character character) {
    if (isEmpty) return character;
    return character.copyWith(
      headIndex: headIndex == unset ? null : headIndex,
      bodyIndex: bodyIndex == unset ? null : bodyIndex,
      armIndex: armIndex == unset ? null : armIndex,
      legIndex: legIndex == unset ? null : legIndex,
      colorPaletteIndex: colorPaletteIndex == unset ? null : colorPaletteIndex,
      accessoryIndex: accessoryIndex == unset ? null : accessoryIndex,
      auraIndex: auraIndex == unset ? null : auraIndex,
    );
  }

  /// 永続化用のカンマ区切り文字列（head,body,arm,leg,palette,accessory,aura）
  String toStorageString() => [
        headIndex,
        bodyIndex,
        armIndex,
        legIndex,
        colorPaletteIndex,
        accessoryIndex,
        auraIndex,
      ].join(',');

  /// 永続化文字列から復元（null・不正値は全ておまかせ扱い）
  factory AvatarCustomization.fromStorageString(String? raw) {
    if (raw == null || raw.isEmpty) return const AvatarCustomization();
    final parts = raw.split(',');
    if (parts.length != 7) return const AvatarCustomization();
    final values = parts.map((v) => int.tryParse(v) ?? unset).toList();
    return AvatarCustomization(
      headIndex: values[0],
      bodyIndex: values[1],
      armIndex: values[2],
      legIndex: values[3],
      colorPaletteIndex: values[4],
      accessoryIndex: values[5],
      auraIndex: values[6],
    );
  }

  AvatarCustomization copyWith({
    int? headIndex,
    int? bodyIndex,
    int? armIndex,
    int? legIndex,
    int? colorPaletteIndex,
    int? accessoryIndex,
    int? auraIndex,
  }) {
    return AvatarCustomization(
      headIndex: headIndex ?? this.headIndex,
      bodyIndex: bodyIndex ?? this.bodyIndex,
      armIndex: armIndex ?? this.armIndex,
      legIndex: legIndex ?? this.legIndex,
      colorPaletteIndex: colorPaletteIndex ?? this.colorPaletteIndex,
      accessoryIndex: accessoryIndex ?? this.accessoryIndex,
      auraIndex: auraIndex ?? this.auraIndex,
    );
  }
}
