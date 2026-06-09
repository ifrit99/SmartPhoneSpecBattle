import '../../data/local_storage_service.dart';
import '../data/gacha_device_catalog.dart';
import '../enums/rarity.dart';
import '../models/gacha_character.dart';

enum RosterBonusMetric {
  uniqueDevices,
  ssrOwned,
  limitedOwned,
  awakeningTotal,
}

class RosterBonusDefinition {
  final String id;
  final String title;
  final String description;
  final RosterBonusMetric metric;
  final int target;
  final int coinBonusPercent;

  const RosterBonusDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.metric,
    required this.target,
    required this.coinBonusPercent,
  });
}

class RosterBonusSnapshot {
  final RosterBonusDefinition definition;
  final int current;

  const RosterBonusSnapshot({
    required this.definition,
    required this.current,
  });

  bool get unlocked => current >= definition.target;
  double get progress => (current / definition.target).clamp(0.0, 1.0);
}

class RosterBonusSummary {
  final int rosterCount;
  final int uniqueDevices;
  final int ssrOwned;
  final int limitedOwned;
  final int awakeningTotal;
  final List<RosterBonusSnapshot> bonuses;

  const RosterBonusSummary({
    required this.rosterCount,
    required this.uniqueDevices,
    required this.ssrOwned,
    required this.limitedOwned,
    required this.awakeningTotal,
    required this.bonuses,
  });

  int get unlockedCount => bonuses.where((bonus) => bonus.unlocked).length;

  int get coinBonusPercent => bonuses
      .where((bonus) => bonus.unlocked)
      .fold<int>(0, (total, bonus) => total + bonus.definition.coinBonusPercent)
      .clamp(0, RosterBonusService.maxCoinBonusPercent)
      .toInt();

  double get coinMultiplier => 1 + coinBonusPercent / 100;
}

class RosterBonusService {
  static const int maxCoinBonusPercent = 20;

  static const List<RosterBonusDefinition> definitions = [
    RosterBonusDefinition(
      id: 'unique_3',
      title: '端末研究 I',
      description: '異なる端末を3種集める',
      metric: RosterBonusMetric.uniqueDevices,
      target: 3,
      coinBonusPercent: 3,
    ),
    RosterBonusDefinition(
      id: 'unique_8',
      title: '端末研究 II',
      description: '異なる端末を8種集める',
      metric: RosterBonusMetric.uniqueDevices,
      target: 8,
      coinBonusPercent: 5,
    ),
    RosterBonusDefinition(
      id: 'ssr_1',
      title: '旗艦機解析',
      description: 'SSR端末を1体入手する',
      metric: RosterBonusMetric.ssrOwned,
      target: 1,
      coinBonusPercent: 4,
    ),
    RosterBonusDefinition(
      id: 'limited_1',
      title: '限定端末研究',
      description: 'イベント限定端末を1体入手する',
      metric: RosterBonusMetric.limitedOwned,
      target: 1,
      coinBonusPercent: 5,
    ),
    RosterBonusDefinition(
      id: 'awakening_3',
      title: '覚醒チューニング',
      description: '覚醒レベル合計を3以上にする',
      metric: RosterBonusMetric.awakeningTotal,
      target: 3,
      coinBonusPercent: 3,
    ),
  ];

  final LocalStorageService _storage;

  RosterBonusService(this._storage);

  RosterBonusSummary loadSummary() {
    return calculate(_storage.getGachaCharacters().map(_decode).toList());
  }

  RosterBonusSummary calculate(List<GachaCharacter> roster) {
    final limitedNames =
        eventLimitedDeviceCatalog.map((device) => device.deviceName).toSet();
    final uniqueDevices = roster.map((char) => char.deviceName).toSet().length;
    final ssrOwned = roster.where((char) => char.rarity == Rarity.ssr).length;
    final limitedOwned = roster
        .where((char) => limitedNames.contains(char.deviceName))
        .map((char) => char.deviceName)
        .toSet()
        .length;
    final awakeningTotal =
        roster.fold<int>(0, (total, char) => total + char.awakeningLevel);

    return RosterBonusSummary(
      rosterCount: roster.length,
      uniqueDevices: uniqueDevices,
      ssrOwned: ssrOwned,
      limitedOwned: limitedOwned,
      awakeningTotal: awakeningTotal,
      bonuses: definitions
          .map(
            (definition) => RosterBonusSnapshot(
              definition: definition,
              current: _metricValue(
                definition.metric,
                uniqueDevices: uniqueDevices,
                ssrOwned: ssrOwned,
                limitedOwned: limitedOwned,
                awakeningTotal: awakeningTotal,
              ),
            ),
          )
          .toList(),
    );
  }

  int _metricValue(
    RosterBonusMetric metric, {
    required int uniqueDevices,
    required int ssrOwned,
    required int limitedOwned,
    required int awakeningTotal,
  }) {
    return switch (metric) {
      RosterBonusMetric.uniqueDevices => uniqueDevices,
      RosterBonusMetric.ssrOwned => ssrOwned,
      RosterBonusMetric.limitedOwned => limitedOwned,
      RosterBonusMetric.awakeningTotal => awakeningTotal,
    };
  }

  GachaCharacter _decode(String raw) => GachaCharacter.fromJsonString(raw);
}
