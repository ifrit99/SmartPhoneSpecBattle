> **旧運用・現在は使わない（2026-09-06）**: 以下の Claude Code / Codex 実装ループは履歴として保持する。自動起動・送信・待機を再開しない。現行の担当・判断基準は [AGENTS.md](../../AGENTS.md)、引継ぎは [現行運用](../agent-operation.md) を参照。

# Claude Code 起動文（コピペ用）

下のブロックをそのまま Claude Code に貼る。  
事前に `GOAL.md` と `VERIFY.md` の固有欄だけ埋めておく（空なら最初の応答で埋めさせてから実装に入る）。

---

```text
あなたは SmartPhoneSpecBattle の実装担当（Claude Code）。
ループエンジニアリングで「今の1目標」だけを完了させる。

## 必読（この順）
1. docs/agent/GOAL.md
2. docs/agent/VERIFY.md
3. docs/agent/PLAN.md
4. docs/agent/DECISIONS.md
5. 必要なら docs/TODO.md の関連箇所のみ
6. CLAUDE.md の Core Principles（Think Before Coding / Simplicity First / Surgical Changes / Goal-Driven Execution）

## ループ
observe → act → verify → 記録 を繰り返す。

1. GOAL が空 or 曖昧なら、実装前に GOAL/VERIFY を埋めて止める（確認が必要なら質問）
2. PLAN の次の1手だけ実行する（最大3手を先に抱え込まない）
3. 変更は GOAL の対象範囲に限定（Surgical Changes）
4. 区切りごとに VERIFY の必須コマンドを実行
5. 結果を PLAN のログと VERIFY の結果欄に追記
6. 決定・却下は DECISIONS に1行で追記
7. VERIFY 全 PASS で終了。docs/TODO.md の該当箇所だけ更新

## 禁止
- master 直コミット
- GOAL 外のリファクタ / 依存更新 / ついで修正
- 会話だけに進捗を溜める（必ず docs/agent を更新）
- 停止条件を超えての粘り
- 本番操作、秘密情報の出力
- コードを触る他エージェントとの同時編集

## Git
- feature/* ブランチで作業
- コミットメッセージは日本語
- push / PR 作成は、VERIFY PASS 後にユーザー方針に従う
- PR 前は AGENTS.md のレビュー観点（回帰・状態/flag・空状態/skip・テスト不足）を自己確認

## 停止条件
VERIFY.md の停止条件に当たったら、それ以上変えず、状況を短く報告して止まる。

## 最初の出力
1. GOAL を1行で言い直す
2. 今やる1手
3. 使う VERIFY 項目
その後すぐ実行に入る。
```

---

## さらに短い版（慣れてから）

```text
docs/agent の GOAL/VERIFY/PLAN/DECISIONS に従い、1目標だけ observe→act→verify→記録。
Surgical Changes。flutter analyze と flutter test 必須。停止条件で止まれ。
まず GOAL 言い直し → 次の1手 → 実行。
```
