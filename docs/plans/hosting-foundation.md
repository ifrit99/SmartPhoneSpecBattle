# Plan: ホスティング基盤の移行（Cloudflare Pages）
Created: 2026-09-11
Status: PLANNING（ユーザーの RFC 承認待ち。承認後の実装席は grok-4.6）

## 要件
`docs/rfc_hosting_foundation.md` を**唯一の正本**とする。本ファイルは PR の順序と完了条件の写しだけを持ち、要件の詳細・比較・判断理由は RFC 側を参照する。RFC §10 の受け入れ基準と §11 の未決事項（Q1〜Q3 は最低限）にユーザーが回答するまで着手しない。

## 前提
- 選定は RFC §7 のとおり **(A) Cloudflare Pages** を第一候補とする。ユーザーが B/C を選んだ場合は RFC §7 を更新し、本計画の PR-2/PR-3 を差し替える。
- コード変更・ワークフロー変更・`web/` 配下の追加はすべて実装 PR で行う。本計画と RFC はドキュメントのみ。
- `CharacterCodec` / `QrBattleService` / ツイート UI の仕様は変更しない（RFC S-8、§4-4）。触るのは URL 直書きの値だけ。

## PR の順序（各 PR は Codex レビュー → ユーザーがマージ判断）

| 順 | ブランチ（案） | 内容 | 対応する RFC 要件 | 規模 |
|----|---|---|---|---|
| PR-0 | （ユーザー作業、PR なし） | Cloudflare アカウント/プロジェクト作成、API トークン（Pages Edit 限定）発行、GitHub Environment `production` に `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID` を登録。Sentry の Allowed Domains に新ドメイン追加 | M-4, S-2, S-7 | — |
| PR-1 | `feature/hosting-headers` | `web/_headers` を追加（CSP は Report-Only で開始）。GitHub Pages では無効なファイルなので**現行配信に影響なし**。先に成果物へ同梱しておき、PR-2 で切り替えた瞬間に効かせる | S-3, S-5 | 小 |
| PR-2 | `feature/hosting-cloudflare-deploy` | `deploy.yml` の配置ステップを Cloudflare Pages（Direct Upload）へ差し替え、`--base-href "/"`（`ci.yml` も同時）。`SITE_URL` の `sed` と `og:url`、`result_screen.dart` の `_gameUrl` を正規 URL に更新（`--dart-define=SITE_URL` 化は同 PR で判断）。旧 GitHub Pages 用ワークフローはリネームして残す（ロールバック用）。RFC M-8 の手動確認を PR 本文に添える | M-1, M-2, M-4, M-5, M-8 | 中 |
| PR-3 | `feature/hosting-githubio-redirect` | github.io 側を「リダイレクト専用 `index.html`」に置き換える別ワークフロー（`?battle=` を引き継ぐ）。停止時期は RFC M-6 | M-3, M-6 | 小 |
| PR-4 | `feature/hosting-csp-enforce` | Report-Only の観測結果を見て CSP を enforce に切り替え。HSTS はカスタムドメイン確定時のみ短い max-age で | S-3, S-4, S-5 | 小 |
| PR-5（任意） | `feature/ci-action-pinning` | third-party action の SHA 固定、Dependabot（`github-actions`）有効化。RFC Q5 の回答が「同時」なら PR-2 に含める | S-6 | 小 |

## 完了条件（RFC §9/§10 の写し）
- [ ] 正規 URL で タイトル → ホーム → フレンド共有 → `?battle=` 直リンク → ゲストプレビューまで遷移する
- [ ] X intent の本文に正規 URL（ルートのみ、`?battle=` なし）と `#SPECBATTLE` が含まれる
- [ ] OGP デバッガで画像と `og:url` が正規 URL を指す
- [ ] `curl -I` で S-3 のヘッダ（CSP / nosniff / Referrer-Policy / Permissions-Policy / frame-ancestors）が返る
- [ ] `https://ifrit99.github.io/SmartPhoneSpecBattle/?battle=...` が `?battle=` を保って正規 URL へリダイレクトする
- [ ] `flutter analyze` / `flutter test` 全パス（PR ごと）
- [ ] 月額 ¥0 のまま（カード紐付けが必要な設定を含まない）

## 運用メモ（PR-2 マージ後に追記）
- 月次確認: Cloudflare Pages の帯域/リクエスト数、Pages Functions の実行回数（F8 着手後）、Sentry の request URL に github.io が残る比率（M-6 判定）

---
## Generator ログ
（実装時に追記）

---
## 評価
（検証結果を追記）
