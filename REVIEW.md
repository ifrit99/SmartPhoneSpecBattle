# REVIEW.md — SmartPhoneSpecBattle のレビュー基準

レビューする AI（GitHub のレビューボット、thermos、受入テスト）向けの正本。担当や流れは [AGENTS.md](AGENTS.md)、書き方の規約は [docs/coding_rules.md](docs/coding_rules.md) を見る。ここには「このリポで何が壊れると困るか」だけを書く。

## 返し方
- 最初の1行は件数にする。例:「重大 1 / 軽微 2 / 前からある 1」。直すところが無ければ「直すところなし」とだけ書く。
- 指摘には札を1つ付ける。**重大**（直すまでマージ不可）／**軽微**（マージは止めない。1回のレビューで3件まで）／**前からある**（この PR が入れたものではない。マージは止めない）。
- 証拠は `ファイル:行` で示す。名前からの推測だけで指摘しない。
- 何がまずいか、なぜ困るか、どう直すかを短く書く。日本語で書く。
- 見た目の好み・言い回し・整形だけの指摘はしない。
- 同じ種類の誤りが他の場所にもあれば、1行ではなく「この種類を全部」と書く。
- 状態・フラグ管理、空の状態やスキップの流れの分岐漏れを見る。足りないテストがあれば指摘する。

## 往復のルール
- 1回目は全体を見る。2回目以降は前回からの差分だけを見る。
- 前に出した指摘をくり返さない。答えが付いた指摘は蒸し返さない。
- 3往復しても重大が残るなら、それ以上直させない。「やり方を見直す」と書いて止め、参謀に返す。
- 指摘はすべて「直した（コミット）」か「直さない理由」のどちらかで答えが付くまでマージしない。
- エージェントにできない確認（実機、本番コンソール、GitHub の設定）は往復に数えない。指摘のまま止めず、PR 本文の「イフリトさんがやること」に移して閉じる。

## 危なさの区分（変更内容で決める。作者では決めない）
PR 本文の区分が低すぎないかを必ず見る。1ファイルでも上の区分に当たれば、PR 全体がその区分になる。

| 区分 | 当たるもの |
|---|---|
| 高 | 通貨・ガチャ・報酬・ショップ（`currency_service` `gacha_service` `*_reward_*` `daily_shop` `season_pass` `achievement` `daily_mission` `weekly_challenge` `limited_event` `player_rank` `boss_bounty` `rival_road` `battle_result_service` `serial_executor`）、保存とバックアップ（`lib/data/local_storage_service.dart` `data_backup_screen`）、Firebase（`firestore.rules` `firestore.indexes.json` `firebase.json` `lib/data/firebase_*` `firestore_ranking_backend` `ranking_service`）、CSP と配信（`web/_headers` `web/index.html` `wrangler.toml`）、CI と自動化（`.github/workflows/**` `dependabot.yml`）、同意と個人データ（`analytics*` `privacy_settings_screen` `error_monitoring` `sentry_options`）、共有 URL の形式（`character_codec` `qr_battle_service`）、依存の追加（`pubspec.yaml`） |
| 中 | 上以外の `lib/**` と `assets/**`、エージェントへの指示（`AGENTS.md` `CLAUDE.md` `REVIEW.md` `CONTEXT.md` `.claude/**` `.cursor/**` `.agents/**` `.github/pull_request_template.md`）、`tool/**`、Dependabot の版上げ |
| 低 | `docs/**` とその他の `.md`（上の指示ファイルを除く）、テストだけの追加・修正（`test/**`） |

## イフリトさんの関わり（判断1・2はおすすめどおり確定）
- **低（判断1）**: 参謀が1日分をまとめて「低 N 件、全部緑。まとめてマージ？」と聞く。答えは1回だけ。1か月事故が無ければ「参謀が自動でマージ」に緩めるか、また聞く。
- **中**: 1件ずつマージ。見た目が変わるときは見た目の OK も。
- **高（判断2）**: 1件ずつマージ。エージェントに確かめられないこと（iPhone 実機など）はマージ前に止めない。マージ前は Chrome headless で CSP 違反 0 まで必須。マージ直後に参謀が1つだけ頼む。だめなら PR に書いた戻し方で戻す。

## このリポでの「壊れた」の姿
### 通貨・報酬（高）
- **増える**: 同時に受け取ると二重に付く（#69）。受取済みの確認と付与の間に別の処理が割り込めないかを見る。
- **消える・上書きされる**: 2つの加算が重なり片方の残高が消えた（#72）。保存失敗で残高だけ変わった（#75）。付与が失敗して報酬が消えた・コインだけ入ってジェムが付かない（#77）。通貨の読み書きは `CurrencyService` の直列化を通っているか、失敗時に呼び出し前へ戻るかを見る。
- ガチャで通貨を減らしたあとキャラ保存が失敗すると、通貨だけ減る（#77 の残り）。ガチャを触る PR はここを必ず見る。
- 通貨まわりを変えたら `bash .claude/skills/currency-ledger-verify/run.sh` の結果が PR にあるか。モデルが実装とずれていないか（#76 #78 で直した種類）。

### 起動と本番（高）
- **黒画面**: 設定があるときに Firebase を起動時に初期化して黒画面になった（#58 で直してからマージ）。Firebase はランキング参加を ON にするまで初期化しない。`main` や `ServiceLocator.init` から呼んでいないかを見る。
- **CSP で動かない**: Firebase が書くインラインスクリプトを CSP が止め、本番でランキング参加が失敗した（#58 のあと見つかり #82 で修正）。`script-src` に `'unsafe-inline'` は足さない。ハッシュで許す。firebase の版やサービスを変えたら `web/_headers` のハッシュとテストも変わっているか。
- Firestore ルールはマージしても本番に効かない（コンソールで人が公開する）。PR に「マージ後にやること」があるか。

### 秘密（高）
- キー・トークン・パスワードの値がコード、PR 本文、テスト、ログ出力に入っていないか。
- ワークフローで秘密を表示していないか。本番用トークンが本番以外の実行から使えないか（#79）。
- Firebase の Web 用 API キーは公開前提なので値が見えても漏えいではない。ただしルールが緩いと誰でも書ける。

### 共有 URL（高）
- 形式を変えて既存の URL が開けなくならないか。

### ドキュメント（低）
- 壊れた姿は「うそ」。今の運用やコードと合っているか。リンク先が存在するか。

## 見なくてよいもの
- `pubspec.lock`（`pubspec.yaml` の変更に合っていればよい）
- `assets/**` の画像の中身（見た目の判断はイフリトがする）
- `docs/plans/` の古い計画、`docs/agmsg_harness.md` などの旧文書

## くり返す指摘はここへ
同じ指摘が2つの PR で出たら、この REVIEW.md か `docs/coding_rules.md` に1行足す。本番で起きた不具合は `docs/incidents.md` と上の「壊れた」の姿の両方に書く。
