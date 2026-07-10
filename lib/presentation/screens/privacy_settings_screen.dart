import 'package:flutter/material.dart';

import '../../domain/services/analytics_service.dart';
import '../../domain/services/service_locator.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final _analytics = ServiceLocator().analyticsService;
  late AnalyticsConsent _consent;

  @override
  void initState() {
    super.initState();
    _consent = _analytics.consent;
  }

  Future<void> _setConsent(AnalyticsConsent consent) async {
    await _analytics.setConsent(consent);
    if (!mounted) return;
    setState(() => _consent = consent);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Privacy設定を保存しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final granted = _consent == AnalyticsConsent.granted;
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Privacy'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2838),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '匿名プレイデータ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'バトル、ガチャ、共有、バックアップなどの利用状況とエラー情報を、ゲーム改善のために送信します。個人を特定する情報は送信しません。',
                    style: TextStyle(color: Colors.white60, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: granted,
                      activeThumbColor: const Color(0xFF00B894),
                      title: Text(
                        granted ? '送信する' : '送信しない',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        granted ? 'Analytics収集は有効です' : 'Analytics収集は停止しています',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      onChanged: (value) => _setConsent(
                        value
                            ? AnalyticsConsent.granted
                            : AnalyticsConsent.denied,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
