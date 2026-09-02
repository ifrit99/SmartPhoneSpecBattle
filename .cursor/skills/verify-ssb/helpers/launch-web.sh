#!/usr/bin/env bash
# Start Flutter web-server for verify-ssb. Does not open a browser.
# Usage: launch-web.sh <port> <run-dir>
set -euo pipefail

PORT="${1:-8091}"
RUN_DIR="${2:-}"

if [[ -z "$RUN_DIR" ]]; then
  echo "usage: $0 <port> <run-dir>" >&2
  exit 2
fi

if [[ ! "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1024 || PORT > 65535 )); then
  echo "refusing port '$PORT' (expected 1024-65535)" >&2
  exit 2
fi

mkdir -p "$RUN_DIR"
PORT_FILE="$RUN_DIR/port"
PID_FILE="$RUN_DIR/pid"
LOG_FILE="$RUN_DIR/flutter.log"

if command -v lsof >/dev/null 2>&1; then
  if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "port $PORT is already listening; refuse to steal it. pick 8091 or 8092." >&2
    lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >&2 || true
    exit 1
  fi
fi

FLUTTER_BIN="$(command -v flutter || true)"
if [[ -z "$FLUTTER_BIN" || ! -x "$FLUTTER_BIN" ]]; then
  FLUTTER_BIN="${HOME}/development/flutter/bin/flutter"
fi
if [[ ! -x "$FLUTTER_BIN" ]]; then
  echo "flutter not found on PATH or at $HOME/development/flutter/bin/flutter" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  cd "$ROOT"
else
  cd "$(cd "$SCRIPT_DIR/../../../.." && pwd)"
fi

# Record intent before spawn so doctor/cleanup have something to read on failure.
printf '%s\n' "$PORT" >"$PORT_FILE"
printf '%s\n' "$FLUTTER_BIN run -d web-server --web-hostname 127.0.0.1 --web-port $PORT" >"$RUN_DIR/launch-cmd"

set +e
"$FLUTTER_BIN" run -d web-server \
  --web-hostname 127.0.0.1 \
  --web-port "$PORT" \
  >"$LOG_FILE" 2>&1 &
FLUTTER_PID=$!
set -e
printf '%s\n' "$FLUTTER_PID" >"$PID_FILE"

ready=0
for _ in $(seq 1 90); do
  if ! kill -0 "$FLUTTER_PID" 2>/dev/null; then
    echo "flutter run exited before the server was ready. last log:" >&2
    tail -n 80 "$LOG_FILE" >&2 || true
    exit 1
  fi
  if grep -E "is being served at http://127\\.0\\.0\\.1:${PORT}|Debug service on http://127\\.0\\.0\\.1:${PORT}" "$LOG_FILE" >/dev/null 2>&1; then
    ready=1
    break
  fi
  if curl -fsS "http://127.0.0.1:${PORT}/" 2>/dev/null | grep -q "SPEC BATTLE"; then
    ready=1
    break
  fi
  sleep 1
done

if [[ "$ready" -ne 1 ]]; then
  echo "timed out waiting for web-server on 127.0.0.1:${PORT}" >&2
  tail -n 80 "$LOG_FILE" >&2 || true
  kill "$FLUTTER_PID" 2>/dev/null || true
  exit 1
fi

echo "verify-ssb web-server ready pid=$FLUTTER_PID url=http://127.0.0.1:${PORT}/"
echo "log=$LOG_FILE"
