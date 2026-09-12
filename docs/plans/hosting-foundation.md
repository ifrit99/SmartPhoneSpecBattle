# Plan: ホスティング基盤の移行（Cloudflare Pages）
Created: 2026-09-11
Status: PR-4 done（RFC は 2026-09-11 ユーザー承認済み。実装席は grok-4.6。PR-1 は #45。PR-2 は #46。PR-3 は #48。計画表の実装 PR はここまで。M-6 の deploy-github-pages.yml 削除は後続）

## 要件
`docs/rfc_hosting_foundation.md` を**唯一の正本**とする。本ファイルは PR の順序と完了条件の写しだけを持ち、要件の詳細・比較・判断理由は RFC 側を参照する。RFC §10 の受け入れ基準と §11 の未決事項（Q1〜Q3 は最低限）にユーザーが回答するまで着手しない。

## 前提
- 選定は RFC §7 のとおり **(A) Cloudflare Pages** を第一候補とする。ユーザーが B/C を選んだ場合は RFC §7 を更新し、本計画の PR-2 を差し替える。
- github.io からのリダイレクトは**行わない**（2026-09-11 ユーザー判断: プレイヤー・既存ツイートなし。RFC M-3 / Q3）。Cloudflare Pages 稼働確認後に GitHub Pages を停止するだけ。
- コード変更・ワークフロー変更・`web/` 配下の追加はすべて実装 PR で行う。本計画と RFC はドキュメントのみ。
- `CharacterCodec` / `QrBattleService` / ツイート UI の仕様は変更しない（RFC S-8、§4-4）。触るのは URL 直書きの値だけ。

## PR の順序（各 PR は Codex レビュー → ユーザーがマージ判断）

| 順 | ブランチ（案） | 内容 | 対応する RFC 要件 | 規模 |
|----|---|---|---|---|
| PR-0 | （ユーザー作業、PR なし） | Cloudflare アカウント/プロジェクト作成、API トークン（Pages Edit 限定）発行、GitHub Environment `production` に `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID` を登録。Sentry の Allowed Domains に新ドメイン追加 | M-4, S-2, S-7 | — |
| PR-1 | `feature/hosting-headers` | `web/_headers` を追加（CSP は Report-Only で開始）。GitHub Pages では無効なファイルなので**現行配信に影響なし**。先に成果物へ同梱しておき、PR-2 で切り替えた瞬間に効かせる | S-3, S-5 | 小 |
| PR-2 | `feature/hosting-cloudflare-deploy` | `deploy.yml` の配置ステップを Cloudflare Pages（Direct Upload）へ差し替え、`--base-href "/"`（`ci.yml` も同時）。`SITE_URL` の `sed` と `og:url`、`result_screen.dart` の `_gameUrl` を正規 URL に更新（`--dart-define=SITE_URL` 化は同 PR で判断）。旧 GitHub Pages 用ワークフローはリネームして残す（ロールバック用）。RFC M-8 の手動確認を PR 本文に添える。確認が通ったらユーザーがリポジトリ設定で GitHub Pages を無効化（リダイレクトスタブなし） | M-1, M-2, M-3, M-4, M-5, M-8 | 中 |
| ~~PR-3~~ | ~~`feature/hosting-githubio-redirect`~~ | **取消（2026-09-11）**: github.io リダイレクト専用ページは作らない。プレイヤー・既存ツイートが無く保全対象がないため（RFC M-3 / Q3） | — | — |
| PR-3 | `feature/hosting-csp-enforce` | **done**: Report-Only を `Content-Security-Policy` に切替。ディレクティブ本文は据え置き。HSTS は未追加（カスタムドメインなし、S-4）。`deploy-github-pages.yml` は緊急ロールバック用に残置（M-6 の削除は後続。Pages は unpublished 済み） | S-3, S-4, S-5 | 小 |
| PR-4 | `feature/ci-action-pinning` | **done**: third-party action の SHA 固定、Dependabot（`github-actions`）週次。`deploy-github-pages.yml` もピン（緊急ロールバック用に残置）。メジャータグは最新パッチ SHA を採用し、メジャー上げはしない | S-6 | 小 |

## 完了条件（RFC §9/§10 の写し）
- [ ] 正規 URL で タイトル → ホーム → フレンド共有 → `?battle=` 直リンク → ゲストプレビューまで遷移する
- [ ] X intent の本文に正規 URL（ルートのみ、`?battle=` なし）と `#SPECBATTLE` が含まれる
- [ ] OGP デバッガで画像と `og:url` が正規 URL を指す
- [ ] `curl -I` で S-3 のヘッダ（CSP / nosniff / Referrer-Policy / Permissions-Policy / frame-ancestors）が返る
- [ ] GitHub Pages への配置が止まっている（旧 URL が更新されない。リダイレクトは不要）
- [ ] `flutter analyze` / `flutter test` 全パス（PR ごと）
- [ ] 月額 ¥0 のまま（カード紐付けが必要な設定を含まない）

## 運用メモ（PR-2 マージ後に追記）
- 月次確認: Cloudflare Pages の帯域/リクエスト数、Pages Functions の実行回数（F8 着手後）
- 正規 URL 予定: `https://smartphonespecbattle.pages.dev`（初回デプロイでプロジェクト作成。名前が取られていれば URL が変わる）
- シークレット: リポジトリ secrets `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID`（Environment `production` は使わない）
- ブランチプレビュー（M-7）: Git 連携なし。`deploy.yml` は master のみ `--branch=master`。`wrangler.toml` に preview 無効化キーは無い
- GitHub Pages 停止: リポジトリ設定で unpublished 済み。リダイレクトスタブは作らない（M-3）。`deploy-github-pages.yml` は緊急ロールバック用に残す（M-5）。M-6 のファイル削除は後続
- ロールバック: (1) Pages のデプロイ履歴、(2) `deploy-github-pages.yml` を `workflow_dispatch` で実行
---
## Generator ログ
- 2026-09-12 grok-4.6: PR-2 実装。起点は #45 `cursor/hosting-headers-21ba`（`web/_headers` 同梱）。旧 `deploy.yml` を `deploy-github-pages.yml` にリネームし push トリガーを外した。新 `deploy.yml` は wrangler Direct Upload。`--base-href "/"`、`SITE_URL` dart-define、`og:url` / `_gameUrl` を pages.dev に揃えた。
- 2026-09-12 grok-4.6: PR-3 実装。`web/_headers` の CSP を Report-Only から enforce に切替。ディレクティブ本文は変更なし。HSTS なし。`deploy-github-pages.yml` は残置。起点は master `e6cc47a1`（#47）。
- 2026-09-12 grok-4.6: PR-4 実装。起点は master `787b2e62`（#48）。third-party action を現行メジャータグの最新パッチ SHA に固定。`.github/dependabot.yml` で `github-actions` 週次。`deploy-github-pages.yml` は残置してピンのみ。`cloudflare/wrangler-action` は現行ワークフローに無い（npx wrangler@4）。

---
## 評価
- 2026-09-12 grok-4.6: `flutter analyze` No issues found。`flutter test` All tests passed（476）。`flutter build web --release --base-href "/"` 成功（`base href="/"`、`og:url` は pages.dev、`build/web/_headers` あり）。実装は `cursor/hosting-cloudflare-deploy-161f`。マージしない。
- 2026-09-12 grok-4.6: PR-3。`flutter analyze` No issues found。`flutter build web --release --base-href "/"` 成功（`build/web/_headers` が `web/_headers` と同一。ヘッダ名は `Content-Security-Policy`）。Dart 未変更のため `flutter test` は未実施。実装は `cursor/hosting-csp-enforce-da50`。マージしない。
