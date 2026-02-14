import 'package:shared_preferences/shared_preferences.dart';

/// ローカルストレージを使用したデータ永続化サービス
class LocalStorageService {
  static const String _keyLevel = 'level';
  static const String _keyCurrentExp = 'current_exp';
  static const String _keyExpToNext = 'exp_to_next';
  static const String _keyBattleCount = 'battle_count';
  static const String _keyWinCount = 'win_count';

  late SharedPreferences _prefs;

  /// SharedPreferencesの初期化
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- 経験値・レベル ---

  /// 経験値情報を保存
  Future<void> saveExperience(int level, int currentExp, int expToNext) async {
    await _prefs.setInt(_keyLevel, level);
    await _prefs.setInt(_keyCurrentExp, currentExp);
    await _prefs.setInt(_keyExpToNext, expToNext);
  }

  int getLevel() => _prefs.getInt(_keyLevel) ?? 1;
  int getCurrentExp() => _prefs.getInt(_keyCurrentExp) ?? 0;
  int getExpToNext() => _prefs.getInt(_keyExpToNext) ?? 100;

  // --- バトル戦績 ---

  /// バトル回数をインクリメント
  Future<void> incrementBattleCount() async {
    final count = getBattleCount() + 1;
    await _prefs.setInt(_keyBattleCount, count);
  }

  /// 勝利回数をインクリメント
  Future<void> incrementWinCount() async {
    final count = getWinCount() + 1;
    await _prefs.setInt(_keyWinCount, count);
  }

  int getBattleCount() => _prefs.getInt(_keyBattleCount) ?? 0;
  int getWinCount() => _prefs.getInt(_keyWinCount) ?? 0;

  // --- キャラクター ---

  /// キャラクターシードを保存
  Future<void> saveCharacterSeed(int seed) async {
    await _prefs.setInt('character_seed', seed);
  }

  int getCharacterSeed() => _prefs.getInt('character_seed') ?? 0;

  /// 全データをクリア
  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
