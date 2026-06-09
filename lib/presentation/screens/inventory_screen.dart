import 'package:flutter/material.dart';
import '../../domain/models/gacha_character.dart';
import '../../domain/enums/rarity.dart';
import '../../domain/services/service_locator.dart';
import '../../domain/services/roster_bonus_service.dart';
import '../theme/app_colors.dart';
import '../../data/sound_service.dart';
import '../widgets/pixel_character.dart';
import 'gacha_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _sl = ServiceLocator();
  List<GachaCharacter> _roster = [];
  String? _equippedId;
  Rarity? _rarityFilter;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    final chars = _sl.gachaService.loadRoster();

    // レアリティ降順、レベル降順でソート
    chars.sort((a, b) {
      final rCmp = b.rarity.sortOrder.compareTo(a.rarity.sortOrder);
      if (rCmp != 0) return rCmp;
      return b.character.level.compareTo(a.character.level);
    });

    setState(() {
      _roster = chars;
      _equippedId = _sl.storage.getEquippedGachaCharacterId();
      _loading = false;
    });
  }

  List<GachaCharacter> get _visibleRoster {
    final filter = _rarityFilter;
    if (filter == null) return _roster;
    return _roster.where((char) => char.rarity == filter).toList();
  }

  Future<void> _equipCharacter(GachaCharacter char) async {
    SoundService().playButton();
    await _sl.gachaService.equipCharacter(char.id);
    setState(() {
      _equippedId = char.id;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${char.deviceName} をメインキャラクターに設定しました')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _unequip() async {
    SoundService().playButton();
    await _sl.gachaService.equipCharacter(null);
    setState(() {
      _equippedId = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('実機のスペックに戻しました')),
      );
    }
  }

  Future<void> _openGacha() async {
    SoundService().playButton();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GachaScreen()),
    );
    if (mounted) {
      _initData();
    }
  }

  Color _getRarityColor(Rarity rarity) => rarityColor(rarity);

  void _showCharacterDetails(GachaCharacter char) {
    SoundService().playButton();
    final isEquipped = char.id == _equippedId;
    final rColor = _getRarityColor(char.rarity);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1B2838),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        char.rarity.label,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: rColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      if (char.awakeningLevel > 0) ...[
                        const SizedBox(width: 8),
                        _awakeningChip(char, rColor),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  PixelCharacter(character: char.character, size: 100),
                  const SizedBox(height: 16),
                  Text(
                    char.deviceName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lv.${char.character.level}  /  Power ${_powerScore(char)}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _expProgress(char),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _statBadge(
                          'HP', char.character.baseStats.maxHp.toString()),
                      _statBadge(
                          'ATK', char.character.baseStats.atk.toString()),
                      _statBadge(
                          'DEF', char.character.baseStats.def.toString()),
                      _statBadge(
                          'SPD', char.character.baseStats.spd.toString()),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          isEquipped ? null : () => _equipCharacter(char),
                      icon: Icon(
                          isEquipped ? Icons.check_circle : Icons.person_add),
                      label: Text(
                        isEquipped ? '装備中' : 'このキャラクターで戦う',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isEquipped ? Colors.green : const Color(0xFF6C5CE7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statBadge(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _expProgress(GachaCharacter char) {
    final exp = char.character.experience;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: exp.progressPercentage,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C5CE7)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'EXP ${exp.currentExp}/${exp.expToNext}',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1B2A),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: const Text('編成・インベントリ'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_equippedId != null)
            TextButton.icon(
              onPressed: _unequip,
              icon: const Icon(
                Icons.remove_circle_outline,
                color: Colors.redAccent,
              ),
              label: const Text(
                '実機に戻す',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
        ],
      ),
      body: _roster.isEmpty
          ? _buildEmptyState()
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      children: [
                        _buildRosterSummary(),
                        const SizedBox(height: 12),
                        _buildFilterBar(),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 150,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _visibleRoster.length,
                    itemBuilder: (context, index) {
                      final char = _visibleRoster[index];
                      return _buildRosterCard(char);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    final currency = _sl.currencyService.load();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFFE056FD)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE056FD).withValues(alpha: 0.22),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.group_add,
                color: Colors.white,
                size: 42,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'まだ編成できるキャラがいません',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'ガチャで端末キャラを獲得すると、実機スペックの代わりに装備してバトルやURL共有で使えます。',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 13,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _emptyCurrencyPill(
                    icon: '🪙',
                    label: '${currency.coins}',
                    color: const Color(0xFFFFD700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _emptyCurrencyPill(
                    icon: '💎',
                    label: '${currency.premiumGems}',
                    color: const Color(0xFFE056FD),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openGacha,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('ガチャで仲間を獲得'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              currency.coins >= 100 || currency.premiumGems >= 20
                  ? '今すぐ1回引けます'
                  : 'CPU戦でコイン、デイリー報酬でジェムを集めましょう',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _emptyCurrencyPill({
    required String icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRosterSummary() {
    final uniqueDevices = _roster.map((char) => char.deviceName).toSet().length;
    final ssrCount = _roster.where((char) => char.rarity == Rarity.ssr).length;
    final equipped = _equippedId == null
        ? null
        : _roster
            .where((char) => char.id == _equippedId)
            .cast<GachaCharacter?>()
            .firstOrNull;
    final bestPower = _roster.isEmpty
        ? 0
        : _roster.map(_powerScore).reduce((a, b) => a > b ? a : b);
    final rosterBonus = _sl.rosterBonusService.calculate(_roster);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2, color: Color(0xFF6C5CE7), size: 18),
              const SizedBox(width: 6),
              const Text(
                'ロスター分析',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                equipped == null ? '実機スペックで出撃中' : '${equipped.deviceName} 装備中',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child:
                    _summaryMetric('所持', '${_roster.length}', Colors.white70),
              ),
              const SizedBox(width: 8),
              Expanded(
                child:
                    _summaryMetric('端末種', '$uniqueDevices', Colors.blueAccent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child:
                    _summaryMetric('SSR', '$ssrCount', const Color(0xFFE056FD)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child:
                    _summaryMetric('最高PWR', '$bestPower', Colors.greenAccent),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRosterBonusPanel(rosterBonus),
        ],
      ),
    );
  }

  Widget _buildRosterBonusPanel(RosterBonusSummary summary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph, color: Color(0xFFFFD700), size: 17),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '収集ボーナス',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '+${summary.coinBonusPercent}% Coin',
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: summary.bonuses.map(_rosterBonusChip).toList(),
          ),
        ],
      ),
    );
  }

  Widget _rosterBonusChip(RosterBonusSnapshot bonus) {
    final color = bonus.unlocked ? const Color(0xFFFFD700) : Colors.white38;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            bonus.unlocked ? Icons.check_circle : Icons.lock,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            '${bonus.definition.title} +${bonus.definition.coinBonusPercent}%',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip(label: 'ALL', rarity: null),
          const SizedBox(width: 8),
          ...Rarity.values.reversed.map(
            (rarity) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _filterChip(label: rarity.label, rarity: rarity),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({required String label, required Rarity? rarity}) {
    final selected = _rarityFilter == rarity;
    final color = rarity == null ? Colors.white70 : _getRarityColor(rarity);
    final count = rarity == null
        ? _roster.length
        : _roster.where((c) => c.rarity == rarity).length;

    return ChoiceChip(
      selected: selected,
      label: Text('$label $count'),
      onSelected: (_) {
        setState(() {
          _rarityFilter = rarity;
        });
      },
      labelStyle: TextStyle(
        color: selected ? Colors.white : color,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      selectedColor: color.withValues(alpha: 0.28),
      backgroundColor: Colors.white.withValues(alpha: 0.04),
      side: BorderSide(color: color.withValues(alpha: selected ? 0.65 : 0.25)),
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildRosterCard(GachaCharacter char) {
    final rColor = _getRarityColor(char.rarity);
    final isEquipped = char.id == _equippedId;

    return GestureDetector(
      onTap: () => _showCharacterDetails(char),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1B2838),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isEquipped ? Colors.greenAccent : rColor.withValues(alpha: 0.5),
            width: isEquipped ? 3 : 1,
          ),
          boxShadow: isEquipped
              ? [
                  BoxShadow(
                    color: Colors.greenAccent.withValues(alpha: 0.28),
                    blurRadius: 12,
                  ),
                ]
              : [],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        constraints: const BoxConstraints(maxWidth: 72),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 3,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: rColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: rColor.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                char.rarity.label,
                                style: TextStyle(
                                  color: rColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            if (char.awakeningLevel > 0)
                              Text(
                                char.awakeningLabel,
                                style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Lv.${char.character.level}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  PixelCharacter(character: char.character, size: 52),
                  const SizedBox(height: 8),
                  Text(
                    char.deviceName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'PWR ${_powerScore(char)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isEquipped)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  Icons.check_circle,
                  color: Colors.greenAccent,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _powerScore(GachaCharacter char) {
    final stats = char.character.battleStats;
    return (stats.maxHp * 0.35 +
            stats.atk * 3.0 +
            stats.def * 2.1 +
            stats.spd * 1.6)
        .round();
  }

  Widget _awakeningChip(GachaCharacter char, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '覚醒 ${char.awakeningLabel}',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
