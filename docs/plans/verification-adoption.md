# Plan: 検証のしくみを SSB に取り入れる
Created: 2026-11-17
Status: PLANNING

## 要件
Claude Code チームの検証の記事（出典）を SSB に取り入れる。何を今やり、何をあとにし、何をやらないかを決める。最初の一切れは PR 1 本に収める。

出典:
- https://claude.dev/blog/how-the-claude-code-team-thinks-about-verification/ （2026-11-16、Addy Osmani）
- https://x.com/ClaudeDevs/status/2122457608963395586 （この環境からは 403 で読めない。記事の告知と見て、中身は記事で判断した）

## いまの SSB（判断の前提）
- CI（`.github/workflows/ci.yml`）: `flutter analyze` / `flutter test` / UX perf の記録（閾値なし＝測るだけ）/ `flutter build web --release`。動くアプリは誰も起動していない。
- 本番で起きた事故は、どちらも「起動して初めて分かる」種類だった。黒画面（#58）と CSP によるランキング参加失敗（#82）。単体テストは緑のままだった。
- 通貨は TLA+ モデルで守っている。モデル本体はこのリポにある（`.claude/skills/currency-ledger-verify/` の `CurrencyService.tla` `run.sh` ほか）。参謀の箱の `/workspace/ssb-formal-verify/` は別コピー。実装席の Cloud Agent には `tlc` が無いので、#77 では本検査をレビュー担当に回した。
- 実装席（Cloud Agent `grok-4.6`）には Flutter 3.44.0 と headless Chrome がある（#82・#89 の PR 本文）。この設計スレッドの VM には Flutter が無い。
- このチェックアウトのスキルは `.claude/skills/*` から見つかる。`midway-check` は `.claude/skills/midway-check -> ../../.agents/skills/midway-check` の symlink 経由で見えている。
- 前回の verify スキル（[#33](https://github.com/ifrit99/SmartPhoneSpecBattle/pull/33)、`cursor/verify-ssb-skill-0d2d`）は 1,018 行で、Mac の Cursor ブラウザ前提だった。Cloud では動かず、下書きのまま閉じた。今回は小さく、Cloud で動くものにする。
- `REVIEW.md` にはすでに次がある。区分（高・中・低）、3往復で止める、2回目以降は差分だけ、札（重大・軽微・前からある）、同じ指摘が2回出たら1行足す。

## 判断

### 今やる
| 項目 | どう入れるか | 理由 |
|---|---|---|
| `verify` スキル（起動確認） | PR-1。Web をビルドし、本番と同じ CSP で配信し、headless Chrome でタイトル画面まで出ることを確かめる | 事故 2 件（#58・#82）は起動して初めて分かる種類だった。記事も「変更を動かすことが検証」としている |
| コミットに検証方法を残す（`none` も） | PR-1。コミット末尾に `Verified:` 行を書く約束にする。ゲートは作らない | 費用ゼロ。あとで「検証なしのコミット」を数えられる。将来のゲートを観察モードで始めるための材料になる |
| 通貨のプロパティテスト | PR-2。Dart のテストだけで書く。シード固定の乱数で操作列を作り、失敗を注入し、並行に走らせる | TLC が Cloud に無いので、本物のコードを毎回テストで叩く層が要る。依存は増やさない |
| `REVIEW.md` はベースブランチから読む | 司令役が検証スレッドの手順をすぐ変える（PR 不要）。文面は PR-3 で `REVIEW.md` に足す | 変更が自分を裁く基準を書き換えられると、基準が効かない |
| 古いコミットへのレビューは無効 | PR-3。レビューに見た head の SHA を書き、マージは head がその SHA のときだけ | レビュー中に push されたら結果は意味を持たない |
| 3回直して落ちたら止める（実装側） | PR-3。`AGENTS.md` に 1 行 | `REVIEW.md` の 3 往復はレビュー側の規則。実装席が同じテストに何度も挑む側の規則がまだない |
| フレーキーなテスト | PR-3。再実行・sleep・skip で通さない。原因を直すか、理由を書いて消す | 記事どおり。フレークを許すと「再実行すればよい」と学ぶ |
| 新しいゲートは観察モードから | 原則として本書に置く。最初の適用先は「あとで」の stamp 観察 | 前例がある（UX perf の閾値なし＝測るだけ）。誤検知を見てから止める |

### あとで
| 項目 | いつ・どう | 今やらない理由 |
|---|---|---|
| verify で主要導線を歩く（タイトル→ホーム→バトル→リザルト、ガチャ、URL 対戦） | PR-1 が安定したあと。第1候補は `flutter test --platform chrome` で本物のアプリを pump して歩くテスト。pubspec は変えない | Flutter Web は canvas 描画で、CLI の Chrome からはタップできない。CDP か `integration_test` が要る。後者は pubspec の変更（高）になる |
| `Verified:` の観察ゲート | PR-1 の約束が 10 PR ほど回ったあと。CI で `Verified:` が無いコミットをログに出すだけにする（落とさない） | CI は区分「高」。まず人が書く約束を回して、形を固める |
| CI で verify を回す | 観察ゲートのあと | ビルドが 2 回になり CI が遅くなる。PR-1 で所要時間を測ってから決める |
| 共有 URL・バックアップのラウンドトリップ（プロパティ） | PR-2 のあと。`CharacterCodec` と、バックアップコードの encode→decode | 既存の例ベースのテストが厚い（`test/domain/character_codec_test.dart` 475 行）。通貨より後 |
| Cloud で TLC を回す | 版を固定した `tla2tools.jar` をハッシュ確認つきで取る形を `run.sh` に足す。別 PR | スキルの変更（中）。PR-2 で Cloud の穴をまず埋める |
| `currency-ledger-verify` を `.agents/skills/` へ移す | 正本の場所を `AGENTS.md` に合わせる。互換は symlink | 動いているものを今回の範囲で動かさない |
| 規則を定期的に減らす | 月 1 回、設計スレッドが `REVIEW.md` `docs/coding_rules.md` とスキルの削れる行を 1 PR にまとめて出す | まず足す側が回ってから |
| 差分テスト（古い実装を正解にする） | `CharacterCodec` の版上げやバックアップ形式の変更があったとき | 今は移行の予定がない |

### やらない
| 項目 | 理由 |
|---|---|
| レビュー担当を増やす | 記事も重ねるより主担当を調整するとしている。Dual Review は高リスクかユーザー依頼のときだけ（`AGENTS.md`）のまま |
| レビュー担当の評価セット（過去事故の再現・再現率の計測） | SSB の規模では採点データが足りない。代わりに各チェックに「わざと壊すと落ちる」証明を付ける（下の検証） |
| コミットを止めるゲートの enforce（session に verify が無ければ拒否など） | 観察で誤検知を見る前に止めない。Cursor hook はタイムアウト 10 秒で、テストを回す用途に合わない |
| 新しい依存（`glados` などのプロパティテスト用パッケージ、`integration_test`、npm） | 区分「高」になる。シード固定の `Random` で足りる |
| Mac の Cursor ブラウザ前提の verify（#33 の形） | Cloud の実装席で動かない |

理由の補足:
- 記事の「コードの持ち主が自分のチェックを書く」は、SSB では `REVIEW.md` の「壊れた姿」がすでに担っている。あれは事故の PR 番号を付けた、diff から引けるトリガーの一覧になっている。足すのは事故のときだけ（今の約束のまま）。
- 「安いチェックを先に」は `AGENTS.md` の `flutter analyze` / `flutter test` 必須ですでに入っている。PR-1 は「起動」を同じ並びに足すだけにする。

## 最初の一切れ（PR-1）: `verify` スキル（起動確認）と `Verified:` 行

区分: **中**（`AGENTS.md` `.agents/**` `.claude/**`）。製品コード・CI・pubspec は触らない。見た目は変えないので途中確認は不要。

### 何をするか
`bash .agents/skills/verify/run.sh` 1 本で次を順にやり、最後に 1 行の判定を出す。

1. 前提確認: `flutter`（3.44.x）、Chrome（`google-chrome` または `CHROME_EXECUTABLE`）、`python3`、`https://www.gstatic.com/flutter-canvaskit/` に届くか。どれかが欠けたら **exit 2**（環境の問題。製品の失敗と分ける）。
2. ビルド: `flutter build web --profile --base-href "/"`。Firebase の dart-define には**ダミーの値**を入れる（`FIREBASE_API_KEY=verify-dummy` など 4 つ）。これで #58 が壊した「設定がある」分岐を通す。秘密は使わない。`SENTRY_DSN` は空。
   - profile にする理由: `UxTiming` は debug・profile でだけ `[UxTiming] cold_to_title <ms>ms` を出す（`lib/data/ux_timing.dart`、`lib/presentation/screens/title_screen.dart:68`）。これを「タイトルが 1 フレーム描けた」合図に使う。本番の release ビルドは CI がそのまま確かめる。
3. 配信: `build/web` を `127.0.0.1` の空きポート（OS に選ばせる）で配る。`web/_headers` の `/*` の行（`Content-Security-Policy` ほか）をそのまま応答ヘッダーに付ける。Python の標準ライブラリだけで書く。
4. 起動: headless Chrome（`--headless=new --mute-audio`、一時プロファイル、390x844）で開く。コンソールを読む。
   - 第1候補は Chrome の CLI フラグ（`--enable-logging=stderr` など）でコンソールを拾う形。
   - 拾えないときは `--remote-debugging-pipe` と Python 標準ライブラリで CDP を話す形にする。npm と pub の依存は足さない。
5. 判定:
   - **PASS**: 制限時間内（既定 60 秒、`VERIFY_TIMEOUT` で変更可）に `[UxTiming] cold_to_title` が出る。かつ CSP 違反（`Refused to ...` / `Content Security Policy`）と、捕まらなかった例外がコンソールに 0 件。
   - **FAIL**（exit 1）: そうでないとき。最初の違反行かタイムアウトを示す。
6. 証拠: タイトルのスクリーンショットを 1 枚 `/tmp/` に保存してパスを出す（判定には使わない。見た目の PR で人に見せる用）。
7. 片付け: サーバーと Chrome を `trap` で必ず止める。リポの中に成果物を残さない（`build/` は既に gitignore 済み）。
8. 最後の行に、コミットにそのまま貼れる `Verified:` 行を出す（下の約束）。

`SKILL.md` は 60 行以内にする。書くことは 4 つ。いつ使うか（`lib/**` `web/**` `assets/**` `pubspec.yaml` を変えたら、PR を出す前と、レビュー指摘を直して push する前）、実行コマンド、出力と exit の表、**確かめていないこと**（下の表）。

| verify が確かめる | verify が確かめない |
|---|---|
| ビルドが通り、本番と同じ CSP でタイトルが 1 フレーム描ける。「設定あり」の分岐でも起動で固まらない | タップしてからの導線（ホーム・バトル・ガチャ・ランキング参加）。ランキング参加時の Firebase のインラインスクリプトのハッシュ（それは `test/data/firebase_csp_headers_test.dart`）。iPhone Safari。release ビルドに特有の差 |

### `Verified:` 行の約束
コミットメッセージの最後に、空行を挟んで 1 行書く。値は実際に走らせたものだけを並べる。

```
Verified: analyze test verify(PASS 3m10s)
Verified: analyze test tlc(未実行: tlc なし)
Verified: none (docs のみ)
```

使える語: `analyze` `test` `verify` `tlc` `none`。走らせなかった・走らなかったものは書かないか、`(未実行: 理由)` を付ける。数えるときは次を使う。`git log --format='%h %(trailers:key=Verified,valueonly)' origin/master`。ゲートはまだ作らない（観察も PR-1 ではしない）。

### 変わるファイル
| ファイル | 変更 |
|---|---|
| `.agents/skills/verify/SKILL.md` | 新規。上の 4 つだけ |
| `.agents/skills/verify/run.sh` | 新規。上の 1〜8 |
| `.agents/skills/verify/serve_with_headers.py` | 新規。`web/_headers` の `/*` 部分を付けて `build/web` を配る。標準ライブラリだけ |
| `.agents/skills/verify/chrome_console.py` | CDP の形にしたときだけ新規。標準ライブラリだけ |
| `.claude/skills/verify` | 新規 symlink（`../../.agents/skills/verify`）。これが無いとスキルとして見つからない |
| `AGENTS.md` | 「実装・Git の共通基準」に 2 行足す。(1) `lib/**` `web/**` `assets/**` `pubspec.yaml` を変えたら、PR の前に verify を通す。(2) コミットに `Verified:` 行を書く（`none` も書く） |

これ以外のファイルは変えない。`lib/**` `web/**` `.github/**` `pubspec.yaml` に差分が出たら、範囲外として止める。

### PR-1 の完了条件
- [ ] `flutter analyze` エラー 0、`flutter test` 全件成功（既存のまま）
- [ ] PR の head で `run.sh` を **5 回続けて**走らせ、5 回とも PASS。各回の所要時間を PR に書く
- [ ] わざと壊すと落ちる（下の 3 つ）。どれも作業ツリーだけで試し、コミットしない。結果を PR に書く
- [ ] 前提が欠けると exit 2（例: `PATH` から flutter を外して実行）
- [ ] CI の `check` と `agent-hooks` が緑
- [ ] `git diff --stat origin/master...HEAD` が上の表のファイルだけ
- [ ] PR-1 のコミットに `Verified:` 行がある

## 検証（verify と CI がどう証明するか）

### PR-1: verify 自身が正しく落ちること
| わざと壊す（コミットしない） | 期待 |
|---|---|
| `ServiceLocator().init()` の後で `await Completer<void>().future` を入れ、`runApp` に届かなくする（黒画面の再現） | FAIL: 制限時間内に `cold_to_title` が出ない |
| `web/_headers` の `script-src` から `https://www.gstatic.com/flutter-canvaskit/` を消してビルドし直す | FAIL: CSP 違反の行を示す |
| `TitleScreen.initState` で `throw StateError('verify')` | FAIL: 捕まらなかった例外、またはタイムアウト |

安定性: 5 回連続 PASS。1 回でも落ちたら原因を直す。再実行で通さない。1 回の所要時間は目安 5 分以内。超えたら測った値を PR に書く。ゲートにはしない。

### PR-2: プロパティテストが正しく落ちること
仕様:
- 新規ファイルは `test/domain/currency_property_test.dart` と `test/domain/support/fault_injecting_storage.dart`。
- 偽ストレージは既存の `_ThrowAfterCacheStorage`（`test/domain/currency_test.dart:349`）の形にそろえる。キャッシュを先に書き、そのあと `await` で投げることがある。
- シードは 0〜199。シードごとに次を乱数で決める。
  - 開始残高（コイン・ジェムとも 0〜50）
  - 3〜8 個の操作（`addCoins` `spendCoins` `addGems` `spendGems` `addReward` `exchangeCoinsForGems`、量は 0〜30）
  - 書き込みごとの失敗（2 割）と、`Future.delayed(Duration.zero)` を挟む回数（0〜3）
- 操作は `Future.wait` で同時に走らせ、1 つずつの結果（成功・不足で `null`・例外）を取る。
- 成り立つべきこと:
  - 最後の残高は、開始残高に成功した操作の増減だけを足したもの
  - 返ってきた残高も、最後の残高も負にならない
  - 例外の操作と `null` の操作は残高に何も足さない
- 落ちたらシードと操作列をメッセージに出す。壁時計は使わない。全体で 2 秒以内。

| わざと壊す（コミットしない） | 期待 |
|---|---|
| `spendGems` から `_serial.run` を外す | 残高の不一致で落ちる（TLA+ の `NoLostUpdate` と同じ種類） |
| `_restoreSnapshot` の中身を空にする | 例外の操作が残高に残って落ちる（`FailedOpHasNoEffect` と同じ種類） |
| `spendCoins` の残高確認を外す | 負の残高で落ちる（`NoOverspend` と同じ種類） |

区分は **低**（`test/**` だけ）。高のコードを読むだけで変えない。`currency-ledger-verify` の代わりではない。通貨のコードを変える PR では、`REVIEW.md` のとおり `run.sh` の結果が引き続き要る。

### PR-3: 文書の約束（区分 **中**）
- `REVIEW.md`
  - 「往復のルール」に次を足す。基準は PR の base（`git show origin/master:REVIEW.md`）から読む。PR が `REVIEW.md` やスキルのチェックを変えるときは、変更前の基準で判断し、基準の変更そのものは人のマージに回す。
  - 「往復のルール」に次を足す。レビューには見た head の SHA を書く。head が動いたら、その SHA からの差分を見直すまでマージしない。
  - 「通貨・報酬」に次を足す。同じ PR が通貨のコードと `currency-ledger-verify` のモデル・`run.sh` の両方を変えたら、base の `run.sh` を PR の head のコードで走らせた結果も求める。
- `docs/coding_rules.md` の「学習パターン」に 1 行足す。フレーキーなテストは再実行・sleep・skip で通さない。原因を直すか、消してその理由をコミットと `docs/test-notes/known-risks.md` に書く。
- `AGENTS.md` に 1 行足す。同じチェックが 3 回の修正でも落ちるなら止める。落ちた出力をそのまま報告し、チェックを弱めない。
- 証明: 文書だけなので、リンク先とパスが存在すること、`REVIEW.md` の既存の規則と矛盾しないこと（3 往復・差分だけ・区分）を差分で確かめる。

## 今回（PR-1）やらないこと
- 主要導線をタップで歩くこと（あとで。上の「あとで」）
- CI・ワークフロー・Dependabot・CODEOWNERS の変更
- `.cursor/hooks.json` へのゲートの追加（観察も enforce も）
- `pubspec.yaml` の変更、新しい依存
- `currency-ledger-verify` の変更・移動、TLC の取得
- PR-2・PR-3 の中身（別の PR）
- Playwright の厳密な見た目ゲート（頼まれたときだけ。`AGENTS.md` のまま）
- 旧運用の文書（`docs/agent/` `docs/plans/TEMPLATES.md`）の整理

## 司令役とイフリトさんに要る判断
1. **自動マージの範囲**（司令役の内側ループ規則）。いまは `*.md` が自動マージの対象に入っている。そのため `AGENTS.md` `REVIEW.md` `CLAUDE.md` `CONTEXT.md` と `.agents/**` `.claude/**` の `.md` も、検証と CI が通れば自動で入る。`REVIEW.md` ではこれらは「中」（1 件ずつ人がマージ）。案は 2 つ。
   - **（おすすめ）** エージェントへの指示ファイルを自動マージから外す。変更が自分を裁く基準を書き換えて、そのまま入る道を塞ぐため。
   - 今のまま。
   PR-1 と PR-3 はどちらもこの指示ファイルに当たる。
2. **検証スレッドの手順**（司令役、PR 不要）。読むのは設計書・PR 差分・`git show origin/master:REVIEW.md`。報告の先頭に、見た head の SHA を書く。
3. 「あとで」の順番は本書のとおりでよいか。変えるなら、PR-1 の所要時間を見てから決める。

## Generator ログ
（実装スレッドが区切りごとに 1 行足す: 済んだこと・次の一手・判断待ち）

---
## 評価
（検証スレッドが結果を足す）
