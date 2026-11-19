# Plan: 検証のしくみを SSB に取り入れる
Created: 2026-11-17
Status: PLANNING

## 要件
Claude Code チームの検証の記事と、pstack の検証スキル 4 つを SSB に取り入れる。何を今やり、何をあとにし、何をやらないかを決める。最初の一切れは PR 1 本に収める。

この設計は **SSB 固有のことだけ**を書く。内側ループの全リポ共通のルールは、life の Project が別に設計している。共通ルールの文はここに写さない。共通ルールに当たる項目は「共通ルール側」とだけ書き、SSB のどのファイルに当てはまるかだけを書く。

出典:
- https://claude.dev/blog/how-the-claude-code-team-thinks-about-verification/ （2026-11-16、Addy Osmani）
- https://x.com/ClaudeDevs/status/2122457608963395586 （この環境からは 403 で読めない。記事の告知と見て、中身は記事で判断した）
- pstack 0.15.43（Cursor プラグイン）。使うのは `create-verification-skill` `maintain-verification-skill` `create-formal-verification-skill` `maintain-formal-verification-skill` の 4 つ。プラグインの置き場所はマシンごとに違うので、スキル名で探す。

## いまの SSB（判断の前提。確かめたのは origin/master `718a7e0`）
- CI（`.github/workflows/ci.yml`）: `flutter analyze` / `flutter test` / UX perf の記録（閾値なし＝測るだけ）/ `flutter build web --release`。動くアプリは誰も起動していない。
- 本番で起きた事故は、どちらも「起動して初めて分かる」種類だった。黒画面（#58）と、CSP によるランキング参加の失敗（#82）。単体テストは緑のままだった。
- **通貨の TLA+ はリポにある。** #74 で入り、#76・#78 で直した。`.claude/skills/currency-ledger-verify/` に `SKILL.md` `run.sh` `CurrencyService.tla` `CurrencyService.cfg` `CurrencyServiceNoUnmark.cfg` がある。
  - 同期記録のコミットは `b3848753`（#77）。
  - そこから `origin/master` までに、モデルが見ているファイルの差分は 0。見ているファイルは `currency_service.dart` `serial_executor.dart` `local_storage_service.dart` `limited_event_service.dart` `gacha_service.dart`。
- 実装席（Cloud Agent `grok-4.6`）には Flutter 3.44.0 と headless Chrome があり、`tlc` は無い（#82・#89・#77 の PR 本文）。#77 では TLC の本検査をレビュー担当に回した。この設計スレッドの VM には Flutter が無い。
- pstack は Claude Code 向けに `.claude/settings.json` で有効になっている（#71）。参謀の箱の Claude Code でも使える。
- このチェックアウトのスキルは `.claude/skills/*` から見つかる。`midway-check` は `.claude/skills/midway-check -> ../../.agents/skills/midway-check` の symlink 経由で見えている。
- 前回の verify スキル（[#33](https://github.com/ifrit99/SmartPhoneSpecBattle/pull/33)、`cursor/verify-ssb-skill-0d2d`）は 1,018 行で、Mac の Cursor ブラウザが前提だった。Cloud では動かず、下書きのまま閉じた。
- マージのしかた: リポは merge・squash・rebase のどれも許している。squash のメッセージは `COMMIT_MESSAGES` で、全コミットのメッセージを古い順に並べる。最近は squash が多い（#81 #83 #85 #87）。merge commit もある（#82、タイトルだけ）。

## pstack の 4 スキルを SSB でどう使うか
4 つとも `disable-model-invocation: true` なので、エージェントが自分からは使わない。使う回の依頼文にスキル名を書き、エージェントに `SKILL.md` を読ませる。

| スキル | やること・成果物 | SSB での制約 | 判定 |
|---|---|---|---|
| `create-verification-skill` | リポを読み、アプリを起動して操作し、証拠を取るスキルを作る。<br>節は Launch / Doctor / Drive / Evidence / Cleanup / Helpers。<br>`features/` に機能地図を 3〜5 件作る（H2 は `Sub-features` `How to get to it (user POV)` `Driving it with <harness>` `Gotchas` の 4 つ）。<br>渡す前に 1 回、通しで動かして証明する（起動 → Doctor → 1 機能を操作 → 証拠 → 片付け → 証拠が残っている） | 出力先の既定は `.cursor/skills/verify-<app>/`。SSB では `AGENTS.md` に従い、`.agents/skills/verify-ssb/` を正本にして `.claude/skills/verify-ssb` を symlink にする。<br>Flutter Web は canvas 描画なので、操作は座標ではなく Flutter のセマンティクス（aria ラベル）を CDP で掴む。<br>Cloud の実装席で動く（Flutter と Chrome がある） | **今（PR-1）** |
| `maintain-verification-skill` | 機能地図の点検。機能ごとに読む専用の子エージェントがソースを読み、親が 1 つのインスタンスで全機能を実際に操作する。結果は `clean` / `changed`（直しを PR 1 本）/ `blocked` のどれか。スキルのディレクトリしか直さない。製品の不具合は報告だけ | 子エージェントは Cursor 枠のモデルだけで回す（Fable は使わない、オンデマンドは使わない）。枠が足りなければ、親が機能を 1 つずつ順に読む。<br>Cloud で動く | **あとで**: PR-1 のマージ後。地図にある画面を変えた PR のあとと、月 1 回 |
| `create-formal-verification-skill` | 一番大事な約束を 1 つ選び、道具を選んで形式検証し、それを回すスキルを作る | SSB では済んでいる。`currency-ledger-verify` がこの形になっている（性質と害を 1 文ずつ、1 コマンド、同期記録のコミット、わざと壊すと落ちる一覧、範囲と前提） | **やらない**（今回）。次の候補はランキング参加の ON・OFF の競合（#80）。#80 が入ってから考える |
| `maintain-formal-verification-skill` | 同期記録のコミットから、見ているコードの差分を読む。モデルを直し、回し直す。失敗ごとに「モデルのずれ」か「コードの不具合」かを判定する（`in sync` / `updated` / `bug` / `blocked`）。モデルの直しは製品の修正と別の変更にする | TLC が要る。Cloud の実装席には無い → 参謀の箱で回す（次の節）。<br>このスキルは TLA+ の結果を pstack の `/statechart` で読むよう求めているが、`currency-ledger-verify` にはその 1 行が無い。最初の点検でスキルに足す | **あとで**: 見ているファイルを触った PR が同期記録のコミットを進めなかったとき、と月 1 回。今は差分 0 なので、回せば `in sync` の見込み |

### 参謀の箱の TLA+ とのつなぎ
- 正本はリポの `.claude/skills/currency-ledger-verify/` だけにする。`REVIEW.md` が指しているのもここ。
- 参謀の箱の `/workspace/ssb-formal-verify/` の中身は、この環境からは見えない（未確認）。
- 参謀は 1 回だけ、箱のモデルとリポの `.claude/skills/currency-ledger-verify/` を `diff -r` で比べる。
  - 違いがあれば、`maintain-formal-verification-skill` の手順でリポ側に PR を出して入れるか、捨てる。
  - そのあと箱には `tlc` と、リポのチェックアウトだけを置く。
- 回し方: 参謀の箱で PR の head をチェックアウトし、`bash .claude/skills/currency-ledger-verify/run.sh` を回す。PR が通貨のコードとモデルの両方を変えるときは、base の `run.sh` も PR の head のコードで回す。
- 結果は head の SHA を付けて Project に返す。実装席がそれを PR 本文に貼り、コミットの `Verified:` 行に `tlc(PASS <sha>)` を書く。
- 箱で使うのは Claude Pro 枠の Claude Code。pstack は `.claude/settings.json` で有効なので、`maintain-formal-verification-skill` もそこで回せる。

## 判断

### 今やる
| 項目 | どう入れるか | 理由 |
|---|---|---|
| `verify-ssb` スキル（起動とタイトル） | PR-1。`create-verification-skill` の手順で作る。機能地図は 3 件。証明するのは「起動とタイトル」1 件 | 事故 2 件（#58・#82）は起動して初めて分かる種類だった。pstack も、証明は 1 機能でよいとしている |
| コミットに検証方法を残す（`none` も） | PR-1。`Verified:` 行の約束（マージのしかたごと。下で書く）。ゲートは作らない | 費用ゼロ。あとで「検証なしのコミット」を数えられる |
| 通貨のプロパティテスト | PR-2。Dart のテストだけで書き、期待値は参照モデルの表で決める | TLC が Cloud に無いので、本物のコードを毎回テストで叩く層が要る。`create-formal-verification-skill` も、検証器が無い言語では本物のコードを生成した入力でテストせよとしている |
| SSB の「チェック」に当たるファイルを決める | PR-3。`REVIEW.md` に 1 行足す | 共通ルール側の「変更は自分を裁くチェックを書き換えない」を SSB に当てはめるため |
| 通貨のコードとモデルを同じ PR で変えたとき | PR-3。`REVIEW.md` の「通貨・報酬」に 1 行足す | SSB にしかない形 |

PR-3 で SSB の「チェック」として名指しするファイル: `REVIEW.md`、`AGENTS.md`、`.agents/skills/verify-ssb/**`、`.claude/skills/currency-ledger-verify/**`、`test/domain/currency_property_test.dart`、`test/domain/support/fault_injecting_storage.dart`、`.cursor/hooks/**`、`.github/workflows/ci.yml`。

### 共通ルール側に任せる（ここには書かない）
次は life の共通ルールで決まるものとして扱う。SSB は決まったものに従う。
- 基準（`REVIEW.md`）を PR の base から読む
- 古い head へのレビューは無効
- 3 回直しても落ちたら止める
- フレーキーなテストの扱い
- 新しいゲートは観察モードから
- レビュー担当は 1 人で調整する
- 規則を定期的に減らす

SSB 側で書くのは、上の「チェックに当たるファイル」の一覧と、フレークを消したときに理由を書く先（`docs/test-notes/known-risks.md`）だけ。

### あとで
| 項目 | いつ・どう | 今やらない理由 |
|---|---|---|
| 機能地図の残りを実際に操作する（CPU バトル、URL 対戦、ガチャ、初回の案内） | PR-1 のあと、`maintain-verification-skill` の最初の点検で | PR-1 を小さく保つ。pstack の証明は 1 機能でよい |
| `maintain-verification-skill` を定期的に回す | 上の表のとおり | 地図ができてから |
| `maintain-formal-verification-skill` | 上の表のとおり。参謀の箱で | 今は差分 0 |
| `Verified:` の観察ゲート | PR-1 の約束が 10 PR ほど回ったあと。CI でログに出すだけにする（落とさない） | CI は区分「高」 |
| CI で `verify-ssb` を回す | 観察ゲートのあと | ビルドが 2 回になる。PR-1 で所要時間を測ってから |
| 共有 URL・バックアップのラウンドトリップ（プロパティ） | PR-2 のあと | 既存の例ベースのテストが厚い（`test/domain/character_codec_test.dart` 475 行） |
| Cloud で TLC を回す | 版を固定した `tla2tools.jar` をハッシュ確認つきで取る形を `run.sh` に足す | 参謀の箱で回るなら急がない |
| `currency-ledger-verify` を `.agents/skills/` へ移す | 互換は symlink | 動いているものを今回動かさない |

### やらない
| 項目 | 理由 |
|---|---|
| `create-formal-verification-skill` で通貨をもう一度作る | 済んでいる |
| 新しい依存（`glados`、`integration_test`、npm、pub のテスト用パッケージ） | 区分「高」になる。シード固定の `Random` と Python の標準ライブラリで足りる |
| Mac の Cursor ブラウザ前提の verify（#33 の形） | Cloud の実装席で動かない |
| コミットを止める enforce のゲート | 観察で誤検知を見る前に止めない。Cursor hook はタイムアウト 10 秒で、テストを回す用途に合わない |

## 最初の一切れ（PR-1）: `verify-ssb`（起動とタイトル）と `Verified:` 行

区分: **中**（`AGENTS.md` `.agents/**` `.claude/**`）。製品コード・CI・pubspec は触らない。見た目は変えないので途中確認は不要。

### 作り方
実装スレッドへの依頼文に「pstack の `create-verification-skill` の `SKILL.md` を読み、その手順で作る」と書く。SSB 向けの上書きは次の 4 つ。
1. 出力先は `.agents/skills/verify-ssb/` にし、`.claude/skills/verify-ssb -> ../../.agents/skills/verify-ssb` を張る。
2. 機能地図は 3 件:
   - `boot-title.md`（証明する）
   - `cpu-battle.md`（未証明）
   - `url-battle.md`（未証明）

   未証明の 2 件は、操作の手順を書き、`Gotchas` に「PR-1 では未証明」と書く。手順を弱めて通したことにしない。
3. 使う人に聞くのは、コードから分からないことだけ。今回は無い見込み。
4. 判定のしかたは下の「判定」の節に従う。

### Launch
1. 前提確認: `flutter`（3.44.x）、Chrome（`google-chrome` または `CHROME_EXECUTABLE`）、`python3`、`https://www.gstatic.com/flutter-canvaskit/` に届くか。欠けたら **exit 2**（環境の問題として、製品の失敗と分ける）。
2. ビルド: `flutter build web --profile --base-href "/"`。
   - Firebase の dart-define 4 つにダミーの値を入れる（`FIREBASE_API_KEY=verify-dummy` など）。これで #58 が壊した「設定あり」の分岐を通す。
   - 秘密は使わない。`SENTRY_DSN` は空。
   - profile にする理由: `UxTiming` が debug・profile でだけ `[UxTiming] cold_to_title <ms>ms` を出す（`lib/data/ux_timing.dart`、`lib/presentation/screens/title_screen.dart:68`）。これを「タイトルが 1 フレーム描けた」合図に使う。release ビルドは CI が確かめる。
3. 配信: `build/web` を `127.0.0.1` の空きポート（OS に選ばせる）で配る。`web/_headers` の `/*` の行をそのまま応答ヘッダーに付ける。Python の標準ライブラリだけで書く。
4. 準備完了: サーバーが `/` に 200 を返し、本文に `<title>SPEC BATTLE</title>` がある。

### Drive（`boot-title`）
- headless Chrome を `--headless=new --mute-audio --remote-debugging-pipe` と一時プロファイル、390x844 で起動する。CDP は Python の標準ライブラリだけで話す。
- Firebase の API ホスト 3 つは `--host-resolver-rules` で名前解決させない（`MAP identitytoolkit.googleapis.com ~NOTFOUND` ほか 2 つ）。ダミーのキーが本物の Firebase に届くことはなく、ネットの具合で結果がぶれない。
- CDP で次を拾う:
  - コンソール（`Runtime.consoleAPICalled` `Log.entryAdded`）
  - 捕まらなかった例外（`Runtime.exceptionThrown`）
  - リクエストとその失敗（`Network.requestWillBeSent` `Network.loadingFailed` `Network.responseReceived`）
- 合図を待つ時間は既定 60 秒。`VERIFY_TIMEOUT` で変えられる。
- 合図のあと、セマンティクスを有効にして `SPEC BATTLE` と `TAP TO START` が見えることを確かめる（文言は `test/presentation/title_screen_test.dart:30-31`）。セマンティクスを安定して掴めないときは、その理由を `boot-title.md` の `Gotchas` に書き、合図とスクリーンショットだけで判定する。

### 判定
**PASS**（exit 0）は次のすべてを満たすとき:
- 制限時間内に `[UxTiming] cold_to_title` が出た
- 下の表の「失敗に数える」に当たる行が 0 件

それ以外は **FAIL**（exit 1）。最初に当たった行とその規則名を出す。

| 種類 | 失敗に数える | 無視する（報告には出す） |
|---|---|---|
| CSP | `Content Security Policy` / `Refused to` を含むコンソール行。`securitypolicyviolation` | なし |
| 例外 | `Runtime.exceptionThrown`。`error` レベルで `Uncaught` か `Exception caught by` を含む行 | なし |
| 起動時の Firebase（#58 の種類） | タイトルの合図までに出た次のリクエスト: `identitytoolkit.googleapis.com` `securetoken.googleapis.com` `firestore.googleapis.com` `www.gstatic.com/firebasejs/` `firebase_js_preload.js`（成功・失敗とも） | なし |
| 同じオリジンの読み込み | `127.0.0.1:<port>` への 400 以上、または `loadingFailed` | なし（`web/` に `favicon.ico` があるので、例外にしない） |
| 外部フォント | なし | `fonts.gstatic.com` / `fonts.googleapis.com` の失敗（フォールバックのフォント。ネット次第） |
| それ以外の `error` レベル | **失敗に数える**（既定は拒否） | 無視したいときは、行の形と理由を `SKILL.md` の表に足す。その変更はチェックの変更として扱う |
| `warning` / `info` / `log` / `debug` | なし | すべて（`[UxTiming]`、Flutter エンジンの案内など） |
| Chrome 自身の stderr（GPU、dbus など） | なし | すべて（ページのコンソールではないので見ない） |

「設定ありでも通信を待たずにタイトルまで来る」前提:
- コードで確かめた（`718a7e0`）。
  - 設定があると `ServiceLocator.init` は `FirestoreRankingService` を組むだけ（`lib/domain/services/service_locator.dart:159`）。
  - そのバックエンドはコンストラクタで `.instance` に触らない（`lib/data/firestore_ranking_backend.dart:8-10`、`:21-23`）。
  - `ensureFirebaseInitialized` は起動時に呼ばない約束（`lib/data/firebase_bootstrap.dart:32-33`）。
  - ホームがランキングを呼ぶのは参加 ON のときだけ（`lib/presentation/screens/home_screen.dart:175`）。新しいプロファイルでは OFF。
  - 分析は同意が `granted` でなければ何もしない。送り先は `NoopAnalyticsEventSink` だけ（`lib/data/firebase_analytics_client.dart:32-35`、`:44-53`）。
  - 開いている #89 の Firebase JS 先読みも、`ensureFirebaseInitialized` の中（参加 ON のとき）だけで動く。
- 実行でも確かめる。上の表の「起動時の Firebase」と、下のわざと壊す 1 番がそれに当たる。

### Evidence と Cleanup
- 証拠は `.local/verify-ssb/evidence/<run-id>/` に残す（gitignore 済み）。中身は次の 3 つ。
  - タイトルのスクリーンショット 1 枚
  - 拾ったイベントの JSON
  - 判定の 1 行
- 片付けでは、自分が起こしたサーバーと Chrome だけを止める（PID で止め、名前では止めない）。証拠は消さない。片付けのあとに証拠が残っていることを確かめる。

### Helpers
`.agents/skills/verify-ssb/helpers/` に置き、どれも実行可能にして、呼び方を `SKILL.md` に書く。
- `verify.sh`: `launch` / `doctor` / `drive boot-title` / `cleanup` / `all` の 5 つ。`all` は最後にコミットへ貼れる `Verified:` 行を出す。
- `serve_with_headers.py`
- `cdp_drive.py`

### `Verified:` 行の約束
1 行で書く。値は実際に走らせたものだけを並べる。

```
Verified: analyze test verify-ssb(PASS 3m10s)
Verified: analyze test tlc(未実行: tlc なし)
Verified: none (docs のみ)
```

使える語: `analyze` `test` `verify-ssb` `tlc` `none`。走らせなかったものは書かないか、`(未実行: 理由)` を付ける。

**マージのしかたとの関係:**
- どのコミットでも、メッセージの最後の段落に `Verified:` を書く。
- squash のときは、GitHub が全コミットのメッセージを古い順に並べる（`COMMIT_MESSAGES`）。そのため `Verified:` 行は途中の段落にも残る。それでよい。最後の `Verified:` 行が head のコミットのもの。
- squash のメッセージを人が書き直すときは、head のコミットの `Verified:` 行を、メッセージの最後の段落に残す。
- merge commit のときは、PR のコミットがそのまま `origin/master` に入る。
- 念のため、PR 本文の「テスト」の節にも head の `Verified:` 行を書く。

**数え方:** trailer の解析（`%(trailers)`）は squash で最後の段落に来ないことがあるので使わない。行で数える。

```
git log --no-merges --format='%h%x09%s' origin/master        # 全コミット
git log --no-merges --format='%H%n%B%x00' origin/master      # 本文から ^Verified: の最後の行を取る。無ければ「記録なし」
```

ゲートは作らない（観察も PR-1 ではしない）。

### 変わるファイル
| ファイル | 変更 |
|---|---|
| `.agents/skills/verify-ssb/SKILL.md` | 新規。frontmatter（`name: verify-ssb`）。Launch / Doctor / Drive / Evidence / Cleanup / Helpers、判定の表、確かめないこと、`Verified:` 行 |
| `.agents/skills/verify-ssb/features/README.md` | 新規。地図の目次と前提 |
| `.agents/skills/verify-ssb/features/boot-title.md` | 新規。証明済み |
| `.agents/skills/verify-ssb/features/cpu-battle.md` | 新規。未証明 |
| `.agents/skills/verify-ssb/features/url-battle.md` | 新規。未証明 |
| `.agents/skills/verify-ssb/helpers/verify.sh` | 新規 |
| `.agents/skills/verify-ssb/helpers/serve_with_headers.py` | 新規。標準ライブラリだけ |
| `.agents/skills/verify-ssb/helpers/cdp_drive.py` | 新規。標準ライブラリだけ |
| `.claude/skills/verify-ssb` | 新規の symlink。これが無いとスキルとして見つからない |
| `AGENTS.md` | 「実装・Git の共通基準」に 2 行足す。(1) `lib/**` `web/**` `assets/**` `pubspec.yaml` を変えたら、PR の前に `verify-ssb` を通す。(2) コミットに `Verified:` 行を書く（`none` も書く） |

これ以外のファイルは変えない。`lib/**` `web/**` `.github/**` `pubspec.yaml` に差分が出たら、範囲外として止める。

`verify-ssb` が確かめないこと（`SKILL.md` に書く）:
- タップから先の導線（PR-1 では地図に手順があるだけ）
- ランキング参加時の Firebase のインラインスクリプトのハッシュ（それは `test/data/firebase_csp_headers_test.dart`）
- iPhone Safari
- release ビルドに特有の差

### PR-1 の完了条件
- [ ] `flutter analyze` エラー 0、`flutter test` 全件成功（既存のまま）
- [ ] pstack の証明: `verify.sh all` を通しで 1 回。片付けのあとに証拠が残っている
- [ ] 安定性: `verify.sh all` を PR の head で **5 回続けて**走らせ、5 回とも PASS。所要時間を PR に書く
- [ ] わざと壊すと落ちる（下の 4 つ）。作業ツリーだけで試し、コミットしない
- [ ] 前提が欠けると exit 2（例: `PATH` から flutter を外す）
- [ ] CI の `check` と `agent-hooks` が緑
- [ ] `git diff --stat origin/master...HEAD` が上の表のファイルだけ
- [ ] PR-1 のコミットと PR 本文に `Verified:` 行がある

## 検証（verify と CI がどう証明するか）

### PR-1: `verify-ssb` 自身が正しく落ちること
| わざと壊す（コミットしない） | 期待 |
|---|---|
| `ServiceLocator.init` の最後で `ensureFirebaseInitialized()` を呼ぶ（#58 の再現） | FAIL: 起動時の Firebase（`www.gstatic.com/firebasejs/` か API ホストへのリクエスト） |
| `ServiceLocator().init()` の後で `await Completer<void>().future` を入れ、`runApp` に届かなくする（黒画面） | FAIL: 制限時間内に `cold_to_title` が出ない |
| `web/_headers` の `script-src` から `https://www.gstatic.com/flutter-canvaskit/` を消してビルドし直す | FAIL: CSP |
| `TitleScreen.initState` の先頭で `throw StateError('verify')` | FAIL: 例外、またはタイムアウト |

1 回でも理由の分からない FAIL が出たら、原因を直す。再実行で通さない。1 回の所要時間の目安は 5 分以内。超えたら測った値を PR に書く。ゲートにはしない。

### PR-2: 通貨のプロパティテスト
区分 **低**（`test/**` だけ）。新規ファイルは `test/domain/currency_property_test.dart` と `test/domain/support/fault_injecting_storage.dart`。偽ストレージは `_ThrowAfterCacheStorage`（`test/domain/currency_test.dart:349`）の形にそろえる。キャッシュを先に書き、そのあと `await` で投げることがある。

**入力**（シード 0〜199。シードごとに `Random(seed)` で決める）:
- 開始残高: コイン・ジェムとも 0〜50
- 操作: 3〜8 個。種類は下の表の 6 つ。量はどれも 0〜30 の整数。`exchangeCoinsForGems` の `coins` と `gems` は別々に引く
- 失敗の注入: 操作ごとに 2 割で「その操作の最初の書き込みで投げる」。コインとジェムのどちらで投げるかも引く。失敗のあとの戻し（`_restoreSnapshot`）の書き込みは投げない（1 操作に失敗は 1 回まで）
- 書き込みごとに `Future.delayed(Duration.zero)` を 0〜3 回挟む

**走らせ方:** 全操作を一度に呼び、`Future.wait` で待つ。1 つずつの結果（成功・`null`・例外）を取る。`SerialExecutor.run` は最初の `await` の前に `_chain` を付け替える（`lib/domain/services/serial_executor.dart`）。そのため、実際に処理される順は呼んだ順になる。

**参照モデル**（期待値はこれだけで作る。本体のコードを写さない）: 呼んだ順に 1 つずつ、次の表で残高 `(c, g)` を進める。「失敗注入あり」は、偽ストレージがその操作で投げると決めたもの。

| 操作 | 条件 | 期待する結果 | 残高の変化 |
|---|---|---|---|
| `addCoins(n)` | 失敗注入なし | 成功（`n = 0` でも保存する） | `c += n` |
| `addCoins(n)` | 失敗注入あり | 例外 | なし |
| `spendCoins(n)` | `c < n` | `null`（保存しない。注入は起きない） | なし |
| `spendCoins(n)` | `c >= n`、失敗注入なし | 成功（`n = 0` は成功で変化 0） | `c -= n` |
| `spendCoins(n)` | `c >= n`、失敗注入あり | 例外 | なし |
| `addGems(n)` / `spendGems(n)` | コインと同じ規則をジェムに | 同上 | `g` を同様に |
| `addReward(coins: a, gems: b)` | `a = 0` かつ `b = 0` | 成功（保存しない。注入は起きない） | なし |
| `addReward(coins: a, gems: b)` | それ以外、失敗注入なし | 成功 | `c += a`、`g += b` |
| `addReward(coins: a, gems: b)` | それ以外、失敗注入あり | 例外 | なし（両方とも） |
| `exchangeCoinsForGems(coins: x, gems: y)` | `c < x` | `null`（保存しない） | なし |
| `exchangeCoinsForGems(coins: x, gems: y)` | `c >= x`、失敗注入なし | 成功。レートは無い。呼び手が `x` と `y` を両方決めるので、あまりも無い | `c -= x`、`g += y` |
| `exchangeCoinsForGems(coins: x, gems: y)` | `c >= x`、失敗注入あり | 例外 | なし（両方とも） |

「保存しない」行では、偽ストレージは書き込みを受けないので、注入は起きない。参照モデルは、注入が実際に起きた操作の数も数える。

**成り立つべきこと:**
1. 操作ごとの結果の種類（成功・`null`・例外）が、参照モデルと一致する。
2. 成功した操作が返した残高が、参照モデルのその時点の残高と一致する。
3. 最後の `load()` が、参照モデルの最後の残高と一致する。
4. 偽ストレージが実際に投げた回数が、参照モデルの「失敗注入あり」で保存する行の数と一致する。
5. 残高は、途中も最後も負にならない。

落ちたら、シードと操作列と、最初に食い違った操作の番号をメッセージに出す。壁時計は使わない。全体で 2 秒以内。

| わざと壊す（コミットしない） | 期待 |
|---|---|
| `spendGems` から `_serial.run` を外す | 1 か 3 で落ちる（TLA+ の `NoLostUpdate` と同じ種類） |
| `_restoreSnapshot` の中身を空にする | 3 で落ちる（`FailedOpHasNoEffect` と同じ種類） |
| `spendCoins` の残高確認を外す | `PlayerCurrency.spendCoins` が投げるので、1 で落ちる（`null` のはずが例外になる） |
| `addReward` の `a = 0 かつ b = 0` の早期 return を外す | 4 で落ちる（保存しないはずの行で注入が起きる） |

高のコードは読むだけで変えない。`currency-ledger-verify` の代わりではない。通貨のコードを変える PR では、`REVIEW.md` のとおり `run.sh` の結果が引き続き要る。

### PR-3: SSB 固有の文書（区分 **中**）
- `REVIEW.md` の「往復のルール」に 1 行足す。SSB でチェックに当たるファイルは「今やる」の表の下の一覧。PR がそれらを変えるときは、変更前の版で判断する。マージの扱いは「決まったこと」のとおり（指示ファイルはイフリト、テストだけなら自動）。
- `REVIEW.md` の「通貨・報酬」に 1 行足す。同じ PR が通貨のコードと `currency-ledger-verify` のモデルか `run.sh` の両方を変えたら、base の `run.sh` を PR の head のコードで回した結果も求める。
- 共通ルール（life）が決まったら、そこを指す 1 行だけにする。ここの文は写さない。
- 証明: 文書だけなので、リンク先とパスが存在すること、`REVIEW.md` の既存の規則（3 往復・差分だけ・区分）と矛盾しないことを差分で確かめる。

## 今回（PR-1）やらないこと
- 未証明の機能（CPU バトル・URL 対戦）を実際に操作すること
- CI・ワークフロー・Dependabot・CODEOWNERS の変更
- `.cursor/hooks.json` へのゲートの追加（観察も enforce も）
- `pubspec.yaml` の変更、新しい依存
- `currency-ledger-verify` の変更・移動、TLC の取得、pstack の formal 系スキルを回すこと
- PR-2・PR-3 の中身（別の PR）
- Playwright の厳密な見た目ゲート（頼まれたときだけ。`AGENTS.md` のまま）
- 共通ルール（life）の文の取り込み
- 旧運用の文書（`docs/agent/` `docs/plans/TEMPLATES.md`）の整理

## 決まったこと（イフリト 2026-11-17）
- **自動マージの範囲**（9:14 承認「AI指示ファイルのみね」）:
  - AI への指示ファイルを変える PR は自動マージから外し、イフリトがマージする。指示ファイルは `AGENTS.md` `REVIEW.md` `CLAUDE.md` `CONTEXT.md` と、`.agents/**` `.claude/**` の `.md` など。
  - ふつうの docs とテストだけの PR は、これまでどおり自動マージする。
  - 内側ループ規則への反映は司令役がする。
- 当てはめ:

  | PR | マージ | 理由 |
  |---|---|---|
  | #90（本書） | イフリト | 9:09 に、docs だけでも人がマージすると決めた。指示ファイルの規則にも当たる |
  | PR-1 | イフリト | `AGENTS.md` `.agents/**` `.claude/**` |
  | PR-2 | 自動マージ | テストだけ。チェックに当たるファイルだが、指示ファイルではない |
  | PR-3 | イフリト | `REVIEW.md` |

- 参謀に頼むこと（判断ではなく作業）: `/workspace/ssb-formal-verify/` とリポの `.claude/skills/currency-ledger-verify/` を `diff -r` で比べる。違いがあれば、「参謀の箱の TLA+ とのつなぎ」の節の手順で扱う。

## Generator ログ
（実装スレッドが区切りごとに 1 行足す: 済んだこと・次の一手・判断待ち）

- 2026-11-19: PR-3 着手。REVIEW.md にチェック対象・base の run.sh・フレーク理由の行き先を足す。判断待ちなし。
- 2026-11-19: PR-3 文書のリンク先（life `dev/rules/`）と既存パスを確認。verify-ssb と通貨プロパティテストは PR-1/PR-2 待ち。次は PR。マージはイフリト。

---
## 評価
（検証スレッドが結果を足す）
