# agmsg エージェント間連携ハーネス

[agmsg](https://github.com/fujibee/agmsg) は Bash + SQLite で構成されるローカルAIエージェント間メッセージングツール（`~/.agents/skills/agmsg` にインストール済み）。本ハーネスは、agmsgを使って Claude Code と Codex をチーム `specbattle` 上で連携させ、設計・実装・レビューの役割分離を伴う開発フローを実現するためのものである。

通常モード（`CLAUDE.md` の役割分担）との違いは「役割分担表」を参照。

---

## 1. 役割分担表

| 役割 | 担当 | 主な作業 |
|------|------|---------|
| オーケストレーター | Claude Code メインセッション | agmsg送受信、進行管理、`agmsg-designer`/`agmsg-reviewer` への委任、PR作成 |
| 設計（Planner） | `agmsg-designer` サブエージェント | `docs/plans/{feature}.md` の作成、`[TASK]` メッセージ素案の作成 |
| 実装（Generator） | Codex | feature/ブランチでの実装、画像生成（image gen）、`flutter analyze`/`flutter test`、`[DONE]` 送信 |
| レビュー（Evaluator） | `agmsg-reviewer` サブエージェント | diffと計画の突き合わせ、verdict判定、`[REVIEW]` メッセージ素案の作成 |

**大原則**: 同一エージェントが自分の成果物を評価しない。設計（agmsg-designer）とレビュー（agmsg-reviewer）は必ず別サブエージェント・別コンテキストで実行する。メインセッション自身も、Codexの実装に対して自らレビューを完結させず `agmsg-reviewer` に委任する。

既存の Planner/Generator/Evaluator ワークフロー（`docs/plans/TEMPLATES.md`）との対応:

| Planner/Generator/Evaluator | agmsgハーネス |
|---|---|
| Planner | `agmsg-designer` |
| Generator | Codex |
| Evaluator | `agmsg-reviewer` |

通常モード（`CLAUDE.md` の「Claude Code=実装担当 / Codex=PRレビュー担当」）とは役割が入れ替わる点に注意。ハーネスモードを使うかどうかはタスクごとに選択してよい。

---

## 2. 画像生成ポリシー

- 画像・ビジュアルアセットの生成はすべて **Codex の image gen 機能**で行い、`assets/` に配置する。
- Claude側（メインセッション・`agmsg-designer`・`agmsg-reviewer`）では画像を生成しない。
- `agmsg-designer` が作成する計画ファイルおよびメインセッションが送る `[TASK]` メッセージには、必要なアセットを明記する。

---

## 3. セットアップ手順

チェックアウト（worktree含む）ごとに初回のみ実行する（agmsgの登録・配信フックはプロジェクトパス単位のため、別のworktreeで使う場合はそのworktreeでも実行が必要）。

```bash
bash scripts/agmsg/setup.sh
```

- claude / codex エージェントをチーム `specbattle` に登録する（登録済みならスキップ）。
- 配信モードを設定する（claude=monitor、codex=turn）。
- **monitor モードは次回の Claude Code セッションから有効**になる。

Codex の起動:

```bash
# タスクを渡して起動（推奨）
bash scripts/agmsg/start_codex.sh "[TASK] t1 <目的> branch=feature/xxx spec=docs/plans/xxx.md 完了条件=analyze/testグリーン"

# 起動のみ
bash scripts/agmsg/start_codex.sh
```

tmux内ならペイン分割、tmux外なら新規ターミナルウィンドウで Codex が起動し、自動的にチームへ参加する。

turnモードのCodexはアイドル中に受信箱を確認しないため、初回タスクは**起動前に送信**する必要がある。start_codex.sh に第1引数でタスクを渡すと、spawn前に送信してから起動する。

---

## 4. メッセージプロトコル

| 種別 | 方向 | 書式例 |
|------|------|--------|
| `[TASK]` | claude→codex | `[TASK] t1 <目的> branch=feature/xxx spec=docs/plans/xxx.md 完了条件=analyze/testグリーン`（必要な画像アセットがあれば明記） |
| `[QUESTION]` / `[ANSWER]` | 双方向 | 実装中の不明点確認 |
| `[DONE]` | codex→claude | `[DONE] t1 branch=feature/xxx 変更サマリー・テスト結果` |
| `[REVIEW]` | claude→codex | `[REVIEW] t1 verdict=approve\|request_changes 指摘一覧` |
| `[FIX_DONE]` | codex→claude | `[FIX_DONE] t1 対応内容` |
| `[BLOCKED]` | 双方向 | 続行不能時のエスカレーション（ユーザー判断待ち） |

---

## 5. 連携フロー

```
1. メインセッションが agmsg-designer に仕様作成を委任
       → docs/plans/{feature}.md 出力（Status: PLANNING）
            ↓
2. メインが [TASK] を codex へ送信
       （Codex未起動なら start_codex.sh "[TASK] ..." で送信→起動。
         起動済みなら待機ループ中のCodexが受信）
       （不明点は [QUESTION] / [ANSWER] 往復）
            ↓
3. Codex が feature/ブランチ作成 → 実装
       （画像が必要なら image gen で生成し assets/ 配置）
            ↓
4. Codex が flutter analyze / flutter test を通す
       → [DONE] 送信
            ↓
5. メインが agmsg-reviewer に diff レビューを委任
       （設計とは別コンテキスト）
            ↓
   ┌─ 6a. 指摘あり ─────────────────────────┐
   │ [REVIEW] request_changes 送信            │
   │   → Codex 修正 → [FIX_DONE] → 5. に戻る │
   └───────────────────────────────────────┘
            ↓ 6b. 指摘なし
   [REVIEW] approve 送信 → Codex が push
            ↓
7. メインセッションが PR 作成 → ユーザー承認後マージ
```

---

## 6. 運用ルール

- **完了条件**: `flutter analyze` エラー0 / `flutter test` 全パスをCodexが実装完了の必須条件とする。
- **ブランチ規約**: 全ての実装は `feature/` ブランチで行う（`CLAUDE.md` のGit運用ルールに準拠）。
- **single-writer原則**: 同時にコードを触るのはCodexのみ。`agmsg-reviewer` によるレビュー中、Codexは `[DONE]`・`[QUESTION]`・`[FIX_DONE]` 送信後の待機ループ（`AGENTS.md` 参照）で `[REVIEW]` を待つ。
- **push/PR作成のタイミング**: `[REVIEW] approve` を受け取るまで、Codexはpush・PR作成を行わない。
- **PRレビュー**: ハーネスモードではPRレビューはClaude側（`agmsg-reviewer`）が担当する。GitHub PRへの `@codex review` は任意の追加確認として扱う。

---

## 7. トラブルシュート

- **メッセージが届かない**: 手動で `$agmsg`（受信箱確認コマンド）を実行する。
- **アイドルのCodexにメッセージが届かない**: turnモードではメッセージはCodexのターン終了時にのみ配信される。対処: (1) 初回タスクは `start_codex.sh` の引数で渡す（起動前送信。agmsg が `--boot-prompt` 対応版の場合、`start_codex.sh` は自動的に初回プロンプトへタスクを載せる方式に切り替わる）、(2) Codexは `[DONE]`/`[QUESTION]`/`[FIX_DONE]` 送信後に待機ループ（`AGENTS.md` 参照）で返信を待つ運用とする、(3) それでもアイドルになった場合はCodexのターミナルで何か入力すれば次のターン終了時に配信される。リアルタイム配信が必要な場合は agmsg の Codex monitor bridge（BETA）があるが本ハーネスでは対象外。
- **monitorモードが効かない**: monitorモードはセッション再起動後に有効になる。設定直後のセッションでは反映されない。
- **sandbox利用時に書き込みエラーが出る**: `~/.agents/skills/agmsg/` への書き込み許可が必要。
  - Claude Code: settingsの `sandbox.filesystem.allowWrite` に `~/.agents/skills/agmsg` を追加する。
  - Codex: `config.toml` の `writable_roots` に `~/.agents/skills/agmsg` を追加する。
- **spawnが失敗する**: codex CLI が未導入、またはヘッドレス環境（GUIターミナルを開けない）である可能性がある。
