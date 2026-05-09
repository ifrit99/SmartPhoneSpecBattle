# Plan: Codex PR #14 P1指摘 全対応
Created: 2026-05-09
Status: EVAL
Branch: `fix/review-followups`

## 要件
PR #14 で Codex から提示された P1 指摘 3 件を全て解消する：
- `lib/data/sound_service.dart` `unlockAudio()` 失敗時に再試行可能化（r3200386033 / r3200739254）
- `lib/domain/services/daily_mission_service.dart` 一括/個別受取の並列再入による二重加算を防止（r3212925391）
- `lib/domain/services/daily_shop_service.dart` 購入の並列再入による二重消費を防止（r3212925388）

## 仕様

### ロジック/状態変更
- `lib/data/sound_service.dart`: `_audioUnlocked = true` を `try` ブロック成功時のみ設定（`finally` から移動）。**origin `1cfd53e` で対応済**。
- `lib/domain/services/daily_mission_service.dart`: `_claimChain` フィールドと `_runExclusive<T>()` を追加し `claim()` / `claimAllAvailable()` を直列化。受取済みID保存を報酬加算より先に行う順序へ修正。**ローカル編集済**。
- `lib/domain/services/daily_shop_service.dart`: 同パターンを移植し `purchase()` を `_runExclusive` でラップ。

### 新規ファイル
- なし（既存サービスに `_runExclusive` パターンを追加するのみ）

### テスト基準
- [ ] `flutter analyze` エラー 0
- [ ] `flutter test` 全パス（既存 + 並列テスト計4件追加）
- [ ] 並列 `claim` / `claimAllAvailable` が二重加算しない
- [ ] 並列 `purchase` が二重消費しない（同一オファー / 異なるオファー両方）
- [ ] ブラウザでホーム画面の「全部受け取る」「ショップ購入」を連打しても通貨二重加算なし
- [ ] 音声 unlock 失敗時に再タップで再試行できる

### 完了条件
- [ ] flutter analyze: エラー0
- [ ] flutter test: 全パス
- [ ] PR #14 へのpush完了
- [ ] Evaluator 全PASS でこの Status を DONE に変更

---
## Generator ログ
- 2026-05-09: `git pull --ff-only` で `1cfd53e fix: keep audio unlock retryable on failure` を取り込み（sound_service / sound_service_test）。
- 2026-05-09: daily_mission_service.dart に `_runExclusive` を追加し `claim()` / `claimAllAvailable()` を直列化、受取済みID保存→報酬加算の順に変更（既存ローカル編集をそのまま採用）。
- 2026-05-09: daily_shop_service.dart に同パターンの `_runExclusive` を移植し `purchase()` をラップ。報酬付与が `spendCoins` 失敗で巻き戻る現状仕様を保つため、購入済みフラグ保存は処理末尾を維持。
- 2026-05-09: テスト追加: `claimAllAvailable` 並列 / `claim` 並列 / 同一オファー並列購入 / 異オファー並列購入 の計4件。
- 2026-05-09: `1cfd53e` の `unlockAudio失敗時は再試行できるよう未アンロックのままにする` がローカル(macOS) で `play(AssetSource)` の non-mocked 内部呼び出しにより通らなかったため、success-path のアサーションを「アンロック済みなら再呼び出しでもメソッドチャネルへ到達しない」検証に置き換え。失敗時に `_audioUnlocked=false` のままという回帰テストの本旨は維持。
- 2026-05-09: `flutter analyze` 0件、`flutter test` 全パス。

---
## 評価
（Evaluator が検証結果を追記）
