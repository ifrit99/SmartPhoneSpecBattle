# 現行のエージェント運用

共通の内側ループ・検証は ifrit99/life の `dev/rules/` を読む（写さない）。このリポの例外・担当は [AGENTS.md](../AGENTS.md)。モデル名はユーザー指定の運用名であり、契約や設定をこの変更で操作したものではない。

1. Mac 側で AI-Shared-Memory/STATUS.md を読み、要求・対象・完了条件を設計担当へ引き継ぐ。
2. 役割は life どおり（写さない）。Fable は自動では使わず、イフリトが毎回 OK したときだけ。枠切れでオンデマンドが要るときは参謀の Claude Pro（箱の Claude Code）に回す。
3. 実装役が設計に沿って PR を作成する。検証役の指摘は同じ PR で直す。見た目の厳密ゲートは依頼時のみ。
4. 検証結果と残リスクを添え、ユーザーがマージ可否を判断する。Mac 側で共有 STATUS の当該タスクだけを更新する。
5. `Verified:` はコミット末尾の trailer。共通の観察ゲートの置き場はこのリポの CI だが、無いことだけで PR を落としてはいけない。

Cloud への引継ぎはタスク関連情報だけとし、ローカル共有メモやホーム Skill 全体はアップロードしない。Cloud にはリポの AGENTS.md と必要な Skill を渡す。認証・権限・ブラウザセッションはそれぞれの実行環境に保持する。

## Skill の配置

- リポ内: 調査時点で `.claude/skills/` も独自 Skill も存在しないため、移行対象なし。今後の追加先は `.agents/skills/` のみ。空の Skill や不要な Claude 入口は作らない。
- ホーム内: `~/.agents/skills/` が正本。Claude 側と差分を確認済み（GStack の通常ファイルは両側同数・379件に内容差分、frontend-design は1件）。既存正本を保持し、`~/.claude/skills -> ../.agents/skills` に統一。旧版は `~/.claude/skills-retired-20260906/` に退避し、自動読込・更新対象にしない。空だった42個の入口は正本の `gstack/<skill>` への相対 symlink に修復済み。
- `~/.codex/skills/.system` と既存の同梱 Skill はそのまま保持する。

## 旧文書

旧 CLAUDE.md の共通基準は AGENTS.md に集約した。CLAUDE.md は互換用に life `dev/rules/` へのポインタと `@AGENTS.md` `@REVIEW.md` だけ。旧 agmsg ハーネスの再開は意味しない。枠切れ時の設計・検証は箱の Claude Code を使う。旧 agmsg と実装ループ文書・スクリプトは削除せず、旧文書冒頭で無効と明示している。

出典: https://x.com/masahirochaen/status/2093670963330363470 （本文の取得は403。ユーザー添付画像と指定方針に基づき適用。）

## 残課題・確認範囲

- 旧 `connect-chrome` / `qa-design-review` は移行前からリンク先実体がないため復活させていない。必要になるまで再導入しない。
- 認証・権限・モデル設定・Cloud 環境・旧ハーネスの実行設定は今回変更していない。
