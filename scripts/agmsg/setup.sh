#!/usr/bin/env bash
set -euo pipefail

# agmsg ハーネスの冪等セットアップスクリプト。
# - claude / codex エージェントを specbattle チームへ登録（未登録の場合のみ）
# - 配信モード（claude=monitor, codex=turn）を設定（毎回実行してよい）
# - チームメンバーを表示し、次の手順を案内する
#
# 実行方法: bash scripts/agmsg/setup.sh

AGMSG_SCRIPTS="$HOME/.agents/skills/agmsg/scripts"
TEAM="specbattle"
REPO_ROOT="$(git rev-parse --show-toplevel)"

if [ ! -x "$AGMSG_SCRIPTS/join.sh" ]; then
  echo "agmsgが見つかりません。https://github.com/fujibee/agmsg を参照してインストールしてください" >&2
  exit 1
fi

register_agent() {
  local agent_id="$1"
  local agent_type="$2"
  local whoami_out

  whoami_out="$("$AGMSG_SCRIPTS/whoami.sh" "$REPO_ROOT" "$agent_type" || true)"

  # 登録済み判定: 出力が agent=/multiple= で始まる（not_joined/suggest は未登録）ことに加え、
  # agents と teams のフィールド値そのものに一致すること（available_teams= への誤マッチを防ぐ）
  if echo "$whoami_out" | grep -qE '^(agent=|multiple=true)' \
    && echo "$whoami_out" | grep -qE "(^|[[:space:]])agents?=([^[:space:]]*,)?${agent_id}(,|[[:space:]]|$)" \
    && echo "$whoami_out" | grep -qE "(^|[[:space:]])teams=([^[:space:]]*,)?${TEAM}(,|[[:space:]]|$)"; then
    echo "[${agent_id}] 登録済みのためスキップします"
  else
    echo "[${agent_id}] チーム ${TEAM} へ登録します"
    "$AGMSG_SCRIPTS/join.sh" "$TEAM" "$agent_id" "$agent_type" "$REPO_ROOT"
  fi
}

register_agent claude claude-code
register_agent codex codex

# 配信モード設定（delivery.sh set は冪等なので毎回実行してよい）
"$AGMSG_SCRIPTS/delivery.sh" set monitor claude-code "$REPO_ROOT"
"$AGMSG_SCRIPTS/delivery.sh" set turn codex "$REPO_ROOT"

"$AGMSG_SCRIPTS/team.sh" "$TEAM"

echo ""
echo "セットアップが完了しました。"
echo "monitor モードは次回の Claude Code セッションから有効になります。"
echo "Codex の起動: bash scripts/agmsg/start_codex.sh"
