import '../../data/local_storage_service.dart';
import 'daily_reward_service.dart';
import 'experience_service.dart';
import 'currency_service.dart';
import 'gacha_service.dart';
import 'qr_battle_service.dart';

/// 旧デバイス名（実在名・架空名）→ 固定IDの対応表（マイグレーション用）
const _oldDeviceNameToIdMap = <String, String>{
  // 実在名（v1）→ ID
  'Galaxy J2 Prime': 'easy_01',
  'Redmi 4A': 'easy_02',
  'AQUOS sense2': 'easy_03',
  'iPhone 6s': 'easy_04',
  'Pixel 5a': 'normal_01',
  'Galaxy A54': 'normal_02',
  'iPhone 13': 'normal_03',
  'Xperia 10 V': 'normal_04',
  'Galaxy S24': 'hard_01',
  'Pixel 9 Pro': 'hard_02',
  'iPhone 16 Pro': 'hard_03',
  'Xperia 1 VI': 'hard_04',
  'Galaxy S24 Ultra': 'boss_01',
  'iPhone 16 Pro Max': 'boss_02',
  'Pixel 9 Pro XL': 'boss_03',
  'ROG Phone 9 Pro': 'boss_04',
  // 架空名（v2）→ ID
  'Stellar J2 Lite': 'easy_01',
  'Blazemi 4A': 'easy_02',
  'Clario sense2': 'easy_03',
  'FruitPhone 6s': 'easy_04',
  'Prism 5a': 'normal_01',
  'Stellar A54': 'normal_02',
  'FruitPhone 13': 'normal_03',
  'Nexia 10 V': 'normal_04',
  'Stellar S24': 'hard_01',
  'Prism 9 Pro': 'hard_02',
  'FruitPhone 16 Pro': 'hard_03',
  'Nexia 1 VI': 'hard_04',
  'Stellar S24 Ultra': 'boss_01',
  'FruitPhone 16 Pro Max': 'boss_02',
  'Prism 9 Pro XL': 'boss_03',
  'Forge Phone 9 Pro': 'boss_04',
};

/// アプリ全体で共有するサービスインスタンスを一元管理するロケータ
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  late final LocalStorageService storage;
  late final ExperienceService experienceService;
  late final CurrencyService currencyService;
  late final GachaService gachaService;
  late final QrBattleService qrBattleService;
  late final DailyRewardService dailyRewardService;

  /// 全サービスの初期化（アプリ起動時に1回だけ呼ぶ）
  Future<void> init() async {
    if (_initialized) return;

    storage = LocalStorageService();
    await storage.init();

    // 旧デバイス名ベースの図鑑データをIDベースにマイグレーション
    await storage.migrateDefeatedEnemies(_oldDeviceNameToIdMap);

    experienceService = ExperienceService(storage);
    currencyService = CurrencyService(storage);
    gachaService = GachaService(currencyService, storage);
    qrBattleService = QrBattleService();
    dailyRewardService = DailyRewardService(storage, currencyService);

    _initialized = true;
  }
}
