import 'package:flutter/material.dart';
import '../../domain/models/character.dart';
import '../../domain/services/qr_battle_service.dart';
import '../../domain/services/service_locator.dart';
import '../../domain/services/character_generator.dart';
import '../../data/device_info_service.dart';
import '../../data/sound_service.dart';
import '../../domain/enums/element_type.dart';
import '../theme/app_colors.dart';
import '../widgets/pixel_character.dart';
import '../widgets/stat_bar.dart';
import 'battle_screen.dart';
import 'gacha_screen.dart';
import 'qr_menu_screen.dart';

/// URLから読み取ったゲストキャラクターのプレビュー画面
class QrGuestPreviewScreen extends StatefulWidget {
  final QrBattleGuest guest;

  const QrGuestPreviewScreen({super.key, required this.guest});

  @override
  State<QrGuestPreviewScreen> createState() => _QrGuestPreviewScreenState();
}

class _QrGuestPreviewScreenState extends State<QrGuestPreviewScreen> {
  bool _loading = false;

  void _startBattle() async {
    setState(() => _loading = true);
    SoundService().playButton();

    final player = await _getEquippedPlayer();

    if (!mounted) return;
    setState(() => _loading = false);

    final nextAction = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (context) => BattleScreen(
          player: player,
          enemy: widget.guest.battleCharacter,
          enemyDeviceName: widget.guest.deviceName ?? 'フレンドの端末',
        ),
      ),
    );

    if (!mounted) return;

    // 初回バトル後の案内アクションを処理
    if (nextAction == 'gacha') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const GachaScreen()),
      );
    } else if (nextAction == 'friend') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const FriendBattleMenuScreen()),
      );
    } else {
      // 通常のバトル終了：プレビュー画面を閉じて前の画面に戻る
      Navigator.of(context).pop();
    }
  }

  Future<Character> _getEquippedPlayer() async {
    final sl = ServiceLocator();
    final equippedId = sl.storage.getEquippedGachaCharacterId();

    if (equippedId != null) {
      final equipped = sl.gachaService.findById(equippedId);
      if (equipped != null) {
        return equipped.character;
      }
    }

    // ガチャキャラ未装備の場合は実機スペックからキャラ生成
    final deviceInfo = DeviceInfoService();
    final specs = await deviceInfo.getDeviceSpecs();
    final exp = sl.experienceService.loadExperience();
    return CharacterGenerator.generate(specs, experience: exp);
  }

  @override
  Widget build(BuildContext context) {
    final enemy = widget.guest.battleCharacter;
    final elemColor = elementColor(enemy.element);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(title: const Text('ゲストプレビュー')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ゲスト情報ラベル
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: elemColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: elemColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  widget.guest.displayLabel,
                  style: TextStyle(color: elemColor, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),

              // キャラクター表示
              PixelCharacter(
                character: enemy,
                size: 120,
                flipHorizontal: true,
              ),
              const SizedBox(height: 16),

              // 名前・属性
              Text(
                enemy.name,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: elemColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: elemColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      elementName(enemy.element),
                      style: TextStyle(color: elemColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Lv.${enemy.level}', style: const TextStyle(color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 24),

              // ステータスバー
              SizedBox(
                width: 240,
                child: Column(
                  children: [
                    StatBar(label: 'HP', value: 1.0, color: Colors.greenAccent, trailingText: '${enemy.currentStats.hp}', height: 8),
                    StatBar(label: 'ATK', value: enemy.currentStats.atk / 150, color: Colors.redAccent, trailingText: '${enemy.currentStats.atk}', height: 8),
                    StatBar(label: 'DEF', value: enemy.currentStats.def / 150, color: Colors.blueAccent, trailingText: '${enemy.currentStats.def}', height: 8),
                    StatBar(label: 'SPD', value: enemy.currentStats.spd / 150, color: Colors.amberAccent, trailingText: '${enemy.currentStats.spd}', height: 8),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // バトル開始ボタン
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _startBattle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 6,
                  ),
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('バトル開始！', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),

              // キャンセルボタン
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('キャンセル', style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
