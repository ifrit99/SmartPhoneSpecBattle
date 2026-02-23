// 条件付きインポート: Web環境ではstub、ネイティブ環境ではnativeを使用
import 'package:battery_plus/battery_plus.dart';
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
class DeviceInfoService {
  final Battery _battery = Battery();

  /// デバイス情報を収集して返す
  Future<DeviceSpecs> getDeviceSpecs() async {
    final info = getPlatformInfo();
    final cpuCores = info.cpuCores;

    int batteryLevel = 100;
    try {
      batteryLevel = await _battery.batteryLevel;
    } catch (e) {
      // Webやシミュレータ、取得失敗時は100とする
    }

    return DeviceSpecs(
      osVersion: info.osVersion.isNotEmpty ? info.osVersion : '14.0',
      deviceModel: info.deviceModel,
      cpuCores: cpuCores,
      ramMB: _estimateRam(cpuCores),
      storageFreeGB: 32, // デフォルト値
      batteryLevel: batteryLevel,
      screenWidth: 0,     // 後でWidgetから設定
      screenHeight: 0,    // 後でWidgetから設定
    );
  }

  /// バッテリー残量のストリーム
  Stream<int> get batteryLevelStream async* {
    // 最初の値を返す
    try {
      yield await _battery.batteryLevel;
    } catch (_) {
      yield 100;
    }
    
    // 定期的にポーリング（30秒ごと）
    await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
      try {
        yield await _battery.batteryLevel;
      } catch (_) {
        yield 100;
      }
    }
  }

  /// デバイスのRAM容量をCPUコア数から推定する
  int _estimateRam(int cores) {
// ...
    if (cores >= 8) return 6144;  // 6GB
    if (cores >= 6) return 4096;  // 4GB
    if (cores >= 4) return 3072;  // 3GB
    return 2048;                   // 2GB
  }
}
