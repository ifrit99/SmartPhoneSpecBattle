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

/// Web環境のダミー実装
PlatformInfo getPlatformInfo() {
  return const PlatformInfo(
    osVersion: 'Web',
    deviceModel: 'Web Browser',
    cpuCores: 4,
  );
}
