# SmartPhoneSpecBattle - CONTEXT

## 開発体制
共通の内側ループ・検証は ifrit99/life の `dev/rules/` を読む（写さない）。このリポの例外は [`AGENTS.md`](AGENTS.md)。
エージェントは `feature/` ブランチへの push まで。`master` への push・PR のマージ・本番デプロイは人が行う。

## 作業フロー
1. **作業開始時**: 判断基準は `AGENTS.md`。再開なら該当する `docs/plans/<件名>.md` の完了条件と記録欄を先に読む。`docs/TODO.md` は機能別の残タスク一覧として必要なら見る（横断進捗の入口にはしない）。
2. **作業終了時**: 計画ファイルの記録欄へ「済んだこと・次の一手・判断待ち」を 1 行足す。計画ファイルが無いときは作らず、PR 本文に 1 行残す。ローカルで STATUS.md が読めるときだけ当該タスクを更新する。`docs/TODO.md` への毎回更新はやめる。

## 検証手段（完了条件）
共通の確かめ方は life の [`dev/rules/verification.md`](https://github.com/ifrit99/life/blob/main/dev/rules/verification.md)。このリポの安い確認は次の 2 つ。コードの追加や変更を行った後、タスクを「完了」とする前にエラーゼロであること。
- **静的解析**: `flutter analyze`
- **ユニットテスト**: `flutter test`
`Verified:` はコミット末尾の trailer（`none` も）。この行が無いことだけで完了や CI を落とさない。
