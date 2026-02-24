import '../../data/local_storage_service.dart';
import 'experience_service.dart';
import 'currency_service.dart';
import 'gacha_service.dart';

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

  /// 全サービスの初期化（アプリ起動時に1回だけ呼ぶ）
  Future<void> init() async {
    if (_initialized) return;

    storage = LocalStorageService();
    await storage.init();

    experienceService = ExperienceService(storage);
    currencyService = CurrencyService(storage);
    gachaService = GachaService(currencyService, storage);

    _initialized = true;
  }
}
