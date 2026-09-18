# 共通ルールの正本 — SmartPhoneSpecBattle

このファイルを全エージェント共通の判断基準の正本とする。ツール固有設定で複製しない。過去の役割分担より、現在のユーザー方針と本書を優先する。
正リポは `/Users/kanaihideaki/Documents/SmartPhoneSpecBattle`（trusted）。`CodexProject/SmartPhoneSpecBattle_codex` は変更しない。

## 現在の担当と流れ
- 設計: Cursor Cloud Agent `claude-fable-5-1`（docs のみ）。Fable 枠切れ時だけ Mac Codex GPT 6 Astra が docs を代行する。
- 実装・修正・テスト・PR作成: Cursor Cloud Agent `grok-4.6`。Codex に実装を寄せない。
- レビュー: Codex。指摘は Grok に戻す。厳密見た目ゲートは頼まれたときだけ Mac Codex + Playwright MCP（headless、`--mute-audio`）。
- Dual Review の役割分担:
  - 設計・アーキ妥当性 → Fable 5.1（docsのみ）
  - 完了報告・差分の事実監査（引用・矛盾・必要ならテスト）→ Mac Codex GPT 6 Astra
- Dual Review は毎回しない。高リスクまたはユーザー依頼時のみ dual。
- Dual Review でも実装は grok-4.6 のまま（既存どおり）。
- 画像: Codex `gpt-image-2`。生成アセットは `assets/` へ。
- 判断: ユーザー。要求 → 設計案 → ユーザーの方針判断 → Grok が実装・検証・PR → Codex レビュー → Grok 修正 → ユーザーがマージ可否を判断。
- ChatGPT Plus + Codex（Mac）を継続し、既定モデルは GPT 6 Astra。Claude Pro は解約済み、Claude Code は使わない。Grok Bot の共有PCには Codex / Claude Code を入れない。

## Cursor Projects（重要）
Cursor Projects / Project Agent でも本書の席を崩さない。
- **製品コード**（Dart / Flutter / アセット配線 / PR）は **実装席 → Cloud Agent `grok-4.6` のみ**。
- **Fable（`claude-fable-5-1`）は docs のみ**。設計〜実装〜PR〜レビューを一人で名乗らない・やらない。
- **マージは人**。エージェントはマージしない。
- Other Models 枠が尽きているときは Fable を起動せず、設計 docs は Mac Codex GPT 6 Astra に逃がす。オンデマンドは触らない。
- 迷ったら Grok Bot の参謀ルート（外環→内環）に寄せる。Projects で席をバイパスしない。

## 進捗・参照先
- 開始時に `/Users/kanaihideaki/orca/workspaces/life/ストレージ整理/AI-Shared-Memory/STATUS.md` を読み、区切りで担当・成果物/PR・検証結果・次の一手・判断待ちだけを更新する。既存の他案件は保持する。
- Cloud Agent からこのローカルパスを読めない場合、Mac 側で当該タスクの最小限の引継ぎを用意する。共有メモ全体を Cloud に複製しない。
- life リポ直下の Hermes `STATUS.md` は上書きしない。本リポに別の `STATUS.md` は作らない。
- `docs/TODO.md` は機能別の残タスク、`docs/plans/`・`docs/agent/` はタスク固有の計画/検証記録。横断進捗の入口は上記1か所とする。
- 仕様: `docs/product_spec.md`。構造: `docs/architecture.md`。実装規約: `docs/coding_rules.md`。必要な関連文書だけ段階的に読む。新規文書は原則 `docs/` へ。

## Skill・別管理の境界
- リポ固有 Skill の正本は `.agents/skills/`。既存の `.claude/skills` を移す場合は差分確認後に正本へ集約し、互換入口は symlink にする。複製して更新しない。
- ホーム側のユーザー管理 Skill は `~/.agents/skills/` を正本とする。`~/.codex/skills` の同梱 Skill は削除しない。移行記録は `docs/agent-operation.md` を参照。
- 認証・APIキー・OAuth・browser session・権限・ツール固有の実行環境は各ツール側で別管理する。共有 Markdown / Skill に値やセッション情報を保存しない。既存の秘密を見つけたら値を出さず所在だけ指摘し、移さない。
- 旧 agmsg / Claude ハーネスは保存するが現在は使わない。起動・タスク送信・返信待機・Claude 承認ループを自動で再開しない。履歴: `docs/agmsg_harness.md`。

## 実装・Git の共通基準
- 前提・完了条件・検証方法を先に明確にし、最小差分で進める。無関係なリファクタや将来用の抽象化は追加しない。
- 仕様・公開範囲・課金・破壊的操作など新しい判断が必要なら、具体的な案と影響をユーザーへ示す。承認済みの範囲は進める。
- コードの同時編集者は1人。`master` から `feature/` ブランチを作り、直接 `master` にコミットしない。コミット要約は日本語。
- コード変更は `flutter analyze` / `flutter test` を通し、変更に応じた検証結果を添える。未検証は理由を明記する。文書のみなら差分・参照整合性を確認する。
- Grok が検証後にコミット・push・PRを作成し、Codex のレビュー指摘を修正する。マージはユーザー判断に従う。

## Language
- Pull request review comments must be written in Japanese.

## Review style
- Keep comments concise and concrete.
- When pointing out an issue, explain:
  - what is wrong
  - why it matters
  - how to fix it

## Review focus
- Prioritize regression risks.
- Check state/flag management carefully.
- Check branch漏れ for empty states and skip flows.
- Point out missing tests when relevant.
