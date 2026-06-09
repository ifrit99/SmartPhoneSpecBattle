# Planner / Generator / Evaluator ワークフロー

## 概要

役割分離による品質向上とコンテキスト肥大化の抑制を目的とした3エージェント構成。
各役割は**別のClaude Codeセッション**で実行し、ハンドオフは `docs/plans/{feature-name}.md` で行う。

---

## タスク規模別の運用ルール

| 規模 | 基準 | 使うエージェント |
|------|------|-----------------|
| **小** | 1文で説明でき、2ファイル以下 | Generator のみ |
| **中** | 新画面 or 3ファイル以上 | Planner + Generator |
| **大** | 複数画面・複雑な状態遷移 | 全3エージェント |

**Evaluator の起動基準**: UIフロー、状態遷移、エッジケースなど「エラー0 ≠ 正しく動く」機能のみ。

---

## Plan ファイルテンプレート

`docs/plans/{feature-name}.md` として作成:

```markdown
# Plan: {機能名}
Created: {date}
Status: PLANNING | IN_PROGRESS | EVAL | DONE | REJECTED

## 要件
{ユーザーの要求を1-3文で}

## 仕様
### 画面/UI変更
- {画面名}: {変更内容}

### ロジック/状態変更
- {ファイル}: {変更内容}

### 新規ファイル
- {パス}: {目的}

### テスト基準
- [ ] {具体的に検証可能な条件}

### 完了条件
- [ ] flutter analyze: エラー0
- [ ] flutter test: 全パス
- [ ] {機能固有の手動チェック}

---
## Generator ログ
（Generator が実装時に追記）

---
## 評価
（Evaluator が検証結果を追記）
```

---

## プロンプトテンプレート

### Planner（新セッションで実行）

```
docs/TODO.md を読んで現在のプロジェクト状況を把握してください。

タスク: {ユーザーの1-2文の要求}

docs/plans/{feature-name}.md に計画ファイルを作成してください。
構成:
- 要件（私のリクエストを引用）
- 仕様: 画面/UI、ロジック/状態、新規ファイル（lib/data/, lib/domain/, lib/presentation/ の3層に沿って）
- テスト基準（ブラウザで何を確認すべきか、具体的に）
- 完了条件（flutter analyze + flutter test + 機能固有チェック）

仕様は50行以内に収めてください。既存コードを参照する場合は該当ファイルだけ読んでください。
Status を PLANNING にセットしてください。
```

### Generator（新セッションで実行）

```
docs/plans/{feature-name}.md を読んでください。これが実装仕様です。仕様に従って実装してください。

ルール:
- feature/{feature-name} ブランチで小さいコミット単位で作業
- 論理的なまとまりごとに flutter analyze と flutter test を実行
- 計画から逸脱する場合は Generator ログに理由を追記
- 完了したら Status を EVAL に変更
- docs/TODO.md を更新

計画ファイルと CLAUDE.md 以外のドキュメントは、変更対象ファイルの理解に必要な場合のみ読んでください。
```

### Evaluator（新セッションで実行）

```
あなたは厳格な評価者です。docs/plans/{feature-name}.md を読んでください。

以下のチェックを順に実行してください:
1. flutter analyze — エラー0であること
2. flutter test — 全テストパスであること
3. git diff master...HEAD — 変更されたファイルを計画の仕様と照合
4. 計画のテスト基準を1つずつ検証（UI確認が必要なら browse ツールを使用）

各基準について PASS / FAIL と1行の理由を記載してください。
FAIL がある場合: Status を REJECTED にし、Generator が修正すべき点をリスト化。
全 PASS の場合: Status を DONE に変更。

計画ファイルの「評価」セクションに結果を追記してください。
「エラーがない」と「正しく動く」は別です。懐疑的に検証してください。
```

### REJECTED 時のリトライ（新 Generator セッション）

```
docs/plans/{feature-name}.md を読んでください。評価セクションで REJECTED されています。指摘された問題を修正してください。
```

---

## フロー

```
ユーザー: 要求を1-2文で書く
    ↓
[Planner セッション] → docs/plans/{feature}.md 作成 (Status: PLANNING)
    ↓
ユーザー: 計画を確認・承認
    ↓
[Generator セッション] → コード実装 + テスト (Status: IN_PROGRESS → EVAL)
    ↓
[Evaluator セッション] → 検証 (Status: DONE or REJECTED)
    ↓ REJECTED の場合
[Generator セッション（新規）] → FAIL 項目を修正 → 再度 EVAL
    ↓ DONE の場合
ユーザー: PR作成 → Codex レビュー → マージ
```

---

## ファイルライフサイクル

1. **作成**: Planner が `docs/plans/{feature-name}.md` を作成（Status: PLANNING）
2. **実装**: Generator が追記（Status: IN_PROGRESS → EVAL）
3. **評価**: Evaluator が追記（Status: DONE or REJECTED）
4. **完了後**: マージ後もそのまま残す（小さいファイルなので削除不要）
