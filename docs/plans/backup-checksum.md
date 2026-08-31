# Plan: F5 バックアップコード v2
Created: 2026-08-31
Status: EVAL

## 要件
`docs/phase5_brushup_spec.md` §2-6 / §1-4 F5 / §4-1 バックアップv2。要件の追加なし（§2-6の転記のみ）。

## 仕様（§2-6 転記）

- 現行: `SPEC-BATTLE-BACKUP:` + Base64url JSON（整合性検証なし）。
- v2 エンコード手順（`CharacterCodec` v2 と同一方式・実装を再利用）:
  1. JSONペイロードをUTF-8バイト列化する
  2. そのバイト列のHMAC-SHA256を計算し、**先頭4バイト**をチェックサムとする
  3. `ペイロードバイト列 + チェックサム4バイト` を連結し、**まとめて1回だけBase64url化**する
  4. 先頭に `SPEC-BATTLE-BACKUP2:` プレフィックスを付与する
- v2 復元手順: プレフィックス除去 → Base64urlデコード → 末尾4バイトをチェックサムとして分離 → 残りのバイト列からHMAC-SHA256先頭4バイトを再計算して比較。不一致なら `IntegrityException`（F3-7の文言で拒否）。
- v1プレフィックスは従来どおり復元可（後方互換）。生成は常にv2。
- 既知の限界: HMAC鍵はクライアント埋め込みのため改ざん防止ではなく**破損検知**が目的（`product_spec.md` 7-1と同じ制約）。

## 画面/UI変更
- データ保護画面: v2コード生成、復元失敗理由の明示（§3-1。F3-7チェックサム文言＝「コードが破損しています」）。

## テスト基準（§4-1 転記）
- [ ] 正常往復
- [ ] 1文字破損で `IntegrityException`
- [ ] v1コード復元互換
- [ ] v2生成プレフィックス
- [ ] 既存 `economy_balance_test.dart` が無変更でパス
- [ ] Character v1/v2/v3 デコード互換の既存テスト維持

## 完了条件
- [ ] flutter analyze: エラー0
- [ ] flutter test: 全パス

---
## Generator ログ
- 生成は常に `SPEC-BATTLE-BACKUP2:`。HMAC-SHA256先頭4バイトは `CharacterCodec.computeChecksum` を再利用。
- 復元は v2 を先に判定（`BACKUP2` が `BACKUP` の接頭辞でもあるため）。v1プレフィックスと prefix なし本文は従来どおりチェックサムなしで復元。
- チェックサム不一致は `IntegrityException('コードが破損しています')`（F3-7）。データ書き込み前に拒否。

---
## 評価
（Evaluator が検証結果を追記）
