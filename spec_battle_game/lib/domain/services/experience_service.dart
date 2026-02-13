import '../models/experience.dart';
import '../../data/local_storage_service.dart';

/// 経験値の管理サービス
class ExperienceService {
  final LocalStorageService _storage;

  ExperienceService(this._storage);

  /// 保存されている経験値情報を読み込む
  Experience loadExperience() {
    return Experience(
      level: _storage.getLevel(),
      currentExp: _storage.getCurrentExp(),
      expToNext: _storage.getExpToNext(),
    );
  }

  /// 経験値を加算して保存
  Future<Experience> addExp(Experience current, int amount) async {
    final updated = current.addExp(amount);
    await _storage.saveExperience(
      updated.level,
      updated.currentExp,
      updated.expToNext,
    );
    return updated;
  }

  /// バトル結果を記録
  Future<void> recordBattle(bool won) async {
    await _storage.incrementBattleCount();
    if (won) {
      await _storage.incrementWinCount();
    }
  }

  /// 戦績を取得
  Map<String, int> getBattleRecord() {
    return {
      'battles': _storage.getBattleCount(),
      'wins': _storage.getWinCount(),
    };
  }
}
