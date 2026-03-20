import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _keyDefeatedEnemies = 'defeated_enemies';
  static const String _keyCoins = 'coins';
  static const String _keyPremiumGems = 'premium_gems';
  static const String _keyGachaRoster = 'gacha_roster';
  static const String _keyEquippedGachaCharacter = 'equipped_gacha_character';
  static const String _keySeed = 'character_seed';
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyFirstBattleCompleted = 'first_battle_completed';

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
      throw StateError('LocalStorageService.init() が呼ばれていません。先に init() を実行してください。');
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

  // --- キャラクター ---

  /// キャラクターシードを保存
  Future<void> saveCharacterSeed(int seed) async {
    await _store.setInt(_keySeed, seed);
  }

  int getCharacterSeed() => _store.getInt(_keySeed) ?? 0;

  // --- 図鑑（対戦履歴） ---

  /// 撃破した敵のリストに追記
  Future<void> saveDefeatedEnemy(String deviceName) async {
    final currentList = getDefeatedEnemies();
    if (!currentList.contains(deviceName)) {
      currentList.add(deviceName);
      await _store.setStringList(_keyDefeatedEnemies, currentList);
    }
  }

  /// 撃破した敵のリストを取得
  List<String> getDefeatedEnemies() => _store.getStringList(_keyDefeatedEnemies) ?? [];

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
  List<String> getGachaCharacters() => _store.getStringList(_keyGachaRoster) ?? [];

  /// 装備中のガチャキャラクターIDを保存
  Future<void> saveEquippedGachaCharacterId(String? id) async {
    if (id == null) {
      await _store.remove(_keyEquippedGachaCharacter);
    } else {
      await _store.setString(_keyEquippedGachaCharacter, id);
    }
  }

  /// 装備中のガチャキャラクターIDを取得
  String? getEquippedGachaCharacterId() => _store.getString(_keyEquippedGachaCharacter);

  // --- オンボーディング ---

  /// オンボーディング完了フラグを取得
  bool isOnboardingCompleted() => _store.getBool(_keyOnboardingCompleted) ?? false;

  /// オンボーディング完了フラグを保存
  Future<void> setOnboardingCompleted() async {
    await _store.setBool(_keyOnboardingCompleted, true);
  }

  /// 初回バトル完了フラグを取得
  bool isFirstBattleCompleted() => _store.getBool(_keyFirstBattleCompleted) ?? false;

  /// 初回バトル完了フラグを保存
  Future<void> setFirstBattleCompleted() async {
    await _store.setBool(_keyFirstBattleCompleted, true);
  }

  /// 全データをクリア
  Future<void> clearAll() async {
    await _store.clear();
  }
}
