import 'dart:io' show Platform;

/// プラットフォーム情報のインターフェース（Web/ネイティブ共通）
class PlatformInfo {
  final String osVersion;
  final String deviceModel;
  final int cpuCores;

  const PlatformInfo({
    this.osVersion = '14.0',
    this.deviceModel = 'Unknown',
    this.cpuCores = 4,
  });
}

/// ネイティブ環境でのPlatform APIを使用した実装
PlatformInfo getPlatformInfo() {
  String deviceModel = 'Unknown';
  if (Platform.isAndroid) {
    deviceModel = 'Android Device';
  } else if (Platform.isIOS) {
    deviceModel = 'iOS Device';
  } else if (Platform.isMacOS) {
    deviceModel = 'macOS Device';
  }

  return PlatformInfo(
    osVersion: Platform.operatingSystemVersion,
    deviceModel: deviceModel,
    cpuCores: Platform.numberOfProcessors,
  );
}
