#!/usr/bin/env bash
# verify-ssb: launch / doctor / drive boot-title / cleanup / all
set -euo pipefail

ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
HELPERS="$ROOT/.agents/skills/verify-ssb/helpers"
STATE_DIR="$ROOT/.local/verify-ssb"
STATE_FILE="$STATE_DIR/state.json"
PORT_FILE="$STATE_DIR/port"
CHROME_PID_FILE="$STATE_DIR/chrome.pid"
BUILD_DIR="$ROOT/build/web"
HEADERS_FILE="$ROOT/web/_headers"
EVIDENCE_ROOT="$STATE_DIR/evidence"
TIMEOUT="${VERIFY_TIMEOUT:-60}"

mkdir -p "$STATE_DIR" "$EVIDENCE_ROOT"

fail_env() {
  echo "env: $*" >&2
  exit 2
}

chrome_bin() {
  if [[ -n "${CHROME_EXECUTABLE:-}" ]]; then
    printf '%s\n' "$CHROME_EXECUTABLE"
    return
  fi
  local name
  for name in google-chrome google-chrome-stable chromium-browser chromium; do
    if command -v "$name" >/dev/null 2>&1; then
      command -v "$name"
      return
    fi
  done
  return 1
}

check_prereqs() {
  command -v python3 >/dev/null 2>&1 || fail_env "python3 が無い"
  command -v flutter >/dev/null 2>&1 || fail_env "flutter が無い"
  python3 - <<'PY' || fail_env "flutter が 3.44.x ではない"
import subprocess, sys
proc = subprocess.run(["flutter", "--version"], capture_output=True, text=True)
text = (proc.stdout or "") + (proc.stderr or "")
sys.exit(0 if "Flutter 3.44." in text else 1)
PY
  chrome_bin >/dev/null || fail_env "chrome が無い (google-chrome または CHROME_EXECUTABLE)"
  python3 - "$ROOT" <<'PY' || fail_env "https://www.gstatic.com/flutter-canvaskit/ に届かない"
import sys, urllib.error, urllib.request
url = "https://www.gstatic.com/flutter-canvaskit/"
try:
    urllib.request.urlopen(url, timeout=10)
except urllib.error.HTTPError:
    pass
except Exception as exc:
    print(exc, file=sys.stderr)
    sys.exit(1)
PY
}

pid_alive() {
  local pid="${1:-}"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

read_state() {
  python3 - "$STATE_FILE" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
if not path.is_file():
    raise SystemExit(1)
data = json.loads(path.read_text())
print(data.get("run_id", ""))
print(data.get("server_pid", ""))
print(data.get("port", ""))
print(data.get("url", ""))
print(data.get("evidence_dir", ""))
PY
}

write_state() {
  local run_id="$1" server_pid="$2" port="$3" url="$4" evidence_dir="$5"
  python3 - "$STATE_FILE" "$run_id" "$server_pid" "$port" "$url" "$evidence_dir" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
path.write_text(json.dumps({
    "run_id": sys.argv[2],
    "server_pid": int(sys.argv[3]),
    "port": int(sys.argv[4]),
    "url": sys.argv[5],
    "evidence_dir": sys.argv[6],
}, indent=2) + "\n")
PY
}

kill_pid() {
  local pid="${1:-}"
  if pid_alive "$pid"; then
    kill "$pid" 2>/dev/null || true
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
      pid_alive "$pid" || return 0
      sleep 0.1
    done
    kill -9 "$pid" 2>/dev/null || true
  fi
}

pid_cmdline_has() {
  local pid="${1:-}" needle="${2:-}"
  [[ -n "$pid" && -n "$needle" ]] || return 1
  python3 - "$pid" "$needle" <<'PY'
import pathlib, sys
pid, needle = sys.argv[1], sys.argv[2]
path = pathlib.Path(f"/proc/{pid}/cmdline")
if not path.is_file():
    raise SystemExit(1)
cmdline = path.read_bytes().replace(b"\x00", b" ").decode("utf-8", "replace")
raise SystemExit(0 if needle in cmdline else 1)
PY
}

kill_owned_pid() {
  local pid="${1:-}" needle="${2:-}"
  [[ -n "$pid" ]] || return 0
  if ! pid_alive "$pid"; then
    return 0
  fi
  if ! pid_cmdline_has "$pid" "$needle"; then
    echo "cleanup skip pid=$pid (cmdline has no ${needle})" >&2
    return 0
  fi
  kill_pid "$pid"
}

cmd_cleanup() {
  local run_id="" server_pid="" port="" url="" evidence_dir=""
  if [[ -f "$STATE_FILE" ]]; then
    local state
    state="$(read_state || true)"
    if [[ -n "$state" ]]; then
      run_id="$(printf '%s\n' "$state" | sed -n '1p')"
      server_pid="$(printf '%s\n' "$state" | sed -n '2p')"
      port="$(printf '%s\n' "$state" | sed -n '3p')"
      url="$(printf '%s\n' "$state" | sed -n '4p')"
      evidence_dir="$(printf '%s\n' "$state" | sed -n '5p')"
    fi
  fi
  kill_owned_pid "$server_pid" "serve_with_headers.py"
  if [[ -f "$CHROME_PID_FILE" ]]; then
    kill_owned_pid "$(tr -d '[:space:]' < "$CHROME_PID_FILE")" "verify-ssb-chrome"
    rm -f "$CHROME_PID_FILE"
  fi
  rm -f "$STATE_FILE" "$PORT_FILE"
  if [[ -n "$evidence_dir" && -d "$evidence_dir" ]]; then
    echo "evidence remains: $evidence_dir"
  elif [[ -n "$run_id" && -d "$EVIDENCE_ROOT/$run_id" ]]; then
    echo "evidence remains: $EVIDENCE_ROOT/$run_id"
  fi
}

wait_http_ready() {
  local url="$1"
  local i
  for i in $(seq 1 50); do
    if python3 - "$url" <<'PY'
import sys, urllib.request
url = sys.argv[1]
try:
    with urllib.request.urlopen(url, timeout=2) as resp:
        body = resp.read().decode("utf-8", "replace")
        raise SystemExit(0 if resp.status == 200 and "<title>SPEC BATTLE</title>" in body else 1)
except Exception:
    raise SystemExit(1)
PY
    then
      return 0
    fi
    sleep 0.1
  done
  return 1
}

cmd_launch() {
  check_prereqs
  cmd_cleanup >/dev/null || true
  echo "building profile web with dummy Firebase dart-define..."
  (
    cd "$ROOT"
    flutter build web --profile --base-href "/" \
      --dart-define=FIREBASE_API_KEY=verify-dummy \
      --dart-define=FIREBASE_APP_ID=verify-dummy \
      --dart-define=FIREBASE_MESSAGING_SENDER_ID=verify-dummy \
      --dart-define=FIREBASE_PROJECT_ID=verify-dummy
  )
  [[ -d "$BUILD_DIR" ]] || fail_env "build/web が無い"
  rm -f "$PORT_FILE"
  python3 "$HELPERS/serve_with_headers.py" \
    --root "$BUILD_DIR" \
    --headers "$HEADERS_FILE" \
    --bind 127.0.0.1 \
    --port 0 \
    --port-file "$PORT_FILE" &
  local server_pid=$!
  local i port=""
  for i in $(seq 1 50); do
    if [[ -f "$PORT_FILE" ]]; then
      port="$(tr -d '[:space:]' < "$PORT_FILE")"
      [[ -n "$port" ]] && break
    fi
    pid_alive "$server_pid" || fail_env "serve_with_headers.py がすぐ終了した"
    sleep 0.1
  done
  [[ -n "$port" ]] || fail_env "ポートを取得できない"
  local url="http://127.0.0.1:${port}/"
  wait_http_ready "$url" || {
    kill_owned_pid "$server_pid" "serve_with_headers.py"
    fail_env "/ が 200 と <title>SPEC BATTLE</title> を返さない"
  }
  local run_id
  run_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  local evidence_dir="$EVIDENCE_ROOT/$run_id"
  mkdir -p "$evidence_dir"
  write_state "$run_id" "$server_pid" "$port" "$url" "$evidence_dir"
  echo "ready $url"
  echo "run_id $run_id"
}

cmd_doctor() {
  check_prereqs
  [[ -f "$STATE_FILE" ]] || { echo "doctor FAIL: instance is not running"; exit 1; }
  local run_id server_pid port url evidence_dir
  run_id="$(read_state | sed -n '1p')"
  server_pid="$(read_state | sed -n '2p')"
  port="$(read_state | sed -n '3p')"
  url="$(read_state | sed -n '4p')"
  evidence_dir="$(read_state | sed -n '5p')"
  pid_alive "$server_pid" || { echo "doctor FAIL: server pid $server_pid is dead"; exit 1; }
  python3 - "$server_pid" "$port" <<'PY' || { echo "doctor FAIL: port is not owned by our server"; exit 1; }
import pathlib, socket, sys
pid = int(sys.argv[1])
port = int(sys.argv[2])
cmdline_path = pathlib.Path(f"/proc/{pid}/cmdline")
if not cmdline_path.is_file():
    sys.exit(1)
cmdline = cmdline_path.read_bytes().replace(b"\x00", b" ").decode("utf-8", "replace")
if "serve_with_headers.py" not in cmdline:
    sys.exit(1)
try:
    with socket.create_connection(("127.0.0.1", port), timeout=2):
        pass
except OSError:
    sys.exit(1)
PY
  wait_http_ready "$url" || { echo "doctor FAIL: $url is not ready"; exit 1; }
  echo "doctor PASS pid=$server_pid port=$port run_id=$run_id evidence=$evidence_dir"
}

cmd_drive() {
  local feature="${1:-}"
  if [[ "$feature" != "boot-title" ]]; then
    echo "FAIL: feature '${feature:-}' is unproven; PR-1 only drives boot-title" >&2
    exit 1
  fi
  [[ -f "$STATE_FILE" ]] || { echo "FAIL: launch していない"; exit 1; }
  local evidence_dir url
  evidence_dir="$(read_state | sed -n '5p')"
  url="$(read_state | sed -n '4p')"
  [[ -n "$evidence_dir" && -n "$url" ]] || { echo "FAIL: state が壊れている"; exit 1; }
  mkdir -p "$evidence_dir"
  python3 "$HELPERS/cdp_drive.py" \
    --url "$url" \
    --evidence "$evidence_dir" \
    --timeout "$TIMEOUT" \
    --pid-file "$CHROME_PID_FILE"
  local status=$?
  if [[ -f "$CHROME_PID_FILE" ]]; then
    kill_owned_pid "$(tr -d '[:space:]' < "$CHROME_PID_FILE")" "verify-ssb-chrome"
    rm -f "$CHROME_PID_FILE"
  fi
  return "$status"
}

format_duration() {
  local total="$1"
  local minutes=$((total / 60))
  local seconds=$((total % 60))
  if [[ "$minutes" -gt 0 ]]; then
    printf '%sm%ss' "$minutes" "$seconds"
  else
    printf '%ss' "$seconds"
  fi
}

cmd_all() {
  local started=$SECONDS
  local status=0
  trap 'cmd_cleanup >/dev/null || true' EXIT
  cmd_launch
  cmd_doctor
  set +e
  cmd_drive boot-title
  status=$?
  set -e
  local evidence_dir
  evidence_dir="$(read_state | sed -n '5p' || true)"
  cmd_cleanup
  if [[ -z "$evidence_dir" || ! -f "$evidence_dir/judgment.txt" ]]; then
    echo "FAIL: cleanup ate the proof or drive wrote none" >&2
    exit 1
  fi
  echo "evidence remains after cleanup: $evidence_dir"
  local elapsed
  elapsed="$(format_duration $((SECONDS - started)))"
  if [[ "$status" -eq 0 ]]; then
    echo "Verified: verify-ssb(PASS $elapsed)"
    exit 0
  fi
  if [[ "$status" -eq 2 ]]; then
    echo "Verified: verify-ssb(未実行: 環境)"
    exit 2
  fi
  local judgment
  judgment="$(tr -d '\n' < "$evidence_dir/judgment.txt")"
  echo "Verified: verify-ssb(FAIL $elapsed) $judgment"
  exit 1
}

usage() {
  cat <<EOF
usage: $(basename "$0") launch|doctor|drive boot-title|cleanup|all
EOF
  exit 2
}

cmd="${1:-}"
case "$cmd" in
  launch) cmd_launch ;;
  doctor) cmd_doctor ;;
  drive) cmd_drive "${2:-}" ;;
  cleanup) cmd_cleanup ;;
  all) cmd_all ;;
  *) usage ;;
esac
