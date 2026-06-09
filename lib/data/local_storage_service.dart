import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

class BattleHistoryEntry {
  final String id;
  final String happenedAt;
  final bool playerWon;
  final String playerName;
  final String enemyName;
  final String modeLabel;
  final String difficultyLabel;
  final int turnsPlayed;
  final int expGained;
  final int coinsGained;
  final String tacticLabel;
  final String supportLabel;
  final String rewardSummary;

  const BattleHistoryEntry({
    required this.id,
    required this.happenedAt,
    required this.playerWon,
    required this.playerName,
    required this.enemyName,
    required this.modeLabel,
    required this.difficultyLabel,
    required this.turnsPlayed,
    required this.expGained,
    required this.coinsGained,
    required this.tacticLabel,
    required this.supportLabel,
    required this.rewardSummary,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'happenedAt': happenedAt,
        'playerWon': playerWon,
        'playerName': playerName,
        'enemyName': enemyName,
        'modeLabel': modeLabel,
        'difficultyLabel': difficultyLabel,
        'turnsPlayed': turnsPlayed,
        'expGained': expGained,
        'coinsGained': coinsGained,
        'tacticLabel': tacticLabel,
        'supportLabel': supportLabel,
        'rewardSummary': rewardSummary,
      };

  String toJsonString() => jsonEncode(toJson());

  factory BattleHistoryEntry.fromJsonString(String raw) {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return BattleHistoryEntry(
      id: _stringValue(data['id'], ''),
      happenedAt: _stringValue(data['happenedAt'], ''),
      playerWon: data['playerWon'] == true,
      playerName: _stringValue(data['playerName'], 'プレイヤー'),
      enemyName: _stringValue(data['enemyName'], '敵'),
      modeLabel: _stringValue(data['modeLabel'], 'CPU'),
      difficultyLabel: _stringValue(data['difficultyLabel'], 'NORMAL'),
      turnsPlayed: _intValue(data['turnsPlayed'], 0),
      expGained: _intValue(data['expGained'], 0),
      coinsGained: _intValue(data['coinsGained'], 0),
      tacticLabel: _stringValue(data['tacticLabel'], 'バランス'),
      supportLabel: _stringValue(data['supportLabel'], '支援なし'),
      rewardSummary: _stringValue(data['rewardSummary'], ''),
    );
  }

  static String _stringValue(Object? value, String fallback) =>
      value is String && value.isNotEmpty ? value : fallback;

  static int _intValue(Object? value, int fallback) =>
      value is int ? value : fallback;
}

/// ローカルストレージを使用したデータ永続化サービス（シングルトン）
class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  static const String _keyLevel = 'level';
  static const String _keyCurrentExp = 'current_exp';
  static const String _keyExpToNext = 'exp_to_next';
  static const String _keyBattleCount = 'battle_count';
  static const String _keyWinCount = 'win_count';
  static const String _keyBattleHistory = 'battle_history';
  static const String _keyDefeatedEnemies = 'defeated_enemies';
  static const String _keyDefeatedEnemiesMigrated = 'defeated_enemies_migrated';
  static const String _keyGachaRosterMigrated = 'gacha_roster_migrated';
  static const String _keyCoins = 'coins';
  static const String _keyPremiumGems = 'premium_gems';
  static const String _keyGachaRoster = 'gacha_roster';
  static const String _keyEquippedGachaCharacter = 'equipped_gacha_character';
  static const String _keyPremiumFeaturedMisses = 'gacha.premiumFeaturedMisses';
  static const String _keyEventLimitedMisses = 'gacha.eventLimitedMisses';
  static const String _keySeed = 'character_seed';
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyFirstBattleCompleted = 'first_battle_completed';
  static const String _keyLastLoginRewardDate = 'daily.lastLoginRewardDate';
  static const String _keyLastBattleRewardDate = 'daily.lastBattleRewardDate';
  static const String _keyLoginStreakDays = 'daily.loginStreakDays';
  static const String _keyClaimedAchievements = 'claimed_achievements';
  static const String _keyClaimedRankRewards = 'claimed_rank_rewards';
  static const String _keyRivalRoadClearedStage = 'rivalRoad.clearedStage';
  static const String _keyRivalRoadBestTurns = 'rivalRoad.bestTurns';
  static const String _keyBgmMuted = 'sound.bgmMuted';
  static const String _keySeMuted = 'sound.seMuted';
  static const String _keyDailyMissionDate = 'daily.missionDate';
  static const String _keyDailyMissionBattles = 'daily.missionBattles';
  static const String _keyDailyMissionWins = 'daily.missionWins';
  static const String _keyDailyMissionGachaPulls = 'daily.missionGachaPulls';
  static const String _keyDailyMissionClaimed = 'daily.missionClaimed';
  static const String _keyDailyShopDate = 'daily.shopDate';
  static const String _keyDailyShopPurchased = 'daily.shopPurchased';
  static const String _keyWeeklyChallengeWeek = 'weekly.challengeWeek';
  static const String _keyWeeklyChallengeHighDifficultyWins =
      'weekly.challengeHighDifficultyWins';
  static const String _keyWeeklyChallengeClaimed = 'weekly.challengeClaimed';
  static const String _keyLimitedEventWeek = 'event.limitedWeek';
  static const String _keyLimitedEventWins = 'event.limitedWins';
  static const String _keyLimitedEventClaimed = 'event.limitedClaimed';
  static const String _keyLimitedEventClaimedMilestones =
      'event.limitedClaimedMilestones';
  static const String _keySeasonPassId = 'season.passId';
  static const String _keySeasonPassXp = 'season.passXp';
  static const String _keySeasonPassClaimedRewards =
      'season.passClaimedRewards';
  static const String _keyLastBossBountyDate = 'bossBounty.lastClaimDate';
  static const String _keyBossBestTurns = 'boss.bestTurns';
  static const String _backupPrefix = 'SPEC-BATTLE-BACKUP:';
  static const int maxBattleHistoryEntries = 20;

  SharedPreferences? _prefs;

  /// SharedPreferencesが初期化済みかどうか
  bool get isInitialized => _prefs != null;

  /// SharedPreferencesの初期化
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// テスト用: SharedPreferencesインスタンスをリセットして再取得する
  @visibleForTesting
  Future<void> resetForTest() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 初期化済みのSharedPreferencesを取得（未初期化時は例外）
  SharedPreferences get _store {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError(
          'LocalStorageService.init() が呼ばれていません。先に init() を実行してください。');
    }
    return prefs;
  }

  // --- 経験値・レベル ---

  /// 経験値情報を保存
  Future<void> saveExperience(int level, int currentExp, int expToNext) async {
    await _store.setInt(_keyLevel, level);
    await _store.setInt(_keyCurrentExp, currentExp);
    await _store.setInt(_keyExpToNext, expToNext);
  }

  int getLevel() => _store.getInt(_keyLevel) ?? 1;
  int getCurrentExp() => _store.getInt(_keyCurrentExp) ?? 0;
  int getExpToNext() => _store.getInt(_keyExpToNext) ?? 100;

  // --- バトル戦績 ---

  /// バトル回数をインクリメント
  Future<void> incrementBattleCount() async {
    final count = getBattleCount() + 1;
    await _store.setInt(_keyBattleCount, count);
  }

  /// 勝利回数をインクリメント
  Future<void> incrementWinCount() async {
    final count = getWinCount() + 1;
    await _store.setInt(_keyWinCount, count);
  }

  int getBattleCount() => _store.getInt(_keyBattleCount) ?? 0;
  int getWinCount() => _store.getInt(_keyWinCount) ?? 0;

  Future<void> saveBattleHistoryEntry(BattleHistoryEntry entry) async {
    final current = getBattleHistory();
    final updated = [
      entry,
      ...current.where((item) => item.id != entry.id),
    ].take(maxBattleHistoryEntries).map((item) => item.toJsonString()).toList();
    await _store.setStringList(_keyBattleHistory, updated);
  }

  List<BattleHistoryEntry> getBattleHistory() {
    final raws = _store.getStringList(_keyBattleHistory) ?? [];
    return raws
        .map((raw) {
          try {
            return BattleHistoryEntry.fromJsonString(raw);
          } on FormatException {
            return null;
          } on TypeError {
            return null;
          }
        })
        .whereType<BattleHistoryEntry>()
        .toList();
  }

  // --- キャラクター ---

  /// キャラクターシードを保存
  Future<void> saveCharacterSeed(int seed) async {
    await _store.setInt(_keySeed, seed);
  }

  int getCharacterSeed() => _store.getInt(_keySeed) ?? 0;

  // --- 図鑑（対戦履歴） ---

  /// 撃破した敵のID をリストに追記
  Future<void> saveDefeatedEnemy(String enemyId) async {
    final currentList = getDefeatedEnemies();
    if (!currentList.contains(enemyId)) {
      currentList.add(enemyId);
      await _store.setStringList(_keyDefeatedEnemies, currentList);
    }
  }

  /// 撃破した敵のIDリストを取得
  List<String> getDefeatedEnemies() =>
      _store.getStringList(_keyDefeatedEnemies) ?? [];

  /// 旧デバイス名ベースの図鑑データをIDベースにマイグレーションする。
  /// [nameToIdMap] は旧デバイス名→IDの対応表。
  /// 一度実行済みなら再実行しない。
  Future<void> migrateDefeatedEnemies(Map<String, String> nameToIdMap) async {
    if (_store.getBool(_keyDefeatedEnemiesMigrated) ?? false) return;

    final currentList = getDefeatedEnemies();
    if (currentList.isEmpty) {
      await _store.setBool(_keyDefeatedEnemiesMigrated, true);
      return;
    }

    // 旧データの中にIDでないもの（＝旧デバイス名）があれば変換する
    final migrated = <String>{};
    for (final entry in currentList) {
      final mapped = nameToIdMap[entry];
      if (mapped != null) {
        // 旧デバイス名 → 新ID に変換
        migrated.add(mapped);
      } else {
        // すでにIDか、マッピングにない未知のエントリはそのまま残す
        migrated.add(entry);
      }
    }

    await _store.setStringList(_keyDefeatedEnemies, migrated.toList());
    await _store.setBool(_keyDefeatedEnemiesMigrated, true);
  }

  /// 旧デバイス名のガチャインベントリを新デバイス名にマイグレーションする。
  /// [deviceNameMap] は旧デバイス名→新デバイス名の対応表。
  /// 一度実行済みなら再実行しない。
  Future<void> migrateGachaRoster(Map<String, String> deviceNameMap) async {
    if (_store.getBool(_keyGachaRosterMigrated) ?? false) return;

    final jsonList = getGachaCharacters();
    if (jsonList.isEmpty) {
      await _store.setBool(_keyGachaRosterMigrated, true);
      return;
    }

    final migrated = <String>[];
    for (final jsonStr in jsonList) {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final oldName = map['deviceName'] as String?;
      if (oldName != null && deviceNameMap.containsKey(oldName)) {
        map['deviceName'] = deviceNameMap[oldName];
      }
      migrated.add(jsonEncode(map));
    }

    await saveGachaCharacters(migrated);
    await _store.setBool(_keyGachaRosterMigrated, true);
  }

  // --- 通貨 ---

  Future<void> saveCoins(int coins) async {
    await _store.setInt(_keyCoins, coins);
  }

  int getCoins() => _store.getInt(_keyCoins) ?? 0;

  Future<void> savePremiumGems(int gems) async {
    await _store.setInt(_keyPremiumGems, gems);
  }

  int getPremiumGems() => _store.getInt(_keyPremiumGems) ?? 0;

  // --- ガチャインベントリ ---

  /// ガチャで獲得したキャラクターリストを保存
  Future<void> saveGachaCharacters(List<String> characterJsons) async {
    await _store.setStringList(_keyGachaRoster, characterJsons);
  }

  /// ガチャで獲得したキャラクターリスト（JSON文字列のリスト）を取得
  List<String> getGachaCharacters() =>
      _store.getStringList(_keyGachaRoster) ?? [];

  /// 装備中のガチャキャラクターIDを保存
  Future<void> saveEquippedGachaCharacterId(String? id) async {
    if (id == null) {
      await _store.remove(_keyEquippedGachaCharacter);
    } else {
      await _store.setString(_keyEquippedGachaCharacter, id);
    }
  }

  /// 装備中のガチャキャラクターIDを取得
  String? getEquippedGachaCharacterId() =>
      _store.getString(_keyEquippedGachaCharacter);

  /// プレミアム解析で日替わりピックアップSSRを引けなかった連続回数を保存
  Future<void> setPremiumFeaturedMisses(int count) async {
    await _store.setInt(_keyPremiumFeaturedMisses, count);
  }

  int getPremiumFeaturedMisses() =>
      _store.getInt(_keyPremiumFeaturedMisses) ?? 0;

  Future<void> setEventLimitedMisses(int count) async {
    await _store.setInt(_keyEventLimitedMisses, count);
  }

  int getEventLimitedMisses() => _store.getInt(_keyEventLimitedMisses) ?? 0;

  // --- オンボーディング ---

  /// オンボーディング完了フラグを取得
  bool isOnboardingCompleted() =>
      _store.getBool(_keyOnboardingCompleted) ?? false;

  /// オンボーディング完了フラグを保存
  Future<void> setOnboardingCompleted() async {
    await _store.setBool(_keyOnboardingCompleted, true);
  }

  /// 初回バトル完了フラグを取得
  bool isFirstBattleCompleted() =>
      _store.getBool(_keyFirstBattleCompleted) ?? false;

  /// 初回バトル完了フラグを保存
  Future<void> setFirstBattleCompleted() async {
    await _store.setBool(_keyFirstBattleCompleted, true);
  }

  // --- デイリー報酬 ---

  /// ログイン報酬の最終受取日を取得
  String? getLastLoginRewardDate() => _store.getString(_keyLastLoginRewardDate);

  /// ログイン報酬の最終受取日を保存
  Future<void> setLastLoginRewardDate(String dateStr) async {
    await _store.setString(_keyLastLoginRewardDate, dateStr);
  }

  /// 連続ログイン日数を取得
  int getLoginStreakDays() => _store.getInt(_keyLoginStreakDays) ?? 0;

  /// 連続ログイン日数を保存
  Future<void> setLoginStreakDays(int days) async {
    await _store.setInt(_keyLoginStreakDays, days);
  }

  /// バトル報酬の最終受取日を取得
  String? getLastBattleRewardDate() =>
      _store.getString(_keyLastBattleRewardDate);

  /// バトル報酬の最終受取日を保存
  Future<void> setLastBattleRewardDate(String dateStr) async {
    await _store.setString(_keyLastBattleRewardDate, dateStr);
  }

  // --- 実績 ---

  List<String> getClaimedAchievements() =>
      _store.getStringList(_keyClaimedAchievements) ?? [];

  Future<void> saveClaimedAchievements(List<String> ids) async {
    await _store.setStringList(_keyClaimedAchievements, ids);
  }

  // --- サウンド設定 ---

  bool isBgmMuted() => _store.getBool(_keyBgmMuted) ?? false;

  Future<void> setBgmMuted(bool muted) async {
    await _store.setBool(_keyBgmMuted, muted);
  }

  bool isSeMuted() => _store.getBool(_keySeMuted) ?? false;

  Future<void> setSeMuted(bool muted) async {
    await _store.setBool(_keySeMuted, muted);
  }

  // --- デイリーミッション ---

  String? getDailyMissionDate() => _store.getString(_keyDailyMissionDate);

  Future<void> setDailyMissionDate(String dateStr) async {
    await _store.setString(_keyDailyMissionDate, dateStr);
  }

  int getDailyMissionBattles() => _store.getInt(_keyDailyMissionBattles) ?? 0;

  Future<void> setDailyMissionBattles(int count) async {
    await _store.setInt(_keyDailyMissionBattles, count);
  }

  int getDailyMissionWins() => _store.getInt(_keyDailyMissionWins) ?? 0;

  Future<void> setDailyMissionWins(int count) async {
    await _store.setInt(_keyDailyMissionWins, count);
  }

  int getDailyMissionGachaPulls() =>
      _store.getInt(_keyDailyMissionGachaPulls) ?? 0;

  Future<void> setDailyMissionGachaPulls(int count) async {
    await _store.setInt(_keyDailyMissionGachaPulls, count);
  }

  List<String> getClaimedDailyMissions() =>
      _store.getStringList(_keyDailyMissionClaimed) ?? [];

  Future<void> saveClaimedDailyMissions(List<String> ids) async {
    await _store.setStringList(_keyDailyMissionClaimed, ids);
  }

  // --- 日替わりショップ ---

  String? getDailyShopDate() => _store.getString(_keyDailyShopDate);

  Future<void> setDailyShopDate(String dateStr) async {
    await _store.setString(_keyDailyShopDate, dateStr);
  }

  List<String> getPurchasedDailyShopOffers() =>
      _store.getStringList(_keyDailyShopPurchased) ?? [];

  Future<void> savePurchasedDailyShopOffers(List<String> ids) async {
    await _store.setStringList(_keyDailyShopPurchased, ids);
  }

  // --- 週次チャレンジ ---

  String? getWeeklyChallengeWeekId() =>
      _store.getString(_keyWeeklyChallengeWeek);

  Future<void> setWeeklyChallengeWeekId(String weekId) async {
    await _store.setString(_keyWeeklyChallengeWeek, weekId);
  }

  int getWeeklyChallengeHighDifficultyWins() =>
      _store.getInt(_keyWeeklyChallengeHighDifficultyWins) ?? 0;

  Future<void> setWeeklyChallengeHighDifficultyWins(int count) async {
    await _store.setInt(_keyWeeklyChallengeHighDifficultyWins, count);
  }

  bool isWeeklyChallengeClaimed() =>
      _store.getBool(_keyWeeklyChallengeClaimed) ?? false;

  Future<void> setWeeklyChallengeClaimed(bool claimed) async {
    await _store.setBool(_keyWeeklyChallengeClaimed, claimed);
  }

  // --- 期間イベント ---

  String? getLimitedEventWeekId() => _store.getString(_keyLimitedEventWeek);

  Future<void> setLimitedEventWeekId(String weekId) async {
    await _store.setString(_keyLimitedEventWeek, weekId);
  }

  int getLimitedEventWins() => _store.getInt(_keyLimitedEventWins) ?? 0;

  Future<void> setLimitedEventWins(int count) async {
    await _store.setInt(_keyLimitedEventWins, count);
  }

  bool isLimitedEventClaimed() =>
      _store.getBool(_keyLimitedEventClaimed) ?? false;

  Future<void> setLimitedEventClaimed(bool claimed) async {
    await _store.setBool(_keyLimitedEventClaimed, claimed);
  }

  List<String> getClaimedLimitedEventMilestones() =>
      _store.getStringList(_keyLimitedEventClaimedMilestones) ?? [];

  Future<void> saveClaimedLimitedEventMilestones(List<String> ids) async {
    await _store.setStringList(_keyLimitedEventClaimedMilestones, ids);
  }

  // --- ランク報酬 ---

  List<String> getClaimedRankRewards() =>
      _store.getStringList(_keyClaimedRankRewards) ?? [];

  Future<void> saveClaimedRankRewards(List<String> ids) async {
    await _store.setStringList(_keyClaimedRankRewards, ids);
  }

  // --- ライバルロード ---

  int getRivalRoadClearedStage() =>
      _store.getInt(_keyRivalRoadClearedStage) ?? 0;

  Future<void> setRivalRoadClearedStage(int stage) async {
    await _store.setInt(_keyRivalRoadClearedStage, stage);
  }

  Map<int, int> getRivalRoadBestTurns() {
    final entries = _store.getStringList(_keyRivalRoadBestTurns) ?? [];
    final result = <int, int>{};
    for (final entry in entries) {
      final parts = entry.split(':');
      if (parts.length != 2) continue;
      final stage = int.tryParse(parts[0]);
      final turns = int.tryParse(parts[1]);
      if (stage != null && stage > 0 && turns != null && turns > 0) {
        result[stage] = turns;
      }
    }
    return result;
  }

  int? getRivalRoadBestTurnsForStage(int stage) =>
      getRivalRoadBestTurns()[stage];

  Future<void> setRivalRoadBestTurnsForStage(int stage, int turns) async {
    if (stage <= 0 || turns <= 0) return;
    final bestTurns = getRivalRoadBestTurns();
    bestTurns[stage] = turns;
    final entries = bestTurns.entries
        .map((entry) => '${entry.key}:${entry.value}')
        .toList()
      ..sort();
    await _store.setStringList(_keyRivalRoadBestTurns, entries);
  }

  // --- シーズンパス ---

  String? getSeasonPassId() => _store.getString(_keySeasonPassId);

  Future<void> setSeasonPassId(String seasonId) async {
    await _store.setString(_keySeasonPassId, seasonId);
  }

  int getSeasonPassXp() => _store.getInt(_keySeasonPassXp) ?? 0;

  Future<void> setSeasonPassXp(int xp) async {
    await _store.setInt(_keySeasonPassXp, xp);
  }

  List<String> getClaimedSeasonPassRewards() =>
      _store.getStringList(_keySeasonPassClaimedRewards) ?? [];

  Future<void> saveClaimedSeasonPassRewards(List<String> ids) async {
    await _store.setStringList(_keySeasonPassClaimedRewards, ids);
  }

  // --- BOSS撃破報酬 ---

  String? getLastBossBountyDate() => _store.getString(_keyLastBossBountyDate);

  Future<void> setLastBossBountyDate(String dateStr) async {
    await _store.setString(_keyLastBossBountyDate, dateStr);
  }

  // --- BOSSタイムアタック ---

  int? getBossBestTurns() {
    final turns = _store.getInt(_keyBossBestTurns);
    return turns == null || turns <= 0 ? null : turns;
  }

  Future<void> setBossBestTurns(int turns) async {
    await _store.setInt(_keyBossBestTurns, turns);
  }

  // --- バックアップ ---

  Future<String> exportBackupCode() async {
    final payload = {
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'data': {
        _keyLevel: getLevel(),
        _keyCurrentExp: getCurrentExp(),
        _keyExpToNext: getExpToNext(),
        _keyBattleCount: getBattleCount(),
        _keyWinCount: getWinCount(),
        _keyBattleHistory:
            getBattleHistory().map((entry) => entry.toJsonString()).toList(),
        _keyDefeatedEnemies: getDefeatedEnemies(),
        _keyDefeatedEnemiesMigrated:
            _store.getBool(_keyDefeatedEnemiesMigrated) ?? false,
        _keyGachaRosterMigrated:
            _store.getBool(_keyGachaRosterMigrated) ?? false,
        _keyCoins: getCoins(),
        _keyPremiumGems: getPremiumGems(),
        _keyGachaRoster: getGachaCharacters(),
        _keyEquippedGachaCharacter: getEquippedGachaCharacterId(),
        _keyPremiumFeaturedMisses: getPremiumFeaturedMisses(),
        _keyEventLimitedMisses: getEventLimitedMisses(),
        _keySeed: getCharacterSeed(),
        _keyOnboardingCompleted: isOnboardingCompleted(),
        _keyFirstBattleCompleted: isFirstBattleCompleted(),
        _keyLastLoginRewardDate: getLastLoginRewardDate(),
        _keyLastBattleRewardDate: getLastBattleRewardDate(),
        _keyLoginStreakDays: getLoginStreakDays(),
        _keyClaimedAchievements: getClaimedAchievements(),
        _keyClaimedRankRewards: getClaimedRankRewards(),
        _keyRivalRoadClearedStage: getRivalRoadClearedStage(),
        _keyRivalRoadBestTurns: getRivalRoadBestTurns()
            .entries
            .map((e) => '${e.key}:${e.value}')
            .toList(),
        _keyBgmMuted: isBgmMuted(),
        _keySeMuted: isSeMuted(),
        _keyDailyMissionDate: getDailyMissionDate(),
        _keyDailyMissionBattles: getDailyMissionBattles(),
        _keyDailyMissionWins: getDailyMissionWins(),
        _keyDailyMissionGachaPulls: getDailyMissionGachaPulls(),
        _keyDailyMissionClaimed: getClaimedDailyMissions(),
        _keyDailyShopDate: getDailyShopDate(),
        _keyDailyShopPurchased: getPurchasedDailyShopOffers(),
        _keyWeeklyChallengeWeek: getWeeklyChallengeWeekId(),
        _keyWeeklyChallengeHighDifficultyWins:
            getWeeklyChallengeHighDifficultyWins(),
        _keyWeeklyChallengeClaimed: isWeeklyChallengeClaimed(),
        _keyLimitedEventWeek: getLimitedEventWeekId(),
        _keyLimitedEventWins: getLimitedEventWins(),
        _keyLimitedEventClaimed: isLimitedEventClaimed(),
        _keyLimitedEventClaimedMilestones: getClaimedLimitedEventMilestones(),
        _keySeasonPassId: getSeasonPassId(),
        _keySeasonPassXp: getSeasonPassXp(),
        _keySeasonPassClaimedRewards: getClaimedSeasonPassRewards(),
        _keyLastBossBountyDate: getLastBossBountyDate(),
        _keyBossBestTurns: getBossBestTurns(),
      },
    };
    final encoded = base64UrlEncode(utf8.encode(jsonEncode(payload)));
    return '$_backupPrefix$encoded';
  }

  Future<void> importBackupCode(String rawCode) async {
    final trimmed = rawCode.trim();
    final body = trimmed.startsWith(_backupPrefix)
        ? trimmed.substring(_backupPrefix.length)
        : trimmed;

    final decoded = utf8.decode(base64Url.decode(body));
    final payload = jsonDecode(decoded) as Map<String, dynamic>;
    if (payload['version'] != 1) {
      throw FormatException('未対応のバックアップ形式です');
    }

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw FormatException('バックアップデータが壊れています');
    }

    await _store.clear();
    await _store.setInt(_keyLevel, _asInt(data[_keyLevel], 1));
    await _store.setInt(_keyCurrentExp, _asInt(data[_keyCurrentExp], 0));
    await _store.setInt(_keyExpToNext, _asInt(data[_keyExpToNext], 100));
    await _store.setInt(_keyBattleCount, _asInt(data[_keyBattleCount], 0));
    await _store.setInt(_keyWinCount, _asInt(data[_keyWinCount], 0));
    await _store.setStringList(
      _keyBattleHistory,
      _asStringList(data[_keyBattleHistory])
          .take(maxBattleHistoryEntries)
          .toList(),
    );
    await _store.setStringList(
      _keyDefeatedEnemies,
      _asStringList(data[_keyDefeatedEnemies]),
    );
    await _store.setBool(
      _keyDefeatedEnemiesMigrated,
      data[_keyDefeatedEnemiesMigrated] == true,
    );
    await _store.setBool(
      _keyGachaRosterMigrated,
      data[_keyGachaRosterMigrated] == true,
    );
    await _store.setInt(_keyCoins, _asInt(data[_keyCoins], 0));
    await _store.setInt(_keyPremiumGems, _asInt(data[_keyPremiumGems], 0));
    await _store.setStringList(
      _keyGachaRoster,
      _asStringList(data[_keyGachaRoster]),
    );
    await _setOptionalString(
      _keyEquippedGachaCharacter,
      data[_keyEquippedGachaCharacter],
    );
    await _store.setInt(
      _keyPremiumFeaturedMisses,
      _asInt(data[_keyPremiumFeaturedMisses], 0),
    );
    await _store.setInt(
      _keyEventLimitedMisses,
      _asInt(data[_keyEventLimitedMisses], 0),
    );
    await _store.setInt(_keySeed, _asInt(data[_keySeed], 0));
    await _store.setBool(
      _keyOnboardingCompleted,
      data[_keyOnboardingCompleted] == true,
    );
    await _store.setBool(
      _keyFirstBattleCompleted,
      data[_keyFirstBattleCompleted] == true,
    );
    await _setOptionalString(
        _keyLastLoginRewardDate, data[_keyLastLoginRewardDate]);
    await _setOptionalString(
        _keyLastBattleRewardDate, data[_keyLastBattleRewardDate]);
    await _store.setInt(
      _keyLoginStreakDays,
      _asInt(data[_keyLoginStreakDays], 0),
    );
    await _store.setStringList(
      _keyClaimedAchievements,
      _asStringList(data[_keyClaimedAchievements]),
    );
    await _store.setStringList(
      _keyClaimedRankRewards,
      _asStringList(data[_keyClaimedRankRewards]),
    );
    await _store.setInt(
      _keyRivalRoadClearedStage,
      _asInt(data[_keyRivalRoadClearedStage], 0),
    );
    await _store.setStringList(
      _keyRivalRoadBestTurns,
      _asStringList(data[_keyRivalRoadBestTurns]),
    );
    await _store.setBool(_keyBgmMuted, data[_keyBgmMuted] == true);
    await _store.setBool(_keySeMuted, data[_keySeMuted] == true);
    await _setOptionalString(_keyDailyMissionDate, data[_keyDailyMissionDate]);
    await _store.setInt(
      _keyDailyMissionBattles,
      _asInt(data[_keyDailyMissionBattles], 0),
    );
    await _store.setInt(
      _keyDailyMissionWins,
      _asInt(data[_keyDailyMissionWins], 0),
    );
    await _store.setInt(
      _keyDailyMissionGachaPulls,
      _asInt(data[_keyDailyMissionGachaPulls], 0),
    );
    await _store.setStringList(
      _keyDailyMissionClaimed,
      _asStringList(data[_keyDailyMissionClaimed]),
    );
    await _setOptionalString(_keyDailyShopDate, data[_keyDailyShopDate]);
    await _store.setStringList(
      _keyDailyShopPurchased,
      _asStringList(data[_keyDailyShopPurchased]),
    );
    await _setOptionalString(
      _keyWeeklyChallengeWeek,
      data[_keyWeeklyChallengeWeek],
    );
    await _store.setInt(
      _keyWeeklyChallengeHighDifficultyWins,
      _asInt(data[_keyWeeklyChallengeHighDifficultyWins], 0),
    );
    await _store.setBool(
      _keyWeeklyChallengeClaimed,
      data[_keyWeeklyChallengeClaimed] == true,
    );
    await _setOptionalString(
      _keyLimitedEventWeek,
      data[_keyLimitedEventWeek],
    );
    await _store.setInt(
      _keyLimitedEventWins,
      _asInt(data[_keyLimitedEventWins], 0),
    );
    await _store.setBool(
      _keyLimitedEventClaimed,
      data[_keyLimitedEventClaimed] == true,
    );
    await _store.setStringList(
      _keyLimitedEventClaimedMilestones,
      _asStringList(data[_keyLimitedEventClaimedMilestones]),
    );
    await _setOptionalString(_keySeasonPassId, data[_keySeasonPassId]);
    await _store.setInt(
      _keySeasonPassXp,
      _asInt(data[_keySeasonPassXp], 0),
    );
    await _store.setStringList(
      _keySeasonPassClaimedRewards,
      _asStringList(data[_keySeasonPassClaimedRewards]),
    );
    await _setOptionalString(
      _keyLastBossBountyDate,
      data[_keyLastBossBountyDate],
    );
    final bossBestTurns = data[_keyBossBestTurns];
    if (bossBestTurns is int && bossBestTurns > 0) {
      await _store.setInt(_keyBossBestTurns, bossBestTurns);
    }
  }

  int _asInt(Object? value, int fallback) {
    return value is int ? value : fallback;
  }

  List<String> _asStringList(Object? value) {
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return const [];
  }

  Future<void> _setOptionalString(String key, Object? value) async {
    if (value is String && value.isNotEmpty) {
      await _store.setString(key, value);
    } else {
      await _store.remove(key);
    }
  }

  /// 全データをクリア
  Future<void> clearAll() async {
    await _store.clear();
  }
}
