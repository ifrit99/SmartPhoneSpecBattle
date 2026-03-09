import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/device_info_service.dart';
import '../../domain/services/character_generator.dart';
import '../../domain/services/service_locator.dart';

/// URL共有画面（自分のキャラクターの対戦URLを生成・コピー・シェアする）
class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  late Future<String> _urlFuture;

  @override
  void initState() {
    super.initState();
    _urlFuture = _generateShareUrl();
  }

  Future<String> _generateShareUrl() async {
    final sl = ServiceLocator();
    final equippedId = sl.storage.getEquippedGachaCharacterId();

    String encoded;
    if (equippedId != null) {
      final equipped = sl.gachaService.findById(equippedId);
      if (equipped != null) {
        encoded = sl.qrBattleService.encodeGachaCharacter(equipped);
        return sl.qrBattleService.generateShareUrl(encoded);
      }
    }

    // 実機キャラクターの場合
    final deviceInfo = DeviceInfoService();
    final specs = await deviceInfo.getDeviceSpecs();
    final batterySpecs = specs.withBattery(100);
    final exp = sl.experienceService.loadExperience();
    final character = CharacterGenerator.generate(batterySpecs, experience: exp);
    encoded = sl.qrBattleService.encodePlayerCharacter(character);
    return sl.qrBattleService.generateShareUrl(encoded);
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
      body: FutureBuilder<String>(
        future: _urlFuture,
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

          final url = snapshot.data!;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.share, size: 64, color: Colors.blueAccent),
                  const SizedBox(height: 16),
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
                        backgroundColor: Colors.greenAccent.withValues(alpha: 0.3),
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
}
