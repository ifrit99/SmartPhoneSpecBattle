// 条件付きインポート: Web環境ではstub、ネイティブ環境ではnativeを使用
import 'platform_info_stub.dart'
    if (dart.library.io) 'platform_info_native.dart';

export 'platform_info_stub.dart'
    if (dart.library.io) 'platform_info_native.dart' show PlatformInfo;

/// デバイスのスペック情報を保持するクラス
class DeviceSpecs {
  final String osVersion;
  final String deviceModel;
  final int cpuCores;
  final int ramMB;
  final int storageFreeGB;
  final int batteryLevel; // 0-100
  final double screenWidth;
  final double screenHeight;

  const DeviceSpecs({
    this.osVersion = '14.0',
    this.deviceModel = 'Unknown',
    this.cpuCores = 4,
    this.ramMB = 4096,
    this.storageFreeGB = 32,
    this.batteryLevel = 100,
    this.screenWidth = 375,
    this.screenHeight = 812,
  });

  /// 画面サイズを更新したコピーを返す
  DeviceSpecs withScreenSize(double width, double height) {
    return DeviceSpecs(
      osVersion: osVersion,
      deviceModel: deviceModel,
      cpuCores: cpuCores,
      ramMB: ramMB,
      storageFreeGB: storageFreeGB,
      batteryLevel: batteryLevel,
      screenWidth: width,
      screenHeight: height,
    );
  }

  /// バッテリー残量を更新したコピーを返す
  DeviceSpecs withBattery(int level) {
    return DeviceSpecs(
      osVersion: osVersion,
      deviceModel: deviceModel,
      cpuCores: cpuCores,
      ramMB: ramMB,
      storageFreeGB: storageFreeGB,
      batteryLevel: level,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
    );
  }

  @override
  String toString() =>
      'DeviceSpecs($deviceModel OS:$osVersion CPU:${cpuCores}cores '
      'RAM:${ramMB}MB Storage:${storageFreeGB}GB Battery:$batteryLevel% '
      'Screen:${screenWidth}x$screenHeight)';
}

/// デバイスのハードウェア情報を取得するサービス
///
/// Web環境ではデフォルト値、ネイティブ環境ではPlatform APIを使用
class DeviceInfoService {
  /// デバイス情報を収集して返す
  Future<DeviceSpecs> getDeviceSpecs() async {
    final info = getPlatformInfo();
    final cpuCores = info.cpuCores;

    return DeviceSpecs(
      osVersion: info.osVersion.isNotEmpty ? info.osVersion : '14.0',
      deviceModel: info.deviceModel,
      cpuCores: cpuCores,
      ramMB: _estimateRam(cpuCores),
      storageFreeGB: 32, // デフォルト値
      batteryLevel: 100,  // デフォルト値（後でプラグインで更新可能）
      screenWidth: 0,     // 後でWidgetから設定
      screenHeight: 0,    // 後でWidgetから設定
    );
  }

  /// デバイスのRAM容量をCPUコア数から推定する
  int _estimateRam(int cores) {
    if (cores >= 8) return 6144;  // 6GB
    if (cores >= 6) return 4096;  // 4GB
    if (cores >= 4) return 3072;  // 3GB
    return 2048;                   // 2GB
  }
}
