# Plan: セキュリティ強化（Firestore ルール・App Check・デプロイの供給網）
Created: 2026-10-12
Status: PLANNING（RFC の §10 にイフリトさんが回答するまで着手しない。実装席は grok-4.6）

## 要件
`docs/rfc_security_hardening.md` を**唯一の正本**とする。本ファイルは PR の順序・完了条件の写しと Generator ログだけを持ち、脅威の整理・案の比較・判断理由は RFC 側を参照する。

## 前提
- 本計画と RFC はドキュメントのみ。`firestore.rules` / ワークフロー / `pubspec.yaml` / Dart の変更はすべて実装 PR で行う。
- HSTS は独自ドメイン確定まで範囲外（RFC §2）。
- PR-S1 と PR-S2 は独立。PR-S3 は RFC Q3 が「導入する」のときだけ。同時編集者は 1 人なので順に進める。
- 値（キー・トークン）は本リポにも共有メモにも書かない。確認結果は Mac 側の共有 `STATUS.md` に「日付・OK/NG・直した内容」だけ残す。

## PR の順序（各 PR は thermos + grok-4.6 high レビュー → イフリトさんがマージ判断）

| 順 | ブランチ（案） | 内容 | 対応する RFC | 規模 |
|----|---|---|---|---|
| PR-0 | （イフリトさんの作業、PR なし） | RFC §7-1〜§7-3 のコンソール確認、TTL ポリシー確認、§7-5 の履歴点検。A-1 採用なら reCAPTCHA v3 サイトキー作成 → GitHub secrets `RECAPTCHA_SITE_KEY` | §7、§8 PR-0 | — |
| PR-S1 | `feature/firestore-rules-hardening` | `firestore.rules` を RFC §4-4（R-1。Q2 Yes なら R-2）に更新。`test/firestore/rules.test.mjs` に §9-1 の観点 7〜13（R-2 時 14）を追加し、固定 `weekId` を「実行日の月曜」に差し替え。（任意）`test/firestore/package-lock.json` | §4、§9-1 | 小 |
| PR-S2 | `feature/deploy-wrangler-pin` | `tool/deploy/package.json` + `package-lock.json`（wrangler 完全版固定）、`deploy.yml` を `npm ci --prefix tool/deploy` → `npx --prefix tool/deploy wrangler` に変更、`.github/dependabot.yml` に `npm`（`/tool/deploy`）追加。`workflow_dispatch` で検証 | §6、§9-2 | 小 |
| PR-S3 | `feature/app-check-recaptcha` | `firebase_app_check` 追加、`ensureFirebaseInitialized` 内で `initializeApp` 直後に `activate`（サイトキー空なら No-op）、`ci.yml` / `deploy.yml` に `--dart-define=RECAPTCHA_SITE_KEY`、`web/_headers` に reCAPTCHA / App Check のドメイン追加、テスト。監視モードで本番確認 | §5、§9-3 | 中 |

PR-S1 / PR-S2 / PR-S3 のマージ後にイフリトさんが行う作業（ルール公開・トークン再発行・App Check 強制切替）は RFC §8 の「〜後」行を参照。

## 完了条件（RFC §9 の写し）
- [ ] PR-S1: ルールテスト 13 観点（R-2 時 14）がローカル Emulator で全パス。結果を PR 本文に貼る。`flutter analyze` / `flutter test` は未変更で通る
- [ ] PR-S1 後: Firebase コンソールのルールがリポと同一。pages.dev で参加 ON → 順位表示 → OFF → 推定へ戻る
- [x] PR-S2: `tool/deploy/package.json` + `package-lock.json` で wrangler 4.152.0 を固定、`deploy.yml` は `npm ci --ignore-scripts --prefix tool/deploy` → `npx --prefix tool/deploy wrangler`、Dependabot が `/tool/deploy` を対象。`workflow_dispatch` での `pages deploy` 成功確認はマージ後（イフリトさん）
- [ ] PR-S2 後: Pages: Edit のみの新トークンで配置成功。旧トークン失効
- [ ] PR-S3: `flutter analyze` エラー 0 / `flutter test` 全パス。`main.dart.js` サイズ差分を記録。参加 OFF で reCAPTCHA / App Check への通信 0 件。参加 ON で CSP violation なし・順位表示。App Check 指標の「検証済み」がほぼ 100%
- [ ] PR-S3 後: Firestore を強制に切替後もアプリが動き、蹴られた場合は推定表示に戻る。Sentry に新規イベントが増えない
- [ ] 全体: 月額 ¥0 のまま（Blaze / Enterprise / カード紐付けを含まない）

---
## Generator ログ
- 2026-10-23 grok-4.6: PR-S2 実装。起点は PR #79 `cursor/cf-production-env-a5c3`。`tool/deploy/package.json` に wrangler `4.152.0`（完全版）と `package-lock.json` を追加。`deploy.yml` は `npx --yes wrangler@…` をやめ、`npm ci --ignore-scripts --prefix tool/deploy` のあと `npx --prefix tool/deploy wrangler` に変更（トークンは Direct Upload ステップのみ）。`actions/setup-node` を SHA 固定（v7.1.0）。`.github/dependabot.yml` に `npm`（`/tool/deploy`）を追加。`workflow_dispatch` の本番配置確認はマージ後。

---
## 評価
- 2026-10-23 grok-4.6: ローカルで `npm ci --ignore-scripts --prefix tool/deploy` と `npx --prefix tool/deploy wrangler --version` が lockfile の 4.152.0 と一致することを確認。`npx --yes wrangler@` が `deploy.yml` に残っていないこと、Dependabot が `/tool/deploy` を対象にしていることを確認。`actionlint` v1.7.7 で workflow YAML を確認（指摘なし）。`pages deploy` は Environment `production` が必要なため未実施。
