#!/usr/bin/env bash
# Tear down only the verify-ssb web-server recorded in <run-dir>.
# Does not delete .local/verify-ssb/evidence/.
# Usage: cleanup.sh <run-dir>
set -euo pipefail

RUN_DIR="${1:-}"
if [[ -z "$RUN_DIR" ]]; then
  echo "usage: $0 <run-dir>" >&2
  exit 2
fi

PID_FILE="$RUN_DIR/pid"
if [[ ! -f "$PID_FILE" ]]; then
  echo "cleanup: no pid file in $RUN_DIR (nothing to kill)"
  rm -rf "$RUN_DIR"
  exit 0
fi

PID="$(tr -d '[:space:]' <"$PID_FILE")"
if [[ -n "$PID" ]] && kill -0 "$PID" 2>/dev/null; then
  # Kill the flutter run process group if we started it in its own group;
  # otherwise the pid and known children.
  if command -v pkill >/dev/null 2>&1; then
    pkill -TERM -P "$PID" 2>/dev/null || true
  fi
  kill -TERM "$PID" 2>/dev/null || true
  for _ in $(seq 1 20); do
    if ! kill -0 "$PID" 2>/dev/null; then
      break
    fi
    sleep 0.2
  done
  if kill -0 "$PID" 2>/dev/null; then
    if command -v pkill >/dev/null 2>&1; then
      pkill -KILL -P "$PID" 2>/dev/null || true
    fi
    kill -KILL "$PID" 2>/dev/null || true
  fi
  echo "cleanup: stopped pid $PID"
else
  echo "cleanup: pid ${PID:-empty} already gone"
fi

rm -rf "$RUN_DIR"
echo "cleanup: removed $RUN_DIR (evidence directory was not touched)"
