# agmsg ハーネス 運用課題レトロスペクティブ

作成日: 2026-07-10
記録者: Claude Code（オーケストレーター役）
対象: `docs/agmsg_harness.md` のハーネスを Phase 5 実装（F1: 分析基盤、F2: エラー監視）で初運用した際に観測した摩擦点
目的: 今後のハーネス改善の材料。関連: `docs/agmsg_harness.md`、`scripts/agmsg/setup.sh`、`scripts/agmsg/start_codex.sh`

---

## 0. 要約

三役分離（設計＝designer / 実装＝Codex / レビュー＝reviewer）の**設計思想自体は機能した**（reviewer が独立に approve、Codex CLI の実装品質も高く F1 は 385 テストパス）。一方で、**運用上の摩擦が大きく、オーケストレーター（Claude）が push・リカバリ・進行監視を都度手当てして回す必要があった**。摩擦の主因は「環境前提のズレ（tmux外・ヘッドレス）」「通知チャネルの脆さ」「Codex 使用上限」「共有 worktree でのローカル git ref 破損」の4系統。

深刻度: 🔴=フロー停止級 / 🟡=手当てで回避可 / 🟢=軽微

---

## 1. 観測した問題点

### P1 🔴 サブエージェント定義が同一セッションで反映されない
- **事象**: `agmsg-designer` / `agmsg-reviewer` を master にマージしても、その定義を読み込む前に開始していた実行中セッションのエージェント登録には載らず、`subagent_type: "agmsg-designer"` が `Agent type not found` で失敗した。
- **原因**: サブエージェント定義はセッション起動時に読み込まれる。稼働中セッションへ後から追加した定義は反映されない。
- **今回の回避**: 役割定義（`.claude/agents/*.md` の内容）を `general-purpose` エージェントのプロンプトに埋め込んで代替。三役分離の原則（別コンテキストで設計/レビュー）は維持できた。
- **改善案**: (a) `docs/agmsg_harness.md` のセットアップ手順に「サブエージェント定義を追加/変更したらセッション再起動が必要」を明記。(b) ハーネス導入は専用セッションで行い、以後のタスクは新セッションで開始する運用を推奨。

### P2 🔴 inbox ストリーム（Monitor / watch.sh）が spawn・setup のたびに kill される
- **事象**: `setup.sh` の AGMSG-DIRECTIVE に従い Monitor で inbox ストリーム（`watch.sh`）を起動しても、その後 `start_codex.sh`（内部で `spawn.sh`）を実行するたびに watch.sh が停止し、Codex からの `[DONE]` 等の自動通知チャネルが失われた。
- **原因**: agmsg の setup/spawn 系スクリプトは既存の watch.sh プロセスを kill する仕様（setup.sh 出力にも「Existing watch.sh processes have already been killed」と明記）。Codex を spawn するたびに Claude 側の watcher が巻き添えで落ちる。
- **今回の回避**: Monitor 依存をやめ、`history.sh` を読み取り専用でポーリングする background ループに切替（spawn の影響を受けず、git にも触れない）。
- **改善案**: (a) spawn/setup が「自分以外（別エージェントの）watch.sh」を kill しないようにする。(b) Claude 用 watcher と Codex spawn のライフサイクルを分離。(c) 当面はドキュメントに「Codex spawn 後は inbox ストリームが落ちるため、履歴ポーリングにフォールバックする」ことを明記。

### P3 🟡 turn モードのアイドル Codex が2件目以降の [TASK] を自動で拾わない
- **事象**: t1 完了後にアイドル化した Codex へ t2 を `send.sh` で送っても、15分待っても着手されなかった（ブランチ未作成・応答なし）。
- **原因**: turn モードの Codex は自分のターン終了時にしか受信箱を確認しない。`[DONE]`/`[ANSWER]` 後にアイドル化すると次ターンが発生せず、キューされた [TASK] が配信されない（`docs/agmsg_harness.md` §7 の既知挙動）。`start_codex.sh` は「初回タスクを起動前送信」に最適化されており、2件目以降のタスク投入手段が弱い。
- **今回の回避**: 新規 Codex を t2 タスク付きで再 spawn（起動時の初回ターンで受信箱チェック→着手）。ただし旧アイドル Codex のターミナルが残る点は未解決。
- **改善案**: (a) 連続タスク運用のため、Codex 側に「[DONE] 後も一定間隔で受信箱を再確認する常駐ループ」を持たせる（AGENTS.md 強化）。(b) monitor bridge（BETA）の採用検討。(c) 手動運用として「次タスク投入時は旧 Codex を despawn → 新規 spawn」を手順化。

### P4 🔴 Codex の使用上限が push と code review をブロック
- **事象**: Codex CLI の**実装自体は正常動作**（t1 で fbcfa13 をコミット）したが、(1) `git push`（権限承認）と (2) GitHub の `@codex review` がいずれも「使用上限に達した」で拒否された。
- **原因**: Codex の使用上限。実装（CLI コーディング）と、権限承認を要する操作／コードレビュー連携は別枠で、後者が先に上限に達したとみられる。
- **今回の回避**: push はオーケストレーター（Claude）が代行。`@codex review` は使えないため、独立レビューは agmsg-reviewer で担保（ハーネス上 `@codex review` は「任意の追加確認」の位置づけなので原則問題なし）。
- **改善案**: (a) ハーネスの役割分担表に「push はオーケストレーターが担当」と最初から明記（Codex に push させない設計にする）。(b) GitHub `@codex review` はハーネスモードでは使わない前提を明確化。

### P5 🟡 共有 worktree でのローカル git 状態の破損・ハング
- **事象**: (1) `gh pr merge --delete-branch` のローカル後処理が worktree 制約でハング（API マージは成功済み）。(2) その中断影響で、共有 git ディレクトリの `refs/remotes/origin/master` が loose ref と packed-ref で食い違い、`git fetch` が exit 0 でも ref を更新しない状態に。(3) `GIT_TERMINAL_PROMPT` 未設定だと `git fetch` が認証プロンプト待ちで2分ハング。
- **原因**: 複数 worktree が共有する common git dir に対し、中断された gh のローカル後処理が remote-tracking ref を壊した。認証は push ではキャッシュされていたが fetch 経路で対話プロンプトに落ちた。
- **今回の回避**: (a) マージは GitHub API 側の成功を真実源とし、ローカル同期不整合は作業に影響しないと判断（PR 差分はサーバー側計算）。(b) 分岐は「マージ済み master とコード等価」と検証済みの現行 HEAD から作成。(c) fetch は `GIT_TERMINAL_PROMPT=0` を付与。
- **改善案**: (a) マージ後のローカル同期は `gh pr merge` の `--delete-branch` に頼らず、API マージ + 別途 API ブランチ削除に分ける。(b) ハーネス運用は「GitHub を真実源」とし、ローカル remote-tracking ref に依存しない。(c) git 系コマンドは常に `GIT_TERMINAL_PROMPT=0` を付ける運用を明記。

### P6 🟡 tmux 外 spawn が GUI 新ターミナルウィンドウ依存
- **事象**: TMUX 未設定（tmux 外）のため、`spawn.sh` は Codex を「新規ターミナルウィンドウ」で起動した。ヘッドレス/リモート環境ではこの前提が脆い。
- **原因**: `start_codex.sh` は tmux 内ならペイン分割、tmux 外なら新規ターミナルウィンドウを開く設計。GUI ターミナルを開けない環境では失敗しうる。
- **今回の回避**: macOS GUI 環境だったため spawn 自体は成功したが、起動した Codex ターミナルはオーケストレーターからは不可視で、進行は agmsg 経由のメッセージでしか把握できなかった。
- **改善案**: (a) tmux 内運用を強く推奨（`docs/agmsg_harness.md` に明記）。(b) ヘッドレス対応の spawn（バックグラウンド/ログファイル方式）を用意。

### P7 🟡 未追跡の計画ファイルが Codex の一括 add に巻き込まれるリスク
- **事象**: designer が working tree に `docs/plans/{feature}.md` を書き、同じ共有 tree で Codex が実装・`git add` する運用のため、Codex の一括 add（`git add -A` 等）に他の未追跡ファイルが混入する懸念がある。
- **原因**: 設計成果物（plan）と実装が同一 working tree・同一ブランチ生成タイミングを共有している。single-writer 原則（同時にコードを触るのは Codex のみ）とも相性が悪い。
- **今回の回避**: [TASK] メッセージで「対象ファイルを明示」「未追跡の plan も一緒にコミット」を指示。オーケストレーター側の別ドキュメント（本ファイル等）は working tree に置かず plumbing で別ブランチにコミット。
- **改善案**: (a) plan ファイルは designer が専用コミット/専用ブランチに載せてから Codex へ渡す。(b) Codex には対象パスを明示し、`git add -A` を避ける運用をルール化。

---

## 2. 機能した点（残すべき設計）

- **三役分離の思想**: 設計・実装・レビューを別コンテキストで回す原則は、実際にレビュー担当が独立して approve を出し、自己評価バイアスを避けられた。
- **Codex CLI の実装品質**: t1（F1）は 22 ファイル・+890 行を計画どおり実装し、385 テストパス。実装エンジンとしては信頼できた。
- **メッセージプロトコル**: `[TASK]/[DONE]/[REVIEW]/[BLOCKED]` の型は、進行状態の把握とハンドオフに有効だった。特に `[BLOCKED]` は push 上限を即座にエスカレーションできた。
- **plan ファイル駆動**: `docs/plans/{feature}.md` を仕様の単一の真実源にする方式は、designer→Codex→reviewer のハンドオフを明確にした。

---

## 3. 優先度付き改善提案（次アクション候補）

| 優先 | 提案 | 対応先 |
|------|------|--------|
| 高 | 役割分担表に「push はオーケストレーターが担当（Codex に push させない）」を明記 | `docs/agmsg_harness.md` P4 |
| 高 | 「サブエージェント定義の追加/変更後はセッション再起動が必要」を明記 | `docs/agmsg_harness.md` P1 |
| 高 | spawn/setup が他エージェントの watch.sh を kill しないよう修正、or「spawn 後は履歴ポーリングにフォールバック」を明記 | agmsg本体 / ドキュメント P2 |
| 中 | 連続タスク運用のための Codex 常駐受信ループ強化、または「次タスクは despawn→再spawn」の手順化 | AGENTS.md / ドキュメント P3 |
| 中 | git 操作は `GIT_TERMINAL_PROMPT=0`、マージは API のみ＋別途ブランチ削除、GitHub を真実源にする運用を明記 | ドキュメント P5 |
| 中 | tmux 内運用を推奨、ヘッドレス対応 spawn を用意 | `start_codex.sh` / ドキュメント P6 |
| 低 | plan ファイルの受け渡しを専用コミット/ブランチ化、Codex に対象パス明示 | ドキュメント P7 |

---

## 4. 総括

現状のハーネスは「クリーンな前提（tmux 内・サブエージェント読込済みセッション・Codex 使用上限に余裕・単一 worktree）」では設計どおり機能するが、それらが崩れると通知・push・git 同期の各所でオーケストレーターの手当てが必要になる。**まず高優先の3点（push 役割分担・セッション再起動明記・watcher の kill 回避）を潰すだけで、運用摩擦は大きく下がる見込み**。
