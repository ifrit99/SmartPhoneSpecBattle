# 機能メモ: URL共有（フレンド対戦）

## 機能の目的
自分のキャラクターを「URL1本」で他者に共有し、受け手がそのURLを開くだけでゲスト敵として戦えるようにする。
Web MVPに合わせ、QR表示・QRカメラスキャンは撤去。URLコピー/OS標準共有で完結させる。

## 現状の理解
- エンコード/デコードは `CharacterCodec`（v2: HMAC-SHA256ベースの4バイトチェックサム付き）が担当。
- v1（チェックサムなし）とも後方互換でデコード可能。
- サービス層は `QrBattleService`:
  - `encodePlayerCharacter(Character)` / `encodeGachaCharacter(GachaCharacter)`
  - `decodeAsGuest(String) -> QrBattleGuest`
  - `generateShareUrl(encoded)`:
    - `baseUrl` が空なら `Uri.base.replace(query: '', fragment: '')` を使い、末尾の `/?#` を除去。
    - base64urlパディング `=` を除去してURLに埋め込む。
  - `extractBattleParam(Uri)`: 逆向き処理。スペース/`+` の混入もクリーンアップし、パディング復元。
  - `normalizeBattleInput(String)`: URL全体/生コードのどちらでも受け取れる入力正規化（PR: `fix/review-followups` で公開化）。
- UI:
  - `FriendBattleMenuScreen` (`qr_menu_screen.dart`): 共有/入力の入り口
  - `ShareScreen` (`qr_display_screen.dart`): URL表示＋コピー＋OS共有
  - `UrlInputScreen` (`qr_scan_screen.dart`): URL/コード貼り付けで相手キャラを開く
  - `QrGuestPreviewScreen`: 受け取ったキャラのプレビュー→バトル遷移
- バトル報酬はCPU対戦のみ付与（QR/URL対戦では付与しない）。

## 関連しそうなファイルや処理
- `lib/domain/services/qr_battle_service.dart`
- `lib/domain/services/character_codec.dart`
- `lib/domain/models/decoded_character.dart`
- `lib/presentation/screens/qr_menu_screen.dart` / `qr_display_screen.dart` / `qr_scan_screen.dart` / `qr_guest_preview_screen.dart`
- `lib/main.dart` — `Uri.base` からの起動時パラメータ解釈（Web専用）
- `test/domain/qr_battle_service_test.dart` / `character_codec_test.dart`

## 今後見直しそうな点
- HMAC秘密鍵は `CharacterCodec._hmacKey`（`lib/domain/services/character_codec.dart:30`）にハードコードされた定数（`'SpecBattle_v2_integrity_2026'`）。リポジトリを読める人には鍵も読めるため、改ざん検知は**難読化レベル**。Web MVP範囲では許容するが、オンライン化・サーバー検証を導入する段階で鍵設計（環境変数化／サーバー側検証）から見直す。
- base64url文字だけで完結しているはずだが、ユーザーが誤ってURL全体ではなくURLエンコード済み文字列を貼る可能性への耐性は要検証。
- 複数端末/ブラウザ間でのURL文字数制限（特にTwitter/LINE等のSNS共有時のURL短縮動作）は未検証（仮置き）。
- ガチャキャラ由来のURLと実機キャラ由来のURLでレアリティやデバイス名が正しく伝達されているかのE2E確認。
- モバイルアプリ復帰時のDeep Link対応は非目標（Web MVP優先）。
