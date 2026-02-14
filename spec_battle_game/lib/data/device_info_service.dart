import 'dart:io';

/// デバイスのハードウェア情報を取得するサービス
///
/// Platform APIで可能な情報を取得し、取れない情報はデフォルト値を使用する
class DeviceInfoService {
  /// デバイス情報を収集して返す
  Future<DeviceSpecs> getDeviceSpecs() async {
    String osVersion = Platform.operatingSystemVersion;
    String deviceModel = Platform.isAndroid
        ? 'Android Device'
        : Platform.isIOS
            ? 'iOS Device'
            : 'Unknown';

    // 画面サイズはWidgetsBindingから取得するため、
    // ここではプラットフォーム情報のみ返す
    return DeviceSpecs(
      osVersion: osVersion.isNotEmpty ? osVersion : '14.0',
      deviceModel: deviceModel,
      cpuCores: Platform.numberOfProcessors,
      ramMB: _estimateRam(),
      storageFreeGB: 32, // デフォルト値
      batteryLevel: 100,  // デフォルト値（後でプラグインで更新可能）
      screenWidth: 0,     // 後でWidgetから設定
      screenHeight: 0,    // 後でWidgetから設定
    );
  }

  /// デバイスのRAM容量をCPUコア数から推定する
  int _estimateRam() {
    final cores = Platform.numberOfProcessors;
    if (cores >= 8) return 6144;  // 6GB
    if (cores >= 6) return 4096;  // 4GB
    if (cores >= 4) return 3072;  // 3GB
    return 2048;                   // 2GB
  }
}

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
