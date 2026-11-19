# SPEC BATTLE verification map

このディレクトリが、ユーザーから見える振る舞いを確かめる正本。先にこの目次を読み、使う機能ファイルをレシピにする。

## Baseline preconditions

- `bash .agents/skills/verify-ssb/helpers/verify.sh launch` で profile の Flutter Web を `http://127.0.0.1:<port>/` に出す。
- Firebase dart-define 4 つは `verify-dummy`。`SENTRY_DSN` は空。
- Chrome は検証ランが立てた一時プロファイルだけを使う。390x844。`--host-resolver-rules` で Firebase API ホスト 3 つを名前解決させない。
- `verify.sh doctor` が PASS のインスタンスだけを操作する。検証ランが立てていないプロセスは操作しない。
- 証明済みは `boot-title` だけ。他の地図は手順を書いてあるが PR-1 では未証明。

## Driving conventions

- レシピはタイトル画面の空のプロファイルから始める。前提が足りなければその機能の Gotchas に理由を書いて FAIL にする。通すために手順を弱めない。
- 操作は Flutter のセマンティクス（aria ラベル / 見える文言）で掴む。座標とタブ順は使わない。
- コマンドはリテラル。`verify.sh` のサブコマンドとフラグを書き換えない。
- ブラウザ操作は `cdp_drive.py`（PR-1 は boot-title 専用）。未証明の機能を `drive` に足して通したことにしない。
- cleanup はプロセスだけ止める。証拠は消さない。

## Proof and skip reporting

- ユーザー操作と、その結果の状態の両方を残す。最終画面だけは足りない。
- UI の証明にはセマンティクス（取れたとき）とスクリーンショットを残す。アプリのタイトル `SPEC BATTLE` が見えること。
- 起動の証明には `[UxTiming] cold_to_title` のコンソール行が要る。
- 到達できない道は、試したコマンドと足りなかった前提を報告する。別の入口で通したことを、その道の証明にしない。

## Feature entry contract

各ファイルは H1 と、ユーザーから見える振る舞いの 1 段落で始める。H2 はこの順で 4 つだけ。

1. `Sub-features`
2. `How to get to it (user POV)`
3. `Driving it with cdp_drive.py`
4. `Gotchas`

実装の内部名は書かない。ユーザーの道、安定したハンドル、必要な状態、コマンド、観測できる証明だけを書く。

## Features

- [Boot and title](./boot-title.md) — 起動してタイトルが 1 フレーム描ける。**証明済み（PR-1）**
- [CPU battle](./cpu-battle.md) — ホームから CPU 戦へ。**未証明**
- [URL battle](./url-battle.md) — Friend から URL 共有 / URL 入力。**未証明**
