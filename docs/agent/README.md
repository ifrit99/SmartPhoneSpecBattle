# Loop Engineering（短い実装ループ）

目的: Claude Code に **observe → act → verify → 記録** を毎回同じ形で回させ、会話履歴依存を減らす。

既存の `docs/plans/`（Planner / Generator / Evaluator）は **中〜大タスク**用。  
`docs/agent/` は **今やる1件**（CI修正・小さなバグ・1〜2ファイル）用。

## いつ使うか

| 規模 | 使うもの |
|------|----------|
| 小（1文で説明、2ファイル以下、CI/バグ） | **`docs/agent/` ループ** |
| 中（新画面 or 3ファイル以上） | `docs/plans/` + Planner/Generator |
| 大（複数画面・複雑な状態） | `docs/plans/` 全3役 |

## ファイル

| ファイル | 役割 |
|----------|------|
| `GOAL.md` | 今の1目標（1〜5行）。同時に複数目標を置かない |
| `PLAN.md` | 次の最大3手。完了した手は消すか打ち消す |
| `DECISIONS.md` | 決めたこと・やらないこと（再発防止の1行メモ） |
| `VERIFY.md` | 合格条件とコマンド。完了の定義はここだけ |
| `START_PROMPT.md` | Claude Code に貼る起動文 |

## 運用ルール

1. 作業開始時: `GOAL.md` と `VERIFY.md` を埋める（人間 or Claude に1回書かせる）
2. Claude Code に `START_PROMPT.md` を貼る
3. ループ中は会話に状態を溜めず、**この4ファイルを更新**させる
4. `VERIFY.md` が全部 PASS したら終了 → PR 前は `AGENTS.md` 観点も確認
5. 停止条件に当たったら人間へ戻す（勝手にスコープ拡大しない）

## 役割分担（変更なし）

- **Claude Code**: このループで実装・検証・記録
- **Codex**: PRレビュー（`AGENTS.md`）
- **Hermes**: 秘書。`lib/` や git 本体は触らない
