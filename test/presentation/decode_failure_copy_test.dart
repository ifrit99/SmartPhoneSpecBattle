import 'package:flutter_test/flutter_test.dart';

import 'package:spec_battle_game/domain/services/character_codec.dart';
import 'package:spec_battle_game/presentation/decode_failure_copy.dart';

void main() {
  group('BattleDecodeFailureCopy', () {
    test('形式不正と改ざん検知を区別する', () {
      const format = FormatException('bad');
      const integrity = IntegrityException('tampered');

      expect(BattleDecodeFailureCopy.urlInputMessage(format), '形式不正');
      expect(BattleDecodeFailureCopy.urlInputMessage(integrity), 'チェックサム不一致');
      expect(BattleDecodeFailureCopy.previewTitle(format), '形式不正');
      expect(BattleDecodeFailureCopy.previewTitle(integrity), '改ざん検知');
    });
  });

  group('BackupRestoreFailureCopy', () {
    test('形式とチェックサムを区別し、コピーし直し案内を持つ', () {
      expect(BackupRestoreFailureCopy.title(const FormatException('bad')), '形式');
      expect(
        BackupRestoreFailureCopy.title(const IntegrityException('tampered')),
        'チェックサム',
      );
      expect(BackupRestoreFailureCopy.retryHint, 'コード全体をコピーし直してください');
    });
  });
}
