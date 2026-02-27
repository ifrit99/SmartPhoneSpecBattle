import 'dart:math';
import '../enums/rarity.dart';
import '../data/gacha_device_catalog.dart';
import '../models/gacha_character.dart';
import '../models/player_currency.dart';
import 'currency_service.dart';
import '../../data/local_storage_service.dart';

/// ガチャ結果を表すクラス
class GachaResult {
  final List<GachaCharacter> characters;
  final PlayerCurrency updatedCurrency;

  const GachaResult({
    required this.characters,
    required this.updatedCurrency,
  });

  bool get hasSR => characters.any((c) => c.rarity == Rarity.sr || c.rarity == Rarity.ssr);
  bool get hasSSR => characters.any((c) => c.rarity == Rarity.ssr);
}

/// ガチャの排出確率テーブル
class GachaProbabilityTable {
  /// 各レアリティの排出確率（パーセント）
  /// N: 60%, R: 25%, SR: 10%, SSR: 5%
  static const Map<Rarity, int> rates = {
    Rarity.n: 60,
    Rarity.r: 25,
    Rarity.sr: 10,
    Rarity.ssr: 5,
  };

  /// 確率テーブルに基づいてレアリティを抽選する
  static Rarity draw(Random random) {
    final roll = random.nextInt(100);
    if (roll < rates[Rarity.ssr]!) return Rarity.ssr;
    if (roll < rates[Rarity.ssr]! + rates[Rarity.sr]!) return Rarity.sr;
    if (roll < rates[Rarity.ssr]! + rates[Rarity.sr]! + rates[Rarity.r]!) return Rarity.r;
    return Rarity.n;
  }
}

/// ガチャシステムのサービスクラス
///
/// 排出確率テーブルに基づくレアリティ抽選、通貨消費、
/// インベントリ永続化を統合的に管理する。
class GachaService {
  final CurrencyService _currencyService;
  final LocalStorageService _storage;
  final Random _random;

  GachaService(this._currencyService, this._storage, [Random? random])
      : _random = random ?? Random();

  /// 単発ガチャ（100コイン）
  ///
  /// 通貨不足の場合は null を返す。
  Future<GachaResult?> pullSingle() async {
    final currency = _currencyService.load();
    if (!currency.canAffordSingle()) return null;

    final updated = await _currencyService.spendCoins(PlayerCurrency.singlePullCost);
    if (updated == null) return null;

    final character = _drawOne();
    await _saveToRoster([character]);

    return GachaResult(characters: [character], updatedCurrency: updated);
  }

  /// 10連ガチャ（900コイン、SR以上1枚保証）
  ///
  /// 通貨不足の場合は null を返す。
  Future<GachaResult?> pullTen() async {
    final currency = _currencyService.load();
    if (!currency.canAffordTenPull()) return null;

    final updated = await _currencyService.spendCoins(PlayerCurrency.tenPullCost);
    if (updated == null) return null;

    final characters = <GachaCharacter>[];

    // 最初の9枚は通常抽選
    for (int i = 0; i < 9; i++) {
      characters.add(_drawOne());
    }

    // 10枚目はSR以上保証
    final hasSROrAbove = characters.any(
      (c) => c.rarity == Rarity.sr || c.rarity == Rarity.ssr,
    );

    if (hasSROrAbove) {
      characters.add(_drawOne());
    } else {
      characters.add(_drawOneGuaranteed());
    }

    await _saveToRoster(characters);

    return GachaResult(characters: characters, updatedCurrency: updated);
  }

  /// 通常抽選で1体を引く
  GachaCharacter _drawOne() {
    final rarity = GachaProbabilityTable.draw(_random);
    return _pickDevice(rarity);
  }

  /// SR以上保証枠で1体を引く
  GachaCharacter _drawOneGuaranteed() {
    // SR:67%, SSR:33% の比率で抽選
    final roll = _random.nextInt(3);
    final rarity = roll == 0 ? Rarity.ssr : Rarity.sr;
    return _pickDevice(rarity);
  }

  /// 指定レアリティの端末からランダムに1体を選んでGachaCharacterを生成
  GachaCharacter _pickDevice(Rarity rarity) {
    final candidates = gachaDevicesByRarity(rarity);
    final device = candidates[_random.nextInt(candidates.length)];
    return GachaCharacter.fromDevice(device);
  }

  /// インベントリにキャラクターを追加保存
  Future<void> _saveToRoster(List<GachaCharacter> newCharacters) async {
    final current = List<String>.from(_storage.getGachaCharacters());
    for (final c in newCharacters) {
      current.add(c.toJsonString());
    }
    await _storage.saveGachaCharacters(current);
  }

  /// インベントリからガチャキャラクター一覧を取得
  List<GachaCharacter> loadRoster() {
    final jsonList = _storage.getGachaCharacters();
    return jsonList.map((s) => GachaCharacter.fromJsonString(s)).toList();
  }

  /// インベントリからキャラクターをIDで検索
  GachaCharacter? findById(String id) {
    final roster = loadRoster();
    for (final c in roster) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// インベントリ内のキャラクターを更新（経験値加算等）
  Future<void> updateCharacter(GachaCharacter updated) async {
    final roster = loadRoster();
    final index = roster.indexWhere((c) => c.id == updated.id);
    if (index < 0) return;
    roster[index] = updated;
    await _storage.saveGachaCharacters(
      roster.map((c) => c.toJsonString()).toList(),
    );
  }

  /// 装備中のガチャキャラクターIDを設定
  Future<void> equipCharacter(String? id) async {
    await _storage.saveEquippedGachaCharacterId(id);
  }

  /// 装備中のガチャキャラクターを取得
  GachaCharacter? getEquippedCharacter() {
    final id = _storage.getEquippedGachaCharacterId();
    if (id == null) return null;
    return findById(id);
  }

  /// 現在のコインで何回引けるか
  int affordableSinglePulls() {
    return _currencyService.load().coins ~/ PlayerCurrency.singlePullCost;
  }

  /// 10連ガチャが引けるか
  bool canAffordTenPull() {
    return _currencyService.load().canAffordTenPull();
  }
}
