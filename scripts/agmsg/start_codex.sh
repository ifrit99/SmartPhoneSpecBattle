#!/usr/bin/env bash
set -euo pipefail

# Codex エージェントを specbattle チームへ起動するスクリプト。
# tmux 内ならペイン分割、tmux 外なら新規ターミナルウィンドウで Codex が起動し、
# `/agmsg actas codex` が自動実行されてチームへ参加する。
#
# 使い方:
#   bash scripts/agmsg/start_codex.sh
#   bash scripts/agmsg/start_codex.sh "[TASK] t1 <目的> branch=feature/xxx spec=docs/plans/xxx.md"
#
# 第1引数が `-` で始まらない文字列として存在する場合、それを「初回タスクメッセージ」
# として扱い、spawn 前に codex 宛てに送信する。残りの引数は spawn にそのまま渡す。
#
# なぜ「送信→起動」なのか:
#   Codex はturnモード（自分のターン終了時のみ受信箱をチェックする）で動作する。
#   起動済みでアイドル状態のCodexにメッセージを送っても、次にCodexのターンが
#   発生するまで届かない＝人間の入力なしには実装が始まらない。
#   一方、Codex起動時の初回ターン（`/agmsg actas codex`）が終了した時点ではturnフック
#   （Stop hook）が受信箱をチェックするため、spawn前に送っておいた [TASK] はそこで
#   配信され、人手なしに実装が始まる。
#   なお、agmsg が `--boot-prompt` 対応版（spawn.shが対応済み）の場合は、送信せずに
#   起動時の初回プロンプトへ直接タスクを載せる公式機構を自動的に使う。
#   また、turnフックの受信箱チェックには60秒クールダウンがあり、起動直後の自動チェックが
#   スキップされることがあるが、`AGENTS.md` の指示によりCodexはセッション開始ターン内で
#   必ず手動で受信箱を確認するため、その場合も保険として取りこぼしを防げる。

AGMSG_SCRIPTS="$HOME/.agents/skills/agmsg/scripts"

if ! command -v codex >/dev/null 2>&1; then
  echo "Codex CLI が見つかりません" >&2
  exit 1
fi

if [ ! -x "$AGMSG_SCRIPTS/spawn.sh" ]; then
  echo "agmsgが見つかりません。https://github.com/fujibee/agmsg を参照してインストールしてください" >&2
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"

TASK_MSG=""
if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then
  TASK_MSG="$1"
  shift
fi

if [ -n "$TASK_MSG" ]; then
  if grep -q -- '--boot-prompt' "$AGMSG_SCRIPTS/spawn.sh"; then
    echo "agmsgが--boot-prompt対応版のため、初回プロンプトにタスクを載せて起動します"
    exec "$AGMSG_SCRIPTS/spawn.sh" codex codex --project "$REPO_ROOT" --team specbattle --boot-prompt "$TASK_MSG" "$@"
  fi
  "$AGMSG_SCRIPTS/send.sh" specbattle claude codex "$TASK_MSG"
  echo "[TASK]を送信しました。Codex起動後の初回ターン終了時に自動配信されます。起動直後のturnフックが60秒クールダウンでスキップされた場合も、AGENTS.mdの指示によりCodexがセッション開始ターン内で受信箱を確認するため取りこぼしません。"
else
  echo "注意: turnモードのCodexはアイドル中に受信箱を確認しません。タスクを自動で始めさせるには、起動前にメッセージを送るか、このスクリプトの第1引数でタスクを渡してください。"
fi

exec "$AGMSG_SCRIPTS/spawn.sh" codex codex --project "$REPO_ROOT" --team specbattle "$@"
