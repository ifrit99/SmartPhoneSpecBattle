import 'dart:math';
import 'package:flutter/material.dart';
import '../../domain/enums/rarity.dart';
import '../../domain/models/gacha_character.dart';
import '../../domain/models/player_currency.dart';
import '../../domain/services/gacha_service.dart';
import '../../domain/services/currency_service.dart';
import '../../data/local_storage_service.dart';
import '../../data/sound_service.dart';
import '../widgets/pixel_character.dart';

class GachaScreen extends StatefulWidget {
  const GachaScreen({super.key});

  @override
  State<GachaScreen> createState() => _GachaScreenState();
}

class _GachaScreenState extends State<GachaScreen> with TickerProviderStateMixin {
  late LocalStorageService _storage;
  late GachaService _gachaService;
  int _currentCoins = 0;
  bool _isPulling = false;

  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _initServices();
  }

  Future<void> _initServices() async {
    _storage = LocalStorageService();
    await _storage.init();
    final currencyService = CurrencyService(_storage);
    _gachaService = GachaService(currencyService, _storage);
    _refreshCoins();
  }

  void _refreshCoins() {
    setState(() {
      _currentCoins = _storage.getCoins();
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Color _getRarityColor(Rarity rarity) {
    switch (rarity) {
      case Rarity.n: return Colors.grey;
      case Rarity.r: return Colors.blueAccent;
      case Rarity.sr: return const Color(0xFFFFD700);
      case Rarity.ssr: return const Color(0xFFE056FD);
    }
  }

  /// 単発ガチャを実行
  Future<void> _pullSingle() async {
    if (_currentCoins < PlayerCurrency.singlePullCost) {
      _showInsufficientCoins();
      return;
    }
    await _executePull(() => _gachaService.pullSingle());
  }

  /// 10連ガチャを実行
  Future<void> _pullTen() async {
    if (_currentCoins < PlayerCurrency.tenPullCost) {
      _showInsufficientCoins();
      return;
    }
    await _executePull(() => _gachaService.pullTen());
  }

  void _showInsufficientCoins() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('コインが足りません！')),
    );
    SoundService().playButton();
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
    _refreshCoins();

    SoundService().playSkill();
    setState(() => _isPulling = false);

    if (result == null || !mounted) return;

    // 結果表示
    if (result.characters.length == 1) {
      _showResultDialog(result.characters.first);
    } else {
      _showMultiResultDialog(result.characters);
    }
  }

  void _showResultDialog(GachaCharacter char) {
    final rColor = _getRarityColor(char.rarity);
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
                width: 300,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2838),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: rColor, width: 3),
                  boxShadow: [
                    BoxShadow(color: rColor.withValues(alpha: 0.5), blurRadius: 30),
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
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white12),
                      ),
                      child: PixelCharacter(character: char.character, size: 80),
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
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'HP: ${char.character.baseStats.maxHp}   ATK: ${char.character.baseStats.atk}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: rColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
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
  void _showMultiResultDialog(List<GachaCharacter> characters) {
    // 最高レアリティの色でダイアログの枠を装飾
    final bestRarity = characters
        .map((c) => c.rarity)
        .reduce((a, b) => a.sortOrder > b.sortOrder ? a : b);
    final borderColor = _getRarityColor(bestRarity);

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
                width: 340,
                constraints: const BoxConstraints(maxHeight: 520),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2838),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor, width: 3),
                  boxShadow: [
                    BoxShadow(color: borderColor.withValues(alpha: 0.5), blurRadius: 30),
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
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: characters.length,
                        separatorBuilder: (_, __) => const Divider(
                          color: Colors.white12, height: 1,
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
                                child: PixelCharacter(character: c.character, size: 28),
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: rColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: rColor, width: 1),
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
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: borderColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('エミュレートガチャ'),
        actions: [
          Center(
            child: Padding(
               padding: const EdgeInsets.only(right: 16),
               child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                 decoration: BoxDecoration(
                   color: Colors.black45,
                   borderRadius: BorderRadius.circular(16),
                   border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
                 ),
                 child: Row(
                   children: [
                     const Text('🪙 ', style: TextStyle(fontSize: 14)),
                     Text(
                       '$_currentCoins',
                       style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                     ),
                   ],
                 ),
               ),
            ),
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ガチャ機体のようなUI
            AnimatedBuilder(
              animation: _shakeController,
              builder: (context, child) {
                final offset = sin(_shakeController.value * pi * 4) * 8;
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D3748),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: _isPulling ? const Color(0xFFFFD700).withValues(alpha: 0.3) : Colors.transparent,
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.memory,
                        size: 80,
                        color: _isPulling ? const Color(0xFFFFD700) : Colors.white54,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 60),

            // 提供割合
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('確率: ', style: TextStyle(color: Colors.white54)),
                  Text('N 60% ', style: TextStyle(color: Colors.grey)),
                  Text('R 25% ', style: TextStyle(color: Colors.blueAccent)),
                  Text('SR 10% ', style: TextStyle(color: Color(0xFFFFD700))),
                  Text('SSR 5%', style: TextStyle(color: Color(0xFFE056FD))),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ボタン群
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 単発ガチャボタン
                ElevatedButton(
                  onPressed: _isPulling ? null : _pullSingle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                const SizedBox(width: 16),
                // 10連ガチャボタン
                ElevatedButton(
                  onPressed: _isPulling ? null : _pullTen,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE056FD),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '※10連はSR以上1枚確定',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
