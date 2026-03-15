import '../enums/rarity.dart';

/// ガチャ用のエミュレートデバイス仕様
class EmulatedDeviceSpec {
  final String deviceName;
  final String osLabel;
  final String osVersion;
  final int cpuCores;
  final int ramMB;
  final int storageFreeGB;
  final int batteryLevel;
  final Rarity rarity;

  const EmulatedDeviceSpec({
    required this.deviceName,
    required this.osLabel,
    required this.osVersion,
    required this.cpuCores,
    required this.ramMB,
    required this.storageFreeGB,
    required this.batteryLevel,
    required this.rarity,
  });
}

/// ガチャ用端末カタログ（N:5, R:5, SR:4, SSR:3 = 計17端末）
const gachaDeviceCatalog = <EmulatedDeviceSpec>[
  // ── N ランク (5端末) ──
  EmulatedDeviceSpec(
    deviceName: 'Galaxy A03',
    osLabel: 'Android 11.0',
    osVersion: '11',
    cpuCores: 4, ramMB: 2048, storageFreeGB: 12, batteryLevel: 50,
    rarity: Rarity.n,
  ),
  EmulatedDeviceSpec(
    deviceName: 'Redmi 9A',
    osLabel: 'Android 10.0',
    osVersion: '10',
    cpuCores: 4, ramMB: 2048, storageFreeGB: 10, batteryLevel: 50,
    rarity: Rarity.n,
  ),
  EmulatedDeviceSpec(
    deviceName: 'AQUOS wish',
    osLabel: 'Android 11.0',
    osVersion: '11',
    cpuCores: 4, ramMB: 3072, storageFreeGB: 16, batteryLevel: 50,
    rarity: Rarity.n,
  ),
  EmulatedDeviceSpec(
    deviceName: 'arrows We',
    osLabel: 'Android 11.0',
    osVersion: '11',
    cpuCores: 4, ramMB: 3072, storageFreeGB: 14, batteryLevel: 50,
    rarity: Rarity.n,
  ),
  EmulatedDeviceSpec(
    deviceName: 'iPhone SE (2nd)',
    osLabel: 'iOS 14.0',
    osVersion: '14',
    cpuCores: 4, ramMB: 3072, storageFreeGB: 18, batteryLevel: 50,
    rarity: Rarity.n,
  ),

  // ── R ランク (5端末) ──
  EmulatedDeviceSpec(
    deviceName: 'Pixel 6a',
    osLabel: 'Android 13.0',
    osVersion: '13',
    cpuCores: 8, ramMB: 6144, storageFreeGB: 48, batteryLevel: 50,
    rarity: Rarity.r,
  ),
  EmulatedDeviceSpec(
    deviceName: 'Galaxy A55',
    osLabel: 'Android 14.0',
    osVersion: '14',
    cpuCores: 8, ramMB: 8192, storageFreeGB: 56, batteryLevel: 50,
    rarity: Rarity.r,
  ),
  EmulatedDeviceSpec(
    deviceName: 'iPhone 14',
    osLabel: 'iOS 17.0',
    osVersion: '17',
    cpuCores: 6, ramMB: 6144, storageFreeGB: 64, batteryLevel: 50,
    rarity: Rarity.r,
  ),
  EmulatedDeviceSpec(
    deviceName: 'Xperia 10 VI',
    osLabel: 'Android 14.0',
    osVersion: '14',
    cpuCores: 8, ramMB: 6144, storageFreeGB: 52, batteryLevel: 50,
    rarity: Rarity.r,
  ),
  EmulatedDeviceSpec(
    deviceName: 'OPPO Reno11 A',
    osLabel: 'Android 14.0',
    osVersion: '14',
    cpuCores: 8, ramMB: 8192, storageFreeGB: 60, batteryLevel: 50,
    rarity: Rarity.r,
  ),

  // ── SR ランク (4端末) ──
  EmulatedDeviceSpec(
    deviceName: 'Galaxy S25',
    osLabel: 'Android 15.0',
    osVersion: '15',
    cpuCores: 8, ramMB: 12288, storageFreeGB: 128, batteryLevel: 50,
    rarity: Rarity.sr,
  ),
  EmulatedDeviceSpec(
    deviceName: 'Pixel 9 Pro',
    osLabel: 'Android 15.0',
    osVersion: '15',
    cpuCores: 9, ramMB: 16384, storageFreeGB: 180, batteryLevel: 50,
    rarity: Rarity.sr,
  ),
  EmulatedDeviceSpec(
    deviceName: 'iPhone 16 Pro',
    osLabel: 'iOS 18.0',
    osVersion: '18',
    cpuCores: 6, ramMB: 8192, storageFreeGB: 200, batteryLevel: 50,
    rarity: Rarity.sr,
  ),
  EmulatedDeviceSpec(
    deviceName: 'Xperia 1 VII',
    osLabel: 'Android 15.0',
    osVersion: '15',
    cpuCores: 8, ramMB: 16384, storageFreeGB: 160, batteryLevel: 50,
    rarity: Rarity.sr,
  ),

  // ── SSR ランク (3端末) ──
  EmulatedDeviceSpec(
    deviceName: 'Galaxy S25 Ultra',
    osLabel: 'Android 15.0',
    osVersion: '15',
    cpuCores: 12, ramMB: 16384, storageFreeGB: 512, batteryLevel: 50,
    rarity: Rarity.ssr,
  ),
  EmulatedDeviceSpec(
    deviceName: 'iPhone 17 Pro Max',
    osLabel: 'iOS 19.0',
    osVersion: '19',
    cpuCores: 6, ramMB: 12288, storageFreeGB: 512, batteryLevel: 50,
    rarity: Rarity.ssr,
  ),
  EmulatedDeviceSpec(
    deviceName: 'ROG Phone 10 Pro',
    osLabel: 'Android 16.0',
    osVersion: '16',
    cpuCores: 12, ramMB: 24576, storageFreeGB: 512, batteryLevel: 50,
    rarity: Rarity.ssr,
  ),
];

/// レアリティでフィルタされたカタログを取得
List<EmulatedDeviceSpec> gachaDevicesByRarity(Rarity rarity) {
  return gachaDeviceCatalog.where((d) => d.rarity == rarity).toList();
}
