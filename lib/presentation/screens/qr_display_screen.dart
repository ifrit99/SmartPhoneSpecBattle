import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/device_info_service.dart';
import '../../domain/enums/element_type.dart';
import '../../domain/enums/rarity.dart';
import '../../domain/models/character.dart';
import '../../domain/services/character_generator.dart';
import '../../domain/services/service_locator.dart';
import '../theme/app_colors.dart';
import '../widgets/pixel_character.dart';

/// URL共有画面（自分のキャラクターの対戦URLを生成・コピー・シェアする）
class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  late Future<_SharePayload> _shareFuture;

  @override
  void initState() {
    super.initState();
    _shareFuture = _generateSharePayload();
  }

  Future<_SharePayload> _generateSharePayload() async {
    final sl = ServiceLocator();
    final equippedId = sl.storage.getEquippedGachaCharacterId();

    if (equippedId != null) {
      final equipped = sl.gachaService.findById(equippedId);
      if (equipped != null) {
        final encoded = sl.qrBattleService.encodeGachaCharacter(equipped);
        return _SharePayload(
          url: sl.qrBattleService.generateShareUrl(encoded),
          character: equipped.character,
          sourceLabel: '${equipped.rarity.label} / ${equipped.deviceName}',
        );
      }
    }

    // 実機キャラクターの場合
    final deviceInfo = DeviceInfoService();
    final specs = await deviceInfo.getDeviceSpecs();
    final exp = sl.experienceService.loadExperience();
    final character = CharacterGenerator.generate(specs, experience: exp);
    final encoded = sl.qrBattleService.encodePlayerCharacter(character);
    return _SharePayload(
      url: sl.qrBattleService.generateShareUrl(encoded),
      character: character,
      sourceLabel: '実機スペック',
    );
  }

  void _copyUrl(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('URLをコピーしました！')),
    );
  }

  void _shareUrl(String url) {
    // Web: テキストをコピーしつつ案内を表示
    Clipboard.setData(ClipboardData(text: 'SPEC BATTLEで対戦しよう！\n$url'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('共有テキストをコピーしました。SNS等に貼り付けてください！')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: const Text('対戦URLを共有'),
      ),
      body: FutureBuilder<_SharePayload>(
        future: _shareFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'エラーが発生しました: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final payload = snapshot.data!;
          final url = payload.url;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildShareCharacterCard(payload),
                  const SizedBox(height: 24),
                  const Text(
                    'このURLを友達に送って\n対戦しよう！',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // URL表示
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B2838),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: SelectableText(
                      url,
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // シェアボタン
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _shareUrl(url),
                      icon: const Icon(Icons.share, color: Colors.white),
                      label: const Text(
                        'シェアする',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.greenAccent.withValues(alpha: 0.3),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: Colors.greenAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // コピーボタン
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _copyUrl(url),
                      icon: const Icon(Icons.copy, color: Colors.white70),
                      label: const Text(
                        'URLをコピー',
                        style: TextStyle(color: Colors.white70),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShareCharacterCard(_SharePayload payload) {
    final character = payload.character;
    final elemColor = elementColor(character.element);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: elemColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: elemColor.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          PixelCharacter(character: character, size: 70),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  character.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _shareBadge(
                      elementName(character.element),
                      elemColor,
                    ),
                    _shareBadge('Lv.${character.level}', Colors.white70),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  payload.sourceLabel,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.ios_share, color: Colors.blueAccent),
        ],
      ),
    );
  }

  Widget _shareBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SharePayload {
  final String url;
  final Character character;
  final String sourceLabel;

  const _SharePayload({
    required this.url,
    required this.character,
    required this.sourceLabel,
  });
}
