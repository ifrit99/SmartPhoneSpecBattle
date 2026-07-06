#!/usr/bin/env bash
set -euo pipefail

# Codex エージェントを specbattle チームへ起動するスクリプト。
# tmux 内ならペイン分割、tmux 外なら新規ターミナルウィンドウで Codex が起動し、
# `/agmsg actas codex` が自動実行されてチームへ参加する。
#
# 実行方法: bash scripts/agmsg/start_codex.sh

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

exec "$AGMSG_SCRIPTS/spawn.sh" codex codex --project "$REPO_ROOT" --team specbattle "$@"
