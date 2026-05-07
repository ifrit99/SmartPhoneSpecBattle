import 'dart:math';
import '../enums/rarity.dart';
import '../data/gacha_device_catalog.dart';
import '../models/gacha_character.dart';
import '../models/player_currency.dart';
import 'currency_service.dart';
import 'daily_mission_service.dart';
import '../../data/local_storage_service.dart';

/// ガチャ結果を表すクラス
class GachaResult {
  final List<GachaCharacter> characters;
  final PlayerCurrency updatedCurrency;
  final int duplicateUpgrades;
  final int duplicateRefundCoins;

  const GachaResult({
    required this.characters,
    required this.updatedCurrency,
    this.duplicateUpgrades = 0,
    this.duplicateRefundCoins = 0,
  });

  bool get hasSR =>
      characters.any((c) => c.rarity == Rarity.sr || c.rarity == Rarity.ssr);
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
    if (roll < rates[Rarity.ssr]! + rates[Rarity.sr]! + rates[Rarity.r]!)
      return Rarity.r;
    return Rarity.n;
  }
}

/// ガチャシステムのサービスクラス
///
/// 排出確率テーブルに基づくレアリティ抽選、通貨消費、
/// インベントリ永続化を統合的に管理する。
class GachaService {
  static const int premiumFeaturedPityThreshold = 6;
  static const int eventLimitedPityThreshold = 4;

  final CurrencyService _currencyService;
  final LocalStorageService _storage;
  final Random _random;
  final DailyMissionService? _dailyMissionService;
  final DateTime Function() _now;

  GachaService(
    this._currencyService,
    this._storage, [
    Object? dailyMissionServiceOrRandom,
    Random? random,
    DateTime Function()? now,
  ])  : _dailyMissionService =
            dailyMissionServiceOrRandom is DailyMissionService
                ? dailyMissionServiceOrRandom
                : null,
        _random = (dailyMissionServiceOrRandom is Random
                ? dailyMissionServiceOrRandom
                : random) ??
            Random(),
        _now = now ?? DateTime.now;

  static int duplicateRefundCoinsFor(Rarity rarity) {
    return switch (rarity) {
      Rarity.n => 25,
      Rarity.r => 45,
      Rarity.sr => 100,
      Rarity.ssr => 180,
    };
  }

  static EmulatedDeviceSpec featuredSsrDevice({DateTime? date}) {
    final targetDate = date ?? DateTime.now();
    final ssrDevices = gachaDevicesByRarity(Rarity.ssr);
    final dayIndex = targetDate.difference(DateTime(2026, 1, 1)).inDays.abs();
    return ssrDevices[dayIndex % ssrDevices.length];
  }

  EmulatedDeviceSpec get todayFeaturedSsr => featuredSsrDevice(date: _now());

  static EmulatedDeviceSpec eventLimitedSsrDevice({DateTime? date}) {
    final targetDate = date ?? DateTime.now();
    final dayIndex = targetDate.difference(DateTime(2026, 1, 1)).inDays.abs();
    final weekIndex = dayIndex ~/ 7;
    return eventLimitedDeviceCatalog[
        weekIndex % eventLimitedDeviceCatalog.length];
  }

  EmulatedDeviceSpec get currentEventLimitedSsr =>
      eventLimitedSsrDevice(date: _now());

  int get premiumFeaturedMisses => _storage.getPremiumFeaturedMisses();

  int get eventLimitedMisses => _storage.getEventLimitedMisses();

  int get premiumFeaturedPullsUntilGuarantee {
    final misses = premiumFeaturedMisses.clamp(
      0,
      premiumFeaturedPityThreshold - 1,
    );
    return premiumFeaturedPityThreshold - misses.toInt();
  }

  bool get isNextPremiumFeaturedGuaranteed =>
      premiumFeaturedMisses >= premiumFeaturedPityThreshold - 1;

  int get eventLimitedPullsUntilGuarantee {
    final misses = eventLimitedMisses.clamp(
      0,
      eventLimitedPityThreshold - 1,
    );
    return eventLimitedPityThreshold - misses.toInt();
  }

  bool get isNextEventLimitedGuaranteed =>
      eventLimitedMisses >= eventLimitedPityThreshold - 1;

  /// 単発ガチャ（100コイン）
  ///
  /// 通貨不足の場合は null を返す。
  Future<GachaResult?> pullSingle() async {
    final currency = _currencyService.load();
    if (!currency.canAffordSingle()) return null;

    final updated =
        await _currencyService.spendCoins(PlayerCurrency.singlePullCost);
    if (updated == null) return null;

    final saved = await _saveToRoster([_drawOne()]);
    await _dailyMissionService?.recordGachaPulls(1);

    return _buildResult(saved, updated);
  }

  /// 10連ガチャ（900コイン、SR以上1枚保証）
  ///
  /// 通貨不足の場合は null を返す。
  Future<GachaResult?> pullTen() async {
    final currency = _currencyService.load();
    if (!currency.canAffordTenPull()) return null;

    final updated =
        await _currencyService.spendCoins(PlayerCurrency.tenPullCost);
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

    final saved = await _saveToRoster(characters);
    await _dailyMissionService?.recordGachaPulls(characters.length);

    return _buildResult(saved, updated);
  }

  /// プレミアム解析ガチャ（20ジェム、SR以上確定）
  ///
  /// デイリー報酬で得たジェムの使い道。通貨不足の場合は null を返す。
  Future<GachaResult?> pullPremium() async {
    final currency = _currencyService.load();
    if (!currency.canAffordPremiumPull()) return null;

    final updated =
        await _currencyService.spendGems(PlayerCurrency.premiumPullCost);
    if (updated == null) return null;

    final character = _drawOnePremium();
    await _updatePremiumFeaturedPity(character);
    final saved = await _saveToRoster([character]);
    await _dailyMissionService?.recordGachaPulls(1);

    return _buildResult(saved, updated);
  }

  /// 期間限定イベント解析（30ジェム、SR以上確定、限定SSRあり）
  Future<GachaResult?> pullEventLimited() async {
    final currency = _currencyService.load();
    if (!currency.canAffordEventLimitedPull()) return null;

    final updated =
        await _currencyService.spendGems(PlayerCurrency.eventLimitedPullCost);
    if (updated == null) return null;

    final character = _drawOneEventLimited();
    await _updateEventLimitedPity(character);
    final saved = await _saveToRoster([character]);
    await _dailyMissionService?.recordGachaPulls(1);

    return _buildResult(saved, updated);
  }

  Future<GachaResult> _buildResult(
    _RosterSaveResult saved,
    PlayerCurrency currencyAfterSpend,
  ) async {
    final updatedCurrency = saved.duplicateRefundCoins > 0
        ? await _currencyService.addCoins(saved.duplicateRefundCoins)
        : currencyAfterSpend;

    return GachaResult(
      characters: saved.characters,
      updatedCurrency: updatedCurrency,
      duplicateUpgrades: saved.duplicateUpgrades,
      duplicateRefundCoins: saved.duplicateRefundCoins,
    );
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

  GachaCharacter _drawOnePremium() {
    if (isNextPremiumFeaturedGuaranteed) {
      return GachaCharacter.fromDevice(todayFeaturedSsr);
    }

    // SSRを引けた場合、60%で日替わりピックアップSSRが出現する。
    final roll = _random.nextInt(3);
    if (roll == 0) {
      if (_random.nextInt(100) < 60) {
        return GachaCharacter.fromDevice(todayFeaturedSsr);
      }
      return _pickDeviceExcluding(Rarity.ssr, todayFeaturedSsr.deviceName);
    }
    return _pickDevice(Rarity.sr);
  }

  GachaCharacter _drawOneEventLimited() {
    if (isNextEventLimitedGuaranteed) {
      return GachaCharacter.fromDevice(currentEventLimitedSsr);
    }

    final roll = _random.nextInt(4);
    if (roll == 0) return GachaCharacter.fromDevice(currentEventLimitedSsr);
    if (roll == 1) return _pickDevice(Rarity.ssr);
    return _pickDevice(Rarity.sr);
  }

  Future<void> _updatePremiumFeaturedPity(GachaCharacter character) async {
    if (_isTodayFeaturedSsr(character)) {
      await _storage.setPremiumFeaturedMisses(0);
      return;
    }

    final nextMisses = (premiumFeaturedMisses + 1)
        .clamp(
          0,
          premiumFeaturedPityThreshold - 1,
        )
        .toInt();
    await _storage.setPremiumFeaturedMisses(nextMisses);
  }

  bool _isTodayFeaturedSsr(GachaCharacter character) {
    return character.rarity == Rarity.ssr &&
        character.deviceName == todayFeaturedSsr.deviceName;
  }

  Future<void> _updateEventLimitedPity(GachaCharacter character) async {
    if (_isCurrentEventLimitedSsr(character)) {
      await _storage.setEventLimitedMisses(0);
      return;
    }

    final nextMisses = (eventLimitedMisses + 1)
        .clamp(
          0,
          eventLimitedPityThreshold - 1,
        )
        .toInt();
    await _storage.setEventLimitedMisses(nextMisses);
  }

  bool _isCurrentEventLimitedSsr(GachaCharacter character) {
    return character.rarity == Rarity.ssr &&
        character.deviceName == currentEventLimitedSsr.deviceName;
  }

  /// 指定レアリティの端末からランダムに1体を選んでGachaCharacterを生成
  GachaCharacter _pickDevice(Rarity rarity) {
    final candidates = gachaDevicesByRarity(rarity);
    final device = candidates[_random.nextInt(candidates.length)];
    return GachaCharacter.fromDevice(device);
  }

  GachaCharacter _pickDeviceExcluding(Rarity rarity, String excludedName) {
    final candidates = gachaDevicesByRarity(rarity)
        .where((device) => device.deviceName != excludedName)
        .toList();
    if (candidates.isEmpty) return _pickDevice(rarity);
    final device = candidates[_random.nextInt(candidates.length)];
    return GachaCharacter.fromDevice(device);
  }

  /// インベントリにキャラクターを追加保存。
  /// 同一レアリティ・同一端末の重複は既存個体の覚醒に変換する。
  Future<_RosterSaveResult> _saveToRoster(
      List<GachaCharacter> newCharacters) async {
    final roster = loadRoster();
    final resolved = <GachaCharacter>[];
    var duplicateUpgrades = 0;
    var duplicateRefundCoins = 0;

    for (final pulled in newCharacters) {
      final existingIndex =
          roster.indexWhere((owned) => owned.isSameSeries(pulled));
      if (existingIndex >= 0) {
        final existing = roster[existingIndex];
        final upgraded = existing.awaken();
        if (upgraded.awakeningLevel > existing.awakeningLevel) {
          duplicateUpgrades++;
        } else {
          duplicateRefundCoins += duplicateRefundCoinsFor(existing.rarity);
        }
        roster[existingIndex] = upgraded;
        resolved.add(upgraded);
      } else {
        roster.add(pulled);
        resolved.add(pulled);
      }
    }

    await _storage.saveGachaCharacters(
      roster.map((c) => c.toJsonString()).toList(),
    );
    return _RosterSaveResult(
      characters: resolved,
      duplicateUpgrades: duplicateUpgrades,
      duplicateRefundCoins: duplicateRefundCoins,
    );
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

class _RosterSaveResult {
  final List<GachaCharacter> characters;
  final int duplicateUpgrades;
  final int duplicateRefundCoins;

  const _RosterSaveResult({
    required this.characters,
    required this.duplicateUpgrades,
    required this.duplicateRefundCoins,
  });
}
