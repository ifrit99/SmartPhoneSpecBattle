# SmartPhoneSpecBattle - CONTEXT

## 開発体制
判断基準・担当の正本は [`AGENTS.md`](AGENTS.md)。
- **実装・テスト・PR 作成**: Cursor Cloud Agent `grok-4.6`。エージェントは `feature/` ブランチへの push と PR 作成まで。
- **`master` への push・PR のマージ・本番デプロイは人が行う。** エージェントはこれらを行わない。
- **Claude Code** は現在使わない（`CLAUDE.md` は `AGENTS.md` への互換入口のみ）。
- **レビュー**: ChatGPT Plus が使えるときは Codex。それ以外は thermos + grok-4.6 high。

## 作業フロー
1. **作業開始時**: `docs/TODO.md` を読み込み、現在の状況と残タスクを把握する。
2. **作業終了時**: 自身の行った変更と次のタスクを `docs/TODO.md` に更新する。

## 検証手段（完了条件）
コードの追加や変更を行った後、タスクを「完了」とする前に、以下のコマンドを実行しエラーゼロであることを確認すること。
- **静的解析**: `flutter analyze`
- **ユニットテスト**: `flutter test`
両方を通過して初めて、機能実装完了とみなすこと。
