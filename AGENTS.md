# SmartPhoneSpecBattle — このリポの例外

全リポ共通の内側ループと検証は **life の `dev/rules/` を読む**。ここに写さない。ツール固有設定へも複製しない。

- 内側ループ: https://github.com/ifrit99/life/blob/main/dev/rules/inner-loop.md
- 検証: https://github.com/ifrit99/life/blob/main/dev/rules/verification.md

life の default branch は `main`。共通と食い違うときは、このファイルか [REVIEW.md](REVIEW.md) に理由を書く。過去の役割分担より、life の共通ルールと本書の例外を優先する。

正リポは `/Users/kanaihideaki/Documents/SmartPhoneSpecBattle`（trusted）。`CodexProject/SmartPhoneSpecBattle_codex` は変更しない。

## このリポの例外

役割・モデル・マージ・往復の上限・レビュー役は life。古い席（製品コードは実装席の Cloud Agent だけ、Dual Review、レビュー既定を thermos + grok-4.6 high にする）は例外にしない。

- **Fable** は自動では使わない。イフリトが毎回 OK したときだけ。
- **途中確認**: 見た目が変わる作業・区分「高」のファイルに触れる作業は、最初の一切れで止めて `.agents/skills/midway-check` の手順で見せ、答えを待ってから続ける。
- ChatGPT Plus は解約済み。Codex 画像生成と Playwright の厳密見た目ゲートは Plus 復帰まで前提にしない。Astra は設計フォールバックに使わない。
- オンデマンド課金は使わない。Claude Pro は Cursor Other Models を補充しない。枠切れの設計・検証は life どおり参謀の Claude Pro（箱の Claude Code）へ回す。
- エージェントはマージしない。迷ったら Grok Bot の参謀ルート（外環→内環）に寄せる。

## 進捗・参照先

- 開始時に `/Users/kanaihideaki/orca/workspaces/life/ストレージ整理/AI-Shared-Memory/STATUS.md` を読み、区切りで担当・成果物/PR・検証結果・次の一手・判断待ちだけを更新する。既存の他案件は保持する。
- Cloud Agent からこのローカルパスを読めない場合、Mac 側で当該タスクの最小限の引継ぎを用意する。共有メモ全体を Cloud に複製しない。
- life リポ直下の Hermes `STATUS.md` は上書きしない。本リポに別の `STATUS.md` は作らない。
- `docs/TODO.md` は機能別の残タスク、`docs/plans/`・`docs/agent/` はタスク固有の計画/検証記録。横断進捗の入口は上記1か所とする。
- 再開時は、該当する `docs/plans/<件名>.md` の完了条件と記録欄（Generator ログ）を先に読む。区切りごとに記録欄へ「済んだこと・次の一手・判断待ち」を 1 行足す。計画ファイルが無いときは作らず、PR 本文に 1 行残す。STATUS.md が読めない Cloud Agent はこれを入口にする。
- 決めたこと: ユーザーと決めた方針・捨てた案は、小さな判断は `docs/decision-log.md`、大きな判断は `docs/adr/` に、それぞれの書式で残す。前回の判断は `grep -n "^## " docs/decision-log.md`・`grep -rln "<語>" docs/adr docs/rfc_*.md`・`git log --oneline --grep "<語>"` で探す。
- 仕様: `docs/product_spec.md`。構造: `docs/architecture.md`。実装規約: `docs/coding_rules.md`。必要な関連文書だけ段階的に読む。新規文書は原則 `docs/` へ。

## Skill・別管理の境界

- リポ固有 Skill の正本は `.agents/skills/`。既存の `.claude/skills` を移す場合は差分確認後に正本へ集約し、互換入口は symlink にする。複製して更新しない。
- ホーム側のユーザー管理 Skill は `~/.agents/skills/` を正本とする。`~/.codex/skills` の同梱 Skill は削除しない。移行記録は `docs/agent-operation.md` を参照。
- 認証・APIキー・OAuth・browser session・権限・ツール固有の実行環境は各ツール側で別管理する。共有 Markdown / Skill に値やセッション情報を保存しない。既存の秘密を見つけたら値を出さず所在だけ指摘し、移さない。
- 旧 agmsg / Claude ハーネスは保存するが現在は使わない。起動・タスク送信・返信待機・Claude 承認ループを自動で再開しない。履歴: `docs/agmsg_harness.md`。

## 実装・Git（このリポ）

前提・完了条件・検証方法を先に明確にし、最小差分で進める。無関係なリファクタや将来用の抽象化は追加しない。仕様・公開範囲・課金・破壊的操作など新しい判断が必要なら、具体的な案と影響をユーザーへ示す。承認済みの範囲は進める。

- コードの同時編集者は1人。`master` から `feature/` ブランチを作り、直接 `master` にコミットしない。コミット要約は日本語。
- GitHub の `master` 保護は **PR 必須・直接 push 禁止・承認 0・bypass なし**（案A）。ruleset は人が Settings で作る。エージェントはマージしない。承認 1 以上 + bypass なしにはしない（Cloud Agent の PR 作者がリポオーナーと同じになり、承認する人がいなくなるため）。
- コード変更は `flutter analyze` / `flutter test` を通し、変更に応じた検証結果を添える。未検証は理由を明記する。文書のみなら差分・参照整合性を確認する。
- `Verified:` は **コミット末尾の trailer**（life `dev/rules/verification.md`）。語は `analyze` `test` `verify-ssb` `tlc` `none`（`verify-ssb` は [#90](https://github.com/ifrit99/SmartPhoneSpecBattle/pull/90) の設計。スキルが来るまでは `analyze` / `test` / `none`）。検証しなかったときも `Verified: none (理由)` と書く。
- **共通の観察ゲートの置き場はこのリポの CI**。数え方は life どおり `git log` の trailer。`Verified:` が無いことだけで PR を落としてはいけない。観察はログに出すだけ。enforce はイフリトが決めるまでやらない。入れる PR は [decision-log](docs/decision-log.md)（#90 の `Verified:` 運用が回ったあとの別 PR）。
- 実装役が検証後にコミット・push・PRを作成し、検証役の指摘を同じ PR で直す。マージはユーザー判断に従う。

## UI / 見た目

- Avoid unnecessary secondary labels and descriptions. Let the layout do the explaining.
- 必要のない補足のラベルや説明文は付けない。配置で伝わるようにする。
- 同意・安全、オンボーディング、空状態の次アクションなど、必要な説明は削らない。

## レビュー

- このリポで何が壊れるかは [REVIEW.md](REVIEW.md)。読むのは PR の base（`git show origin/<base>:REVIEW.md`）。往復の上限、古い head へのレビューは無効、3 回で止まること、不安定なテストの扱いは life の共通ルール。
- レビューは日本語で返す。
