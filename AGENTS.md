# SmartPhoneSpecBattle — このリポの例外

全リポ共通の内側ループと検証は **life の `dev/rules/` を読む**。ここに写さない。ツール固有設定へも複製しない。

- 内側ループ: https://github.com/ifrit99/life/blob/main/dev/rules/inner-loop.md
- 検証: https://github.com/ifrit99/life/blob/main/dev/rules/verification.md

life の default branch は `main`（GitHub の `master` パスも同じファイルを指す）。共通と食い違うときは、このファイルか [REVIEW.md](REVIEW.md) に理由を書く。過去の役割分担より、life の共通ルールと本書の例外を優先する。

正リポは `/Users/kanaihideaki/Documents/SmartPhoneSpecBattle`（trusted）。`CodexProject/SmartPhoneSpecBattle_codex` は変更しない。

## このリポの例外

- **製品コード**（Dart / Flutter / アセット配線 / PR）は **実装席 → Cloud Agent `grok-4.6` のみ**。Codex に実装を寄せない。
- **Fable は使わない。** 設計・検証は life どおり Cursor 枠の Opus。枠切れでオンデマンドが要るときは別モデルに落とさず、参謀の Claude Pro に回す。Astra は設計フォールバックに使わない。
- Dual Review は毎回しない。高リスクまたはユーザー依頼時のみ。設計・アーキ妥当性は Opus（docs のみ）。完了報告・差分の事実監査は、ChatGPT Plus が無いので thermos + grok-4.6 high（Plus 復帰時は Mac Codex GPT 6 Astra）。実装は grok-4.6 のまま。
- レビューの既定も Plus 無しなので thermos + grok-4.6 high。指摘は Grok に戻す。厳密見た目ゲートは頼まれたときだけ（Plus 復帰時は Mac Codex + Playwright MCP、headless、`--mute-audio`）。
- 画像: Plus 無しのときは Codex 画像生成を前提にしない。Plus 復帰時は Codex `gpt-image-2` を候補にし、生成アセットは `assets/` へ。
- **途中確認**: 見た目が変わる作業・区分「高」のファイルに触れる作業は、最初の一切れで止めて `.agents/skills/midway-check` の手順で見せ、答えを待ってから続ける。
- 課金: Claude Pro + Cursor Pro + Open Code Go（Hermes）を継続。ChatGPT Plus は解約済み。Claude Pro は Cursor Other Models を補充しない。Claude Code は使わない。Grok Bot の共有PCには Codex / Claude Code を入れない。オンデマンド課金は使わない。
- Cursor Projects / Project Agent でも席を崩さない。マージは人。エージェントはマージしない。迷ったら Grok Bot の参謀ルート（外環→内環）に寄せる。

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
- `Verified:` 行は記録用。語は `analyze` `test` `verify-ssb` `tlc` `none`（`verify-ssb` は [#90](https://github.com/ifrit99/SmartPhoneSpecBattle/pull/90) の設計。スキルが来るまでは `analyze` / `test` / `none`）。検証しなかったときも `Verified: none (理由)` と書く。
- **共通の観察ゲートの置き場はこのリポの CI**（life `dev/rules/verification.md`）。`Verified:` 行が無いことだけで PR を落としてはいけない。観察はログに出すだけ。enforce はイフリトが決めるまでやらない。数え方は #90 の記録用のまま（本文の `Verified:` 行。trailer 解析は使わない）。
- Grok が検証後にコミット・push・PRを作成し、レビュー指摘を修正する。マージはユーザー判断に従う。

## UI / 見た目

- Avoid unnecessary secondary labels and descriptions. Let the layout do the explaining.
- 必要のない補足のラベルや説明文は付けない。配置で伝わるようにする。
- 同意・安全、オンボーディング、空状態の次アクションなど、必要な説明は削らない。

## レビュー

- このリポで何が壊れるかは [REVIEW.md](REVIEW.md)。往復の上限・基準の読み方・見た SHA は life の共通ルール。
- レビューは日本語で返す。
