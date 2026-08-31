import 'package:flutter/material.dart';

import '../domain/services/service_locator.dart';
import 'screens/qr_guest_preview_screen.dart';
import 'screens/qr_scan_screen.dart';
import 'widgets/analytics_consent_dialog.dart';

/// `?battle=` 直リンクを同意ゲート通過後にデコードする（§2-3 #9 / §3-2）。
///
/// 生パラメータは呼び出し側が保持したまま渡す。失敗時は理由別エラーと
/// URL入力画面への導線をゲストプレビュー上に表示する。
Future<void> openBattleDeepLink(
  BuildContext context,
  String battleParam,
) async {
  await ensureAnalyticsConsent(context);
  if (!context.mounted) return;

  try {
    final guest = ServiceLocator().qrBattleService.decodeAsGuest(battleParam);
    await ServiceLocator().analyticsService.logEvent(
      'share_url_opened',
      params: {
        'source': 'direct_link',
        'is_gacha': guest.isGacha,
      },
    );
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QrGuestPreviewScreen(guest: guest),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (previewContext) => QrGuestPreviewScreen(
          decodeError: e,
          onOpenUrlInput: () {
            Navigator.of(previewContext).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const UrlInputScreen(),
              ),
            );
          },
        ),
      ),
    );
  }
}
