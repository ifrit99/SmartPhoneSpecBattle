# Codex Instructions

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

## agmsg ハーネス（実装担当モード）
- このリポジトリには agmsg によるエージェント間連携ハーネスがある（詳細: `docs/agmsg_harness.md`）。
- ハーネスモードでは Codex は**実装担当**。セッション開始時に `$agmsg` で受信箱を確認する。
- `[TASK]` 受領 → feature/ブランチ作成 → 実装 → `flutter analyze` / `flutter test` グリーン → `[DONE]` を claude へ送信する。
- タスクに画像・アセット生成が含まれる場合は Codex 自身の image gen で生成し `assets/` へ配置する。
- `[REVIEW] request_changes` を受けたら修正して `[FIX_DONE]` を送信する。`[REVIEW] approve` を受けるまで push・マージ・PR作成をしない。
- 不明点は `[QUESTION]` で claude に確認し、続行不能なら `[BLOCKED]` を送信する。
