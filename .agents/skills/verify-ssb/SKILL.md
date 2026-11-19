---
name: verify-ssb
description: Launch SPEC BATTLE Flutter web (profile, dummy Firebase), drive the title screen the way a user would via Chrome CDP, and keep evidence. Use before a PR that changes lib/**, web/**, assets/**, or pubspec.yaml, or when asked to run verify-ssb.
---

# verify-ssb

SPEC BATTLE の Flutter Web を実装席で起動し、ユーザーと同じ道でタイトルまで来たことを証拠付きで確かめる。正本はこのディレクトリ。Claude Code からは `.claude/skills/verify-ssb` の symlink で見える。

PR-1 で証明するのは `boot-title` だけ。地図の CPU バトルと URL 対戦は手順があるが未証明。手順を弱めて通したことにしない。

## Launch

前提（欠けたら **exit 2**。製品の FAIL と分ける）:

- `flutter` が 3.44.x
- Chrome（`google-chrome` または `CHROME_EXECUTABLE`）
- `python3`
- `https://www.gstatic.com/flutter-canvaskit/` に届く（HTTP 404 でもホストが答えれば可）

ビルド（リポルート）:

```bash
flutter build web --profile --base-href "/" \
  --dart-define=FIREBASE_API_KEY=verify-dummy \
  --dart-define=FIREBASE_APP_ID=verify-dummy \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=verify-dummy \
  --dart-define=FIREBASE_PROJECT_ID=verify-dummy
```

- Firebase の dart-define 4 つはダミー（`verify-dummy`）。#58 が壊した「設定あり」の分岐を通す。
- 秘密は使わない。`SENTRY_DSN` は渡さない（空のまま）。
- profile にする理由: `UxTiming` が debug / profile だけで `[UxTiming] cold_to_title <ms>ms` を出す（`lib/data/ux_timing.dart`、`lib/presentation/screens/title_screen.dart`）。これが「タイトルが 1 フレーム描けた」合図。release は CI が見る。

配信:

- `build/web` を `127.0.0.1` の空きポート（OS に選ばせる）で配る。
- `web/_headers` の `/*` 行を応答ヘッダーに付ける。Python 標準ライブラリだけ。
- Cloud 実装席の Chrome は `--no-sandbox --disable-dev-shm-usage --disable-gpu` が要ることがある。ページの判定には使わない。

準備完了: `GET /` が 200 で、本文に `<title>SPEC BATTLE</title>` がある。

起動は次で一括する:

```bash
bash .agents/skills/verify-ssb/helpers/verify.sh launch
```

状態は `.local/verify-ssb/state.json`（gitignore 済み）。二重起動しない。残っていれば cleanup してから立て直す。

## Doctor

読み取り専用。このインスタンスを操作してよいかだけを答える。

```bash
bash .agents/skills/verify-ssb/helpers/verify.sh doctor
```

PASS の条件:

- 前提が揃っている（欠けたら exit 2）
- `state.json` の server PID が生きて、cmdline が `serve_with_headers.py` である
- そのポートへ TCP できる
- `GET /` が 200 で `<title>SPEC BATTLE</title>` がある

それ以外は doctor FAIL（exit 1）。他人のサーバーや残骸を操作しない。

## Drive

ハーネスは headless Chrome の CDP。座標は使わない。Flutter Web は canvas なので、セマンティクス（aria ラベル）を CDP で掴む。

Chrome の必須フラグ:

- `--headless=new --mute-audio --remote-debugging-pipe`
- 一時プロファイル、390x844
- `--host-resolver-rules=MAP identitytoolkit.googleapis.com ~NOTFOUND,MAP securetoken.googleapis.com ~NOTFOUND,MAP firestore.googleapis.com ~NOTFOUND`

ダミーキーが本物の Firebase に届かない。ネットの具合で結果がぶれない。

CDP で拾う:

- コンソール（`Runtime.consoleAPICalled` `Log.entryAdded`）
- 捕まらなかった例外（`Runtime.exceptionThrown`）
- リクエストとその失敗（`Network.requestWillBeSent` `Network.loadingFailed` `Network.responseReceived`）

合図を待つ時間は既定 60 秒。`VERIFY_TIMEOUT` で変えられる。

PR-1 で回す機能は `boot-title` だけ:

```bash
bash .agents/skills/verify-ssb/helpers/verify.sh drive boot-title
```

手順と観測は `features/boot-title.md`。地図の他ファイルは未証明で、`drive cpu-battle` などは FAIL にする。

合図のあとセマンティクスを有効にし、`SPEC BATTLE` と `TAP TO START` を探す（文言は `test/presentation/title_screen_test.dart`）。掴めないときは製品の FAIL にせず、合図と `title.png` で判定し、`judgment.txt` に注意を書く。`title.png` が無い・空なら FAIL。理由は `features/boot-title.md` の Gotchas。

## 判定

**PASS**（exit 0）は次のすべてを満たすとき:

- 制限時間内に `[UxTiming] cold_to_title` が出た
- 下の表の「失敗に数える」に当たる行が 0 件
- `title.png` がある（無い・空・PNG でないは FAIL。スクリーンショット取得の失敗を黙って飛ばさない）

セマンティクスでラベルを掴めなければ FAIL にはしない。`judgment.txt` に `semantics missed:` または `semantics not confirmed` を残す。

それ以外は **FAIL**（exit 1）。最初に当たった行とその規則名を出す。

| 種類 | 失敗に数える | 無視する（報告には出す） |
|---|---|---|
| CSP | `Content Security Policy` / `Refused to` を含むコンソール行。`securitypolicyviolation` | なし |
| 例外 | `Runtime.exceptionThrown`。`error` レベルで `Uncaught` か `Exception caught by` を含む行 | なし |
| 起動時の Firebase（#58 の種類） | タイトルの合図までに出た次のリクエスト: `identitytoolkit.googleapis.com` `securetoken.googleapis.com` `firestore.googleapis.com` `www.gstatic.com/firebasejs/` `firebase_js_preload.js`（成功・失敗とも） | なし |
| 同じオリジンの読み込み | `127.0.0.1:<port>` への 400 以上、または `loadingFailed` | なし（`web/` に `favicon.ico` があるので、例外にしない） |
| 外部フォント | なし | `fonts.gstatic.com` / `fonts.googleapis.com` の失敗（フォールバックのフォント。ネット次第） |
| それ以外の `error` レベル | **失敗に数える**（既定は拒否） | 無視したいときは、行の形と理由をこの表に足す。その変更はチェックの変更として扱う |
| `warning` / `info` / `log` / `debug` | なし | すべて（`[UxTiming]`、Flutter エンジンの案内など） |
| Chrome 自身の stderr（GPU、dbus など） | なし | すべて（ページのコンソールではないので見ない） |

「設定ありでも通信を待たずにタイトルまで来る」ことは、起動時の Firebase 行と、わざと壊す 1 番で実行でも確かめる。

## Evidence

証拠は `.local/verify-ssb/evidence/<run-id>/`（gitignore 済み）。消さない。

- `title.png` — タイトルのスクリーンショット 1 枚
- `events.json` — 拾ったイベントと判定材料
- `judgment.txt` — 判定の 1 行（`PASS` または `FAIL: <規則名> (<最初の行>)`。セマンティクスを掴めなければ `PASS; semantics missed: ...`）

## Cleanup

自分が起こしたサーバーと Chrome だけを止める。PID が生きていても、cmdline に `serve_with_headers.py`（サーバー）または `verify-ssb-chrome`（Chrome の一時プロファイル）が無ければ止めない。名前では止めない。証拠は消さない。片付けのあとに証拠が残っていることを確かめる。

```bash
bash .agents/skills/verify-ssb/helpers/verify.sh cleanup
```

失敗した試行のあとも cleanup する。ポートと Chrome を残さない。

## Helpers

どれも実行可能。リポルートから呼ぶ。

```bash
bash .agents/skills/verify-ssb/helpers/verify.sh launch
bash .agents/skills/verify-ssb/helpers/verify.sh doctor
bash .agents/skills/verify-ssb/helpers/verify.sh drive boot-title
bash .agents/skills/verify-ssb/helpers/verify.sh cleanup
bash .agents/skills/verify-ssb/helpers/verify.sh all
```

`all` は launch → doctor → drive boot-title → cleanup。片付けのあと証拠が残っていることを確かめ、最後にコミットへ貼れる `Verified:` 行を出す。

個別にサーバーや CDP だけを試すとき:

```bash
python3 .agents/skills/verify-ssb/helpers/serve_with_headers.py \
  --root build/web --headers web/_headers --bind 127.0.0.1 --port 0
python3 .agents/skills/verify-ssb/helpers/cdp_drive.py \
  --url http://127.0.0.1:<port>/ \
  --evidence .local/verify-ssb/evidence/<run-id> \
  --timeout 60
```

判定の規則だけを回す:

```bash
python3 .agents/skills/verify-ssb/helpers/test_rules.py
```

標準ライブラリだけ。新しい依存は足さない。

## Verified: 行

値は実際に走らせたものだけを並べる。使える語: `analyze` `test` `verify-ssb` `tlc` `none`。走らせなかったものは書かないか、`(未実行: 理由)` を付ける。

```
Verified: analyze test verify-ssb(PASS 3m10s)
Verified: analyze test tlc(未実行: tlc なし)
Verified: none (docs のみ)
```

どのコミットでも、メッセージの最後の段落に書く。ゲートにはしない。`all` が出すのは `Verified: verify-ssb(PASS <所要>)` の部分。analyze / test を走らせた側が足す。

## 確かめないこと

- タップから先の導線（PR-1 では地図に手順があるだけ）
- ランキング参加時の Firebase のインラインスクリプトのハッシュ（それは `test/data/firebase_csp_headers_test.dart`）
- iPhone Safari
- release ビルドに特有の差

機能地図は `features/`。保守は `/maintain-verification-skill`。
