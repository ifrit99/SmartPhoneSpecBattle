import 'dart:math';
import 'package:flutter/material.dart';
import '../../domain/enums/rarity.dart';
import '../../domain/models/gacha_character.dart';
import '../theme/app_colors.dart';
import '../../domain/models/player_currency.dart';
import '../../domain/services/gacha_service.dart';
import '../../domain/services/service_locator.dart';
import '../../data/sound_service.dart';
import '../widgets/pixel_character.dart';

class GachaScreen extends StatefulWidget {
  const GachaScreen({super.key});

  @override
  State<GachaScreen> createState() => _GachaScreenState();
}

class _GachaScreenState extends State<GachaScreen>
    with TickerProviderStateMixin {
  final _sl = ServiceLocator();
  GachaService get _gachaService => _sl.gachaService;
  String get _featuredDeviceName => _gachaService.todayFeaturedSsr.deviceName;
  String get _eventLimitedDeviceName =>
      _gachaService.currentEventLimitedSsr.deviceName;
  String get _premiumPityLabel => _gachaService.isNextPremiumFeaturedGuaranteed
      ? '次回ピックアップSSR確定'
      : 'ピックアップ天井まであと${_gachaService.premiumFeaturedPullsUntilGuarantee}回';
  String get _eventLimitedPityLabel =>
      _gachaService.isNextEventLimitedGuaranteed
          ? '次回イベント限定SSR確定'
          : '限定天井まであと${_gachaService.eventLimitedPullsUntilGuarantee}回';
  int _currentCoins = 0;
  int _currentGems = 0;
  bool _isPulling = false;

  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _refreshCurrency();
  }

  void _refreshCurrency() {
    if (!mounted) return;
    final currency = _sl.currencyService.load();
    setState(() {
      _currentCoins = currency.coins;
      _currentGems = currency.premiumGems;
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Color _getRarityColor(Rarity rarity) => rarityColor(rarity);

  /// 単発ガチャを実行
  Future<void> _pullSingle() async {
    if (_currentCoins < PlayerCurrency.singlePullCost) {
      _showInsufficientCurrency(
        label: 'コイン',
        unit: 'Coin',
        current: _currentCoins,
        required: PlayerCurrency.singlePullCost,
        hint: 'CPU戦やミッションで集めましょう',
      );
      return;
    }
    await _executePull(() => _gachaService.pullSingle());
  }

  /// 10連ガチャを実行
  Future<void> _pullTen() async {
    if (_currentCoins < PlayerCurrency.tenPullCost) {
      _showInsufficientCurrency(
        label: 'コイン',
        unit: 'Coin',
        current: _currentCoins,
        required: PlayerCurrency.tenPullCost,
        hint: 'CPU戦や週次報酬で集めましょう',
      );
      return;
    }
    await _executePull(() => _gachaService.pullTen());
  }

  /// プレミアム解析ガチャを実行
  Future<void> _pullPremium() async {
    if (_currentGems < PlayerCurrency.premiumPullCost) {
      _showInsufficientCurrency(
        label: 'ジェム',
        unit: 'Gems',
        current: _currentGems,
        required: PlayerCurrency.premiumPullCost,
        hint: 'ログイン報酬やCPUバトル報酬で集めましょう',
      );
      return;
    }
    await _executePull(() => _gachaService.pullPremium());
  }

  /// 期間限定イベント解析ガチャを実行
  Future<void> _pullEventLimited() async {
    if (_currentGems < PlayerCurrency.eventLimitedPullCost) {
      _showInsufficientCurrency(
        label: 'ジェム',
        unit: 'Gems',
        current: _currentGems,
        required: PlayerCurrency.eventLimitedPullCost,
        hint: 'ログイン報酬やイベント報酬で集めましょう',
      );
      return;
    }
    await _executePull(() => _gachaService.pullEventLimited());
  }

  void _showInsufficientCurrency({
    required String label,
    required String unit,
    required int current,
    required int required,
    required String hint,
  }) {
    final shortage = (required - current).clamp(0, required);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$labelが足りません: あと$shortage $unit。$hint'),
      ),
    );
    SoundService().playButton();
  }

  Future<void> _equipFromResult(
    BuildContext dialogContext,
    GachaCharacter char,
  ) async {
    SoundService().playButton();
    await _gachaService.equipCharacter(char.id);
    if (!mounted) return;

    Navigator.of(dialogContext).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${char.deviceName} をメインキャラクターに設定しました')),
    );
  }

  GachaCharacter _recommendedEquipTarget(List<GachaCharacter> characters) {
    return characters.reduce((best, current) {
      final rarityCmp =
          current.rarity.sortOrder.compareTo(best.rarity.sortOrder);
      if (rarityCmp > 0) return current;
      if (rarityCmp < 0) return best;
      return _powerScore(current) > _powerScore(best) ? current : best;
    });
  }

  int _powerScore(GachaCharacter char) {
    final stats = char.character.battleStats;
    return (stats.maxHp * 0.35 +
            stats.atk * 3.0 +
            stats.def * 2.1 +
            stats.spd * 1.6)
        .round();
  }

  /// ガチャ演出と結果表示の共通処理
  Future<void> _executePull(Future<GachaResult?> Function() pullFn) async {
    setState(() => _isPulling = true);

    // 演出開始
    SoundService().playButton();
    for (int i = 0; i < 15; i++) {
      _shakeController.forward(from: 0.0);
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // 抽選実行
    final result = await pullFn();
    _refreshCurrency();

    SoundService().playSkill();
    if (!mounted) return;
    setState(() => _isPulling = false);

    if (result == null) return;

    // 結果表示
    if (result.characters.length == 1) {
      _showResultDialog(
        result.characters.first,
        duplicateUpgrades: result.duplicateUpgrades,
        duplicateRefundCoins: result.duplicateRefundCoins,
      );
    } else {
      _showMultiResultDialog(
        result.characters,
        duplicateUpgrades: result.duplicateUpgrades,
        duplicateRefundCoins: result.duplicateRefundCoins,
      );
    }
  }

  void _showResultDialog(
    GachaCharacter char, {
    int duplicateUpgrades = 0,
    int duplicateRefundCoins = 0,
  }) {
    final rColor = _getRarityColor(char.rarity);
    final awakened = duplicateUpgrades > 0;
    final refunded = duplicateRefundCoins > 0;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'GachaResult',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ScaleTransition(
              scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
              child: Container(
                width: MediaQuery.sizeOf(context).width * 0.85,
                constraints: const BoxConstraints(maxWidth: 340),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2838),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: rColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                        color: rColor.withValues(alpha: 0.5), blurRadius: 30),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      char.rarity.label,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: rColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    if (awakened) ...[
                      const SizedBox(height: 8),
                      _awakeningBadge(
                        '重複覚醒 ${char.awakeningLabel}',
                        rColor,
                      ),
                    ],
                    if (refunded) ...[
                      const SizedBox(height: 8),
                      _awakeningBadge(
                        '上限到達補填 +$duplicateRefundCoins Coin',
                        const Color(0xFFFFD700),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white12),
                      ),
                      child:
                          PixelCharacter(character: char.character, size: 80),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      char.deviceName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'HP: ${char.character.baseStats.maxHp}   ATK: ${char.character.baseStats.atk}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (awakened) ...[
                      const SizedBox(height: 8),
                      const Text(
                        '所持済み端末を強化しました',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    if (refunded) ...[
                      const SizedBox(height: 8),
                      const Text(
                        '覚醒上限のためコインに変換しました',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _equipFromResult(context, char),
                        icon: const Icon(Icons.person_add),
                        label: const Text('このキャラで戦う'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: rColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('閉じる',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 10連ガチャの結果一覧ダイアログ
  void _showMultiResultDialog(
    List<GachaCharacter> characters, {
    int duplicateUpgrades = 0,
    int duplicateRefundCoins = 0,
  }) {
    // 最高レアリティの色でダイアログの枠を装飾
    final bestRarity = characters
        .map((c) => c.rarity)
        .reduce((a, b) => a.sortOrder > b.sortOrder ? a : b);
    final borderColor = _getRarityColor(bestRarity);
    final recommended = _recommendedEquipTarget(characters);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'GachaMultiResult',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ScaleTransition(
              scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
              child: Container(
                width: MediaQuery.sizeOf(context).width * 0.9,
                constraints:
                    const BoxConstraints(maxWidth: 380, maxHeight: 520),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2838),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                        color: borderColor.withValues(alpha: 0.5),
                        blurRadius: 30),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '10連ガチャ結果',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (duplicateUpgrades > 0) ...[
                      const SizedBox(height: 8),
                      _awakeningBadge('重複覚醒 +$duplicateUpgrades', borderColor),
                    ],
                    if (duplicateRefundCoins > 0) ...[
                      const SizedBox(height: 8),
                      _awakeningBadge(
                        '上限到達補填 +$duplicateRefundCoins Coin',
                        const Color(0xFFFFD700),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: characters.length,
                        separatorBuilder: (_, __) => const Divider(
                          color: Colors.white12,
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final c = characters[index];
                          final rColor = _getRarityColor(c.rarity);
                          return ListTile(
                            dense: true,
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                shape: BoxShape.circle,
                                border: Border.all(color: rColor, width: 2),
                              ),
                              child: Center(
                                child: PixelCharacter(
                                    character: c.character, size: 28),
                              ),
                            ),
                            title: Text(
                              c.deviceName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: Container(
                              constraints: const BoxConstraints(minWidth: 48),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: rColor.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border:
                                          Border.all(color: rColor, width: 1),
                                    ),
                                    child: Text(
                                      c.rarity.label,
                                      style: TextStyle(
                                        color: rColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  if (c.awakeningLevel > 0) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      c.awakeningLabel,
                                      style: const TextStyle(
                                        color: Color(0xFFFFD700),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: borderColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: borderColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.recommend, color: borderColor, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'おすすめ: ${recommended.deviceName}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'PWR ${_powerScore(recommended)}',
                            style: TextStyle(
                              color: borderColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _equipFromResult(context, recommended),
                        icon: const Icon(Icons.person_add),
                        label: const Text('おすすめを装備'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: borderColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '閉じる',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _awakeningBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_fix_high, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('ガチャ'),
        actions: [
          Center(
            child: _currencyPill(
              '🪙',
              _currentCoins,
              const Color(0xFFFFD700),
            ),
          ),
          const SizedBox(width: 8),
          Center(
            child: _currencyPill(
              '💎',
              _currentGems,
              const Color(0xFFE056FD),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ガチャ機体のようなUI
              LayoutBuilder(
                builder: (context, constraints) {
                  final orbSize =
                      (constraints.maxWidth * 0.45).clamp(120.0, 220.0);
                  final iconSize = orbSize * 0.4;
                  return AnimatedBuilder(
                    animation: _shakeController,
                    builder: (context, child) {
                      final offset = sin(_shakeController.value * pi * 4) * 8;
                      return Transform.translate(
                        offset: Offset(offset, 0),
                        child: Container(
                          width: orbSize,
                          height: orbSize,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D3748),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: _isPulling
                                    ? const Color(0xFFFFD700)
                                        .withValues(alpha: 0.3)
                                    : Colors.transparent,
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.memory,
                              size: iconSize,
                              color: _isPulling
                                  ? const Color(0xFFFFD700)
                                  : Colors.white54,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 40),

              // 提供割合
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  children: [
                    Text('確率: ', style: TextStyle(color: Colors.white54)),
                    Text('N 60% ', style: TextStyle(color: Colors.grey)),
                    Text('R 25% ', style: TextStyle(color: Colors.blueAccent)),
                    Text('SR 10% ', style: TextStyle(color: Color(0xFFFFD700))),
                    Text('SSR 5%', style: TextStyle(color: Color(0xFFE056FD))),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE056FD).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE056FD).withValues(alpha: 0.28),
                  ),
                ),
                child: Text(
                  'プレミアム解析: SR以上確定 / SSR 33%\nSSR時: $_featuredDeviceName 60%\n$_premiumPityLabel',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFEFB6FF),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF55EFC4).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF55EFC4).withValues(alpha: 0.28),
                  ),
                ),
                child: Text(
                  'イベント解析: SR以上確定 / 限定SSR 25%\n限定: $_eventLimitedDeviceName\n$_eventLimitedPityLabel',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFA6F7DF),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ボタン群
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  // 単発ガチャボタン
                  ElevatedButton(
                    onPressed: _isPulling ? null : _pullSingle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '1回引く',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '🪙 100',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 10連ガチャボタン
                  ElevatedButton(
                    onPressed: _isPulling ? null : _pullTen,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE056FD),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '10連',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '🪙 900',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _isPulling ? null : _pullPremium,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB832E6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'プレミアム解析',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '💎 20',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _isPulling ? null : _pullEventLimited,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B894),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'イベント解析',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '💎 30',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '※10連はSR以上1枚確定\n今日のピックアップ: $_featuredDeviceName\nイベント限定: $_eventLimitedDeviceName',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _currencyPill(String icon, int amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Text('$icon ', style: const TextStyle(fontSize: 14)),
          Text(
            '$amount',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
