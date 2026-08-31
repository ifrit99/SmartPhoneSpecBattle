import '../domain/services/character_codec.dart';

/// デコード/復元失敗の種別（§2-3 の形式不正 / チェックサム・改ざん検知）。
enum DecodeFailureKind { format, integrity }

DecodeFailureKind classifyDecodeFailure(Object error) {
  if (error is IntegrityException) return DecodeFailureKind.integrity;
  return DecodeFailureKind.format;
}

/// URL対戦デコード失敗の表示文言（§2-3 #5 / #6 / #9）。
class BattleDecodeFailureCopy {
  /// #5 URL入力のインライン文言。
  static String urlInputMessage(Object error) {
    return switch (classifyDecodeFailure(error)) {
      DecodeFailureKind.format => '形式不正',
      DecodeFailureKind.integrity => 'チェックサム不一致',
    };
  }

  /// #6 / #9 ゲストプレビュー・直リンクの見出し。
  static String previewTitle(Object error) {
    return switch (classifyDecodeFailure(error)) {
      DecodeFailureKind.format => '形式不正',
      DecodeFailureKind.integrity => '改ざん検知',
    };
  }
}

/// バックアップ復元失敗の表示文言（§2-3 #7。チェックサムは F5 連動）。
class BackupRestoreFailureCopy {
  static String title(Object error) {
    return switch (classifyDecodeFailure(error)) {
      DecodeFailureKind.format => '形式',
      DecodeFailureKind.integrity => 'コードが破損しています',
    };
  }

  static const retryHint = 'コード全体をコピーし直してください';
}
