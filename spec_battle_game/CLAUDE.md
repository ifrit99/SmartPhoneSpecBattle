# SmartPhoneSpecBattle

各種仕様やルールについては、コンテキスト情報の重複・肥大化を防ぐため「Less is More & Progressive Disclosure」の原則に基づき、以下の分割されたドキュメントを必要に応じて段階的に参照してください。

## 🤖 AI向け：最初に読むべきファイル (絶対ルール)
- 作業開始前に必ず **`CONTEXT.md`** と **`docs/TODO.md`** を読み、AIエージェントの役割（Antigravity / Claude Code）や現在の実装状況を把握すること。

## 📚 ドキュメント構成
- `README.md`: プロジェクトの目的と使用技術スタック等の概要
- `docs/architecture.md`: アーキテクチャと設計方針（3層レイヤー構造）、状態管理とWidget分割の基準
- `docs/coding_rules.md`: 命名規則、Null Safety、コード構造の実装ルール
- `docs/TODO.md`: 現在の実装状況のサマリーと、次に取り組むべき残タスク
- `PHASE4_SPEC_DRAFT.md`: 将来の機能拡張案（ガチャ・QR対戦等）の詳細仕様

**※注意:** 新規ドキュメントを作成する場合は `docs/` ディレクトリ内に配置し、このファイルから適宜リンクを追加してください。
