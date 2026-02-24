import 'package:flutter/material.dart';
import '../../domain/models/gacha_character.dart';
import '../../domain/enums/rarity.dart';
import '../../data/local_storage_service.dart';
import '../../data/sound_service.dart';
import '../widgets/pixel_character.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late LocalStorageService _storage;
  List<GachaCharacter> _roster = [];
  String? _equippedId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    _storage = LocalStorageService();
    await _storage.init();
    
    final jsons = _storage.getGachaCharacters();
    final chars = jsons.map((j) => GachaCharacter.fromJsonString(j)).toList();
    
    // レアリティ降順、レベル降順でソート
    chars.sort((a, b) {
      final rCmp = b.rarity.sortOrder.compareTo(a.rarity.sortOrder);
      if (rCmp != 0) return rCmp;
      return b.character.level.compareTo(a.character.level);
    });

    if (!mounted) return;
    setState(() {
      _roster = chars;
      _equippedId = _storage.getEquippedGachaCharacterId();
      _loading = false;
    });
  }

  Future<void> _equipCharacter(GachaCharacter char) async {
    SoundService().playButton();
    await _storage.saveEquippedGachaCharacterId(char.id);
    setState(() {
      _equippedId = char.id;
    });
    // 装備完了のトースト等
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${char.deviceName} をメインキャラクターに設定しました')),
      );
      Navigator.of(context).pop(); // 詳細ダイアログを閉じる
    }
  }

  Future<void> _unequip() async {
    SoundService().playButton();
    await _storage.saveEquippedGachaCharacterId(null);
    setState(() {
      _equippedId = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('実機のスペックに戻しました')),
      );
    }
  }

  Color _getRarityColor(Rarity rarity) {
    switch (rarity) {
      case Rarity.n: return Colors.grey;
      case Rarity.r: return Colors.blueAccent;
      case Rarity.sr: return const Color(0xFFFFD700);
      case Rarity.ssr: return const Color(0xFFE056FD);
    }
  }

  void _showCharacterDetails(GachaCharacter char) {
    SoundService().playButton();
    final isEquipped = char.id == _equippedId;
    final rColor = _getRarityColor(char.rarity);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1B2838),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 16),
              PixelCharacter(character: char.character, size: 100),
              const SizedBox(height: 16),
              Text(
                char.deviceName,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Lv.${char.character.level}',
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statBadge('HP', char.character.baseStats.maxHp.toString()),
                  _statBadge('ATK', char.character.baseStats.atk.toString()),
                  _statBadge('DEF', char.character.baseStats.def.toString()),
                  _statBadge('SPD', char.character.baseStats.spd.toString()),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isEquipped ? null : () => _equipCharacter(char),
                  icon: Icon(isEquipped ? Icons.check_circle : Icons.person_add),
                  label: Text(
                    isEquipped ? '装備中' : 'このキャラクターで戦う',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEquipped ? Colors.green : const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _statBadge(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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
              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
              label: const Text('実機に戻す', style: TextStyle(color: Colors.redAccent)),
            ),
        ],
      ),
      body: _roster.isEmpty
          ? const Center(
              child: Text(
                'ガチャキャラクターがいません\nガチャを引いて獲得しましょう！',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 16, height: 1.5),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _roster.length,
              itemBuilder: (context, index) {
                final char = _roster[index];
                final rColor = _getRarityColor(char.rarity);
                final isEquipped = char.id == _equippedId;

                return GestureDetector(
                  onTap: () => _showCharacterDetails(char),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B2838),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isEquipped ? Colors.greenAccent : rColor.withValues(alpha: 0.5),
                        width: isEquipped ? 3 : 1,
                      ),
                      boxShadow: isEquipped
                          ? [const BoxShadow(color: Colors.greenAccent, blurRadius: 10)]
                          : [],
                    ),
                    child: Stack(
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              char.rarity.label,
                              style: TextStyle(color: rColor, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            PixelCharacter(character: char.character, size: 50),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                char.deviceName,
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (isEquipped)
                          const Positioned(
                            top: 4,
                            right: 4,
                            child: Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
