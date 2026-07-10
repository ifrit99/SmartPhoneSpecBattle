import 'package:flutter/material.dart';

import '../../domain/services/analytics_service.dart';
import '../../domain/services/service_locator.dart';

class AnalyticsConsentDialog extends StatelessWidget {
  final Future<void> Function(AnalyticsConsent consent) onSelected;

  const AnalyticsConsentDialog({
    super.key,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B2838),
      title: const Text(
        'プレイデータ送信へのご協力',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: const Text(
        'ゲーム改善のため、匿名のプレイデータとエラー情報の送信にご協力ください。個人を特定する情報は送信しません。拒否してもすべての機能を遊べます。設定はPrivacyからいつでも変更できます。',
        style: TextStyle(color: Colors.white70, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => _select(context, AnalyticsConsent.denied),
          child: const Text('協力しない'),
        ),
        ElevatedButton(
          onPressed: () => _select(context, AnalyticsConsent.granted),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00B894),
            foregroundColor: Colors.black,
          ),
          child: const Text('協力する'),
        ),
      ],
    );
  }

  Future<void> _select(BuildContext context, AnalyticsConsent consent) async {
    await onSelected(consent);
    if (context.mounted) {
      Navigator.of(context).pop(consent);
    }
  }
}

Future<AnalyticsConsent> ensureAnalyticsConsent(BuildContext context) async {
  final analytics = ServiceLocator().analyticsService;
  if (analytics.consent != AnalyticsConsent.unanswered) {
    return analytics.consent;
  }

  final selected = await showDialog<AnalyticsConsent>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AnalyticsConsentDialog(
      onSelected: analytics.setConsent,
    ),
  );
  return selected ?? analytics.consent;
}
