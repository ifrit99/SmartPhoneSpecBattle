# Boot and title

アプリを開くとタイトル画面が描かれ、`SPEC BATTLE` と `TAP TO START` が見える。通信やランキングを待たずにここまで来る。

## Sub-features

- `boot-serve` は profile ビルドを `127.0.0.1` で配り、`/` の HTML タイトルが `SPEC BATTLE` である。
- `boot-paint` は `[UxTiming] cold_to_title` が出て、タイトルが 1 フレーム描ける。
- `boot-labels` はセマンティクスまたは画面上で `SPEC BATTLE` と `TAP TO START` がある。
- `boot-no-firebase` はタイトルの合図までに Firebase API / firebasejs へリクエストしない。

## How to get to it (user POV)

- ブラウザでアプリの URL（検証では `http://127.0.0.1:<port>/`）を開く。
- クエリ無し。ディープリンク無し。
- タップはしない。タイトルに着いたところで止める。

## Driving it with cdp_drive.py

Preconditions:

- `verify.sh launch` が終わっている。
- `verify.sh doctor` が PASS。
- Chrome は検証ランの一時プロファイル。390x844。Firebase API ホスト 3 つは `--host-resolver-rules` で届かない。

- **Open app.** `Page.navigate` で `/` を開く。`GET /` はすでに 200 で `<title>SPEC BATTLE</title>`。
- **Wait for paint.** コンソールに `[UxTiming] cold_to_title` が出るまで待つ。既定 60 秒（`VERIFY_TIMEOUT`）。
- **Read labels.** 合図のあとセマンティクスを有効にし、`SPEC BATTLE` と `TAP TO START` を探す。
- **Capture.** タイトルのスクリーンショット 1 枚とイベント JSON、判定 1 行を `.local/verify-ssb/evidence/<run-id>/` に残す。
- **Proof.** 判定は SKILL.md の表。合図があり、失敗に数える行が 0 件で、`title.png` があるとき PASS。セマンティクスを掴めなければ `judgment.txt` に注意を残す。
- **Command.** `bash .agents/skills/verify-ssb/helpers/verify.sh drive boot-title`

## Gotchas

- Web では最初のタップは AudioContext の解除だけで、ホームへは行かない。PR-1 はタップしない。
- `TAP TO START` の点滅は cold_to_title より約 1.4 秒遅い。合図の直後だと Opacity 0 でセマンティクスから外れることがある。ドライブは約 1.6 秒待ってからセマンティクスを掴む。
- Flutter Web は canvas。セマンティクス placeholder（`Enable accessibility`）が無い・不安定なときは、合図と `title.png` で判定し、`judgment.txt` に注意を書く。`title.png` が無いときは FAIL。ラベル検査を外して黙らない。
- ダミーの Firebase キーでも `ServiceLocator.init` は `FirestoreRankingService` を組む。初期化自体は参加 ON まで呼ばない。呼ばれたら「起動時の Firebase」で FAIL。
- profile 以外のビルドでは `[UxTiming]` が出ない。release で回して通したことにしない。
