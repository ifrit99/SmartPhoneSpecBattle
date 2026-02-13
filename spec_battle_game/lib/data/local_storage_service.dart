import 'package:shared_preferences/shared_preferences.dart';

/// ローカルストレージを使用したデータ永続化サービス
class LocalStorageService {
  static const String _keyLevel = 'level';
  static const String _keyCurrentExp = 'current_exp';
  static const String _keyExpToNext = 'exp_to_next';
  static const String _keyBattleCount = 'battle_count';
  static const String _keyWinCount = 'win_count';

  SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- 経験値・レベル ---

  Future<void> saveExperience(int level, int currentExp, int expToNext) async {
    await _prefs.setInt(_keyLevel, level);
    await _prefs.setInt(_keyCurrentExp, currentExp);
    await _prefs.setInt(_keyExpToNext, expToNext);
  }

  int getLevel() => _prefs.getInt(_keyLevel) ?? 1;
  int getCurrentExp() => _prefs.getInt(_keyCurrentExp) ?? 0;
  int getExpToNext() => _prefs.getInt(_keyExpToNext) ?? 100;

  // --- バトル戦績 ---

  Future<void> incrementBattleCount() async {
    final count = getBattleCount() + 1;
    await _prefs.setInt(_keyBattleCount, count);
  }

  Future<void> incrementWinCount() async {
    final count = getWinCount() + 1;
    await _prefs.setInt(_keyWinCount, count);
  }

  int getBattleCount() => _prefs.getInt(_keyBattleCount) ?? 0;
  int getWinCount() => _prefs.getInt(_keyWinCount) ?? 0;

  // --- キャラクターデータ（seed情報）---

  Future<void> saveCharacterSeed(int seed) async {
    await _prefs.setInt('character_seed', seed);
  }

  int getCharacterSeed() => _prefs.getInt('character_seed') ?? 0;

  // --- リセット ---

  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
