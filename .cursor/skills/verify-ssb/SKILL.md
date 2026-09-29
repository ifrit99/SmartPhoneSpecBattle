---
name: verify-ssb
description: Drive SmartPhoneSpecBattle (SPEC BATTLE) Flutter web UI on the user's Mac with Cursor Agent browser — navigate, click like a user, snapshot, screenshot for human judgment. Use when proving a feature or checking a UI/flow change. Playwright (headless, --mute-audio) is only for the pixel-diff merge gate when the user explicitly asks. Never Cloud Agent or Grok Bot browser.
---

# Verify SmartPhoneSpecBattle (SPEC BATTLE)

You are writing instructions for the next agent, not a human. Drive the **real Flutter web app**, the way a player does. Do not call widget tests, `BattleEngine` directly, or test-only setters and then claim the feature works.

**Default harness (2026-09-04):** Mac **Cursor Agent browser** (Cursor IDE agent browser tools: navigate, click, snapshot, screenshot). The **user** judges the screenshots. Do not pixel-diff vs `master` on this path.

Cloud Agents **cannot** execute Drive. Grok Bot's browser is **not** this skill. Follow Launch → Doctor → Drive → Evidence → Cleanup in the user's Mac Cursor session.

## What this skill is / is not

- **This skill** is the feature-flow map: launch Flutter web, open it in Cursor Agent browser, click like a user, capture screenshots for **human judgment**.
- **Not this skill's default Drive:** Playwright. Headless Playwright (`--mute-audio`, Mac Claude Code Opus MCP) is **only** the strict pixel-diff merge gate, and only when the user **explicitly asks** for that gate. Use the separate merge-gate skill then. Never headed Chrome on that path (BGM hits AirPods).
- **Not this skill:** Grok Bot's browser, Cloud Agent browsers, or any remote browser. Do **not** pass this Drive section to a Cloud Agent.
- **Not this skill:** `flutter analyze` / `flutter test` (required by `CLAUDE.md` for code changes; they do not prove the running UI).
- A green feature-flow pass here does **not** replace the pixel-diff merge gate. That gate still runs only when the user asks for it.

## Surface

| Surface | Role |
|---|---|
| **Flutter web UI** (`lib/main.dart` → `TitleScreen`) | **Primary. This is what you drive** in Cursor Agent browser. Production: `https://ifrit99.github.io/SmartPhoneSpecBattle/` (`web/index.html` og:url). Local: `flutter run -d web-server` via helpers. |
| Android (`android/`) / iOS (`ios/`) | Secondary native shells. Web-MVP is the shipped product (`docs/TODO.md`). Do **not** make `flutter run` on a device/emulator the drive path. Native Android currently needs a compileSdk/AGP bump (`url_launcher`) and is out of scope. |
| Docker `flutter-dev` | `analyze`/`test` isolation only (`README.md`). Compose maps `8080:8080` but the container `CMD` is `tail -f /dev/null` — it does **not** serve the game until someone execs `flutter run` inside it. Do not use Docker as the default drive path. |
| `scripts/serve-iphone.sh` | LAN/Tailscale Safari on **port 8090**. Human-on-phone helper, not the Cursor Agent browser path. |

App id: Dart package `spec_battle_game`, window title `SPEC BATTLE`, theme scaffold `#0D1B2A`. State lives in `shared_preferences` (web: origin-scoped `localStorage`, keys such as `onboarding_completed`, `first_battle_completed`, `coins`, `sound.bgmMuted`). BGM is `audioplayers` (`assets/sounds/Crimson_Gauntlet.mp3`); SE on web is `document.createElement('audio')` (`lib/data/web_se_player_web.dart`).

## Mac operator notes (read before Launch)

1. **Do not use a Documents checkout.** A clone under `~/Documents` hangs on this machine. Use a throwaway clone under `~/orca/workspaces/` (example: `~/orca/workspaces/ssb-verify`).
2. **Do not collide with an in-progress graphics session.** That session may already own Flutter / port 8080 / a Chrome profile. Default verify ports are **8091** and **8092**, not 8080 or 8090.
3. **Run Drive only in the user's Mac Cursor session.** Do **not** pass this Drive to Cloud Agents. Do **not** use Grok Bot's browser for SSB verify.
4. **Mute / BGM:** prefer muted audio so game BGM does not hit AirPods. Open Cursor Agent browser muted if the tool allows it; otherwise lower OS output or tap in-game `BGM` / `SE` once those chips exist (battle overlay). Do **not** launch headed Chrome for feature-flow. Headless Playwright `--mute-audio` is the merge-gate skill only, and only when the user asked for that gate.
5. Flutter SDK on the operator Mac has been `~/development/flutter/bin/flutter` (see `scripts/serve-iphone.sh`) at 3.44.0. Prefer `flutter` on PATH if it is 3.44.x; otherwise that path.

---

## Launch

Work from the throwaway clone root. Create a run dir (evidence stays elsewhere):

```bash
RUN_ID="$(date +%Y%m%d-%H%M%S)-$$"
RUN_DIR=".local/verify-ssb/runs/${RUN_ID}"
EVIDENCE_DIR=".local/verify-ssb/evidence/${RUN_ID}"
mkdir -p "$RUN_DIR" "$EVIDENCE_DIR"
```

`.local/` is gitignored. Proof artifacts live under `EVIDENCE_DIR` and **survive** Cleanup.

### Start the web server (exact command)

Prefer the helper (records pid/port, refuses a busy port):

```bash
./.cursor/skills/verify-ssb/helpers/launch-web.sh 8091 "$RUN_DIR"
# optional third arg: release (default) | debug
```

The helper **detaches** with `nohup` + `disown` so the Flutter process group survives when the launching command exits. A bare `flutter ... &` dies with SIGHUP (Mac live failure). Plain `setsid cmd &` EPERMs because a background job is already a process-group leader. After the serve line appears, the helper records `spawn_pid`, `pgid`, and the **listen pid that owns the port** (`pid`).

Equivalent raw command (must detach; default verify mode is `--release`):

```bash
FLUTTER_BIN="$(command -v flutter || true)"
[ -x "$FLUTTER_BIN" ] || FLUTTER_BIN="$HOME/development/flutter/bin/flutter"
nohup "$FLUTTER_BIN" run -d web-server --release \
  --web-hostname 127.0.0.1 \
  --web-port 8091 \
  >"$RUN_DIR/flutter.log" 2>&1 < /dev/null &
disown
```

`--release` avoids the debug-DDC wedge after a failed first client (blank body, only `flutter_bootstrap.js`). Pass `debug` as the helper's third argument only if you intentionally want DDC; then do not hit the server until the serve line appears.

**Ready when** `flutter.log` contains the serve URL line (this is the only ready signal):

```text
lib/main.dart is being served at http://127.0.0.1:8091
```

**Not ready:**

- `Waiting for connection from debug service on Web Server...` (too early; Dart is not served yet)
- HTTP 200 with `<title>SPEC BATTLE</title>` from `web/index.html` (static shell; also served during the wait)
- `curl` succeeding before the serve line exists

Do **not** use:

- `flutter run -d chrome` (opens headed Chrome, plays BGM, occupies the GPU/session)
- `flutter run` with `--web-port 8080` if Docker or a graphics session might already bind it
- GitHub Pages as the drive target for unmerged work (that is production `master`)

Second instance (isolation): same command with `--web-port 8092` and a second `RUN_DIR`. See Isolate below.

Teardown is Cleanup, not a second Launch.

---

## Doctor

Read-only. Run whenever the page looks stale, a click no-ops, or after a hot restart.

```bash
./.cursor/skills/verify-ssb/helpers/doctor.sh "$RUN_DIR"
```

Pass means all of:

1. `pid` in `RUN_DIR` is the **listen pid that owns the port** and is still alive. `spawn_pid` (the detached `flutter run`) is still alive. Do not doctor a random listener.
2. `lsof -iTCP:<port> -sTCP:LISTEN` matches that listen pid (or a child of spawn/listen).
3. `flutter.log` contains `lib/main.dart is being served at http://127.0.0.1:<port>` (`serve-url` file exists). HTML title alone is **not** a pass.
4. `GET http://127.0.0.1:<port>/` is HTTP 200 and the body contains `<title>SPEC BATTLE</title>` (identity check that this is Spec Battle, after the serve line).
5. After Cursor Agent browser **navigate** to `http://127.0.0.1:<port>/`: the document has a Flutter surface (`canvas`, `flt-glass-pane`, or `flutter-view`) **and** enabling accessibility (below) reveals `SPEC BATTLE` and `TAP TO START` (`test/presentation/title_screen_test.dart`).

Fail means: do not Drive. Re-Launch on a free port, or Cleanup the stranded run first. Do not attach to someone else's Flutter process.

---

## Drive

Harness: **Mac Cursor Agent browser** (Cursor IDE agent browser tools). Actions: **navigate**, **click**, **snapshot**, **screenshot**. Not Playwright. Not Grok Bot. Not a Cloud Agent.

### Open the app

1. After Launch/Doctor, **navigate** to `http://127.0.0.1:<port>/` (no `?battle=` unless proving the deep link).
2. Prefer a **narrow / phone-like viewport** if the browser tool allows it (this UI is a mobile-game column; ~390×844). If the tool has no viewport lock, still treat below-fold Flutter chrome as real (see gotcha).
3. Prefer **muted audio** when opening the browser (tool mute flag, silent profile, or OS output down). Title web still needs two taps for Dart audio unlock even when silent. Do not open headed Chrome for this path.
4. Use a **fresh browser profile / origin** per run when the tool can (isolates `localStorage` / `shared_preferences`). Same origin as a leftover session reuses onboarding flags and coins.

### Flutter web selectors (Cursor Agent browser)

The app paints with CanvasKit/skwasm. Visible pixels are on a canvas; **stable handles are the semantics tree + exact widget text from this repo**. Workflow: **snapshot** → find the string/role → **click** → **snapshot** again → **screenshot** for the user.

After navigate and Flutter first-frame:

1. **Snapshot.** If `Enable accessibility` or `flt-semantics-placeholder` is present, **click it once with force** (or click that DOM node even if off-screen). It sits **outside the 390×844 viewport**; a normal in-view click **times out or never hits**. Then snapshot until `flt-semantics` (or equivalent a11y nodes) appear.
2. Prefer click-by-role **button** whose accessible name is the exact label in this map (`Party`, `バトル開始`, `協力しない`, …). Material `ElevatedButton` / `OutlinedButton` / `TextButton` expose their child text.
3. For `GestureDetector` / `InkWell` chrome that is **not** a Material button, snapshot then click the exact visible string. Coordinates only as a last resort on the title canvas.
4. There are almost **no** `ValueKey`s on primary CTAs. Exceptions (input-state only, not navigation): URL input `ValueKey('error'|'ready'|'empty')` in `lib/presentation/screens/qr_scan_screen.dart`; backup import `ValueKey(_hasImportInput)` in `data_backup_screen.dart`. Do not invent `data-testid`s.
5. **Semantics in the tree ≠ painted in the canvas fold.** Scrolling a semantics node into view does **not** move the Flutter canvas. `Party` / `Gacha` / `バトル開始` (and the home card stack) can show up in a snapshot while still below the first painted fold. Presence in the snapshot is a valid "we are on home" proof. To **click** a below-fold painted control, wheel/drag the **canvas** until it is in view, then click; do not assume a11y-scroll will do it.

### Boot path (every cold context)

Web title (`lib/presentation/screens/title_screen.dart`):

1. Snapshot until `SPEC BATTLE` and `TAP TO START` are in the tree. Subtitle `スマホのスペックで戦え` fades in ~0.8s after logo; tap prompt ~1.4s. `v0.1.0` is at the bottom. Screenshot the title for the user.
2. **First click anywhere on the view** (the body is one `GestureDetector`). This only runs `SoundService.unlockAudio()` + `playBgm()` and **stays on the title**. Mute keeps AirPods quiet; the Dart gate still requires this tap.
3. **Second click** leaves the title (`pushReplacement` fade 600ms). Snapshot.
4. If `analytics_consent` is unanswered, dialog `プレイデータ送信へのご協力` with buttons `協力しない` / `協力する` (`analytics_consent_dialog.dart`). For a feature proof that is not Privacy, click **`協力しない`**. Never type `协力しない` (simplified 协); the label is Japanese `協力しない`.
5. If `onboarding_completed` is false, `OnboardingScreen`: `スキップ` (always visible) or `次へ` ×2 then `はじめる！`. Fast path: **`スキップ`**. Pages: `あなたのスマホが\nキャラクターに！` → `スペックが\n能力値に変わる` → `まずは1回\nバトルしてみよう！`.
6. Home (`HomeScreen`). First-run also shows `はじめてのバトル！` banner. Login popup `ログインボーナス！` / button `受け取る` may appear; dismiss with `受け取る` before asserting home chrome. Screenshot home for the user — they judge, no pixel-diff vs `master`.

You are on home when several of these are in the **semantics tree** (home is a long `SingleChildScrollView`; many sit below the first canvas fold — see Drive gotcha above). Live proof of `features/home.md` used semantics presence of the menu row plus `バトル開始`:

| Handle | Kind | Source |
|---|---|---|
| `Party` | OutlinedButton | `home_screen.dart` |
| `Gacha` | OutlinedButton | same |
| `Collection` | OutlinedButton | same |
| `Friend` | OutlinedButton | same |
| `Help` | OutlinedButton | same |
| `Privacy` | OutlinedButton | same |
| `Backup` | OutlinedButton | same |
| `バトル開始` | ElevatedButton | `_buildBattleButton` |
| `見た目` | text on GestureDetector | character card |
| `タップしてキャラクター詳細を見る` | hint text | bottom of home |
| `Lv.` | player level | character card |
| `バトル数` / `勝利数` / `勝率` | RecordCard | `record_card.dart` |
| `推定上位` | PowerRatingCard | `power_rating_card.dart` |
| `解析ロードマップ` | card title | `home_screen.dart` |
| `日替わりショップ` | card title | `home_screen.dart` |
| `ライバルロード` | card title | `rival_road_card.dart` |
| `高難度チャレンジ` | card title | `home_screen.dart` |
| `シーズンパス YYYY-MM` | card title | `season_pass_card.dart` (`'シーズンパス ${pass.seasonId}'`; live semantics may drop the space, e.g. `シーズンパス2026-09`) |

AppBar titles after navigation (use these as "we arrived" checks):

| Screen | AppBar / chrome |
|---|---|
| Character | `キャラクター` |
| Inventory | `編成・インベントリ` |
| Gacha | `ガチャ` |
| Collection | `コレクション` + tabs `敵キャラ図鑑` / `プレイヤー履歴` / `実績` |
| Friend menu | `フレンド対戦` |
| Share | `対戦URLを共有` |
| URL input | `対戦コードを入力` |
| Guest preview | `対戦プレビュー` |
| Help | `遊び方` |
| Privacy | `Privacy` |
| Backup | `データ保護` |
| Avatar studio | `アバタースタジオ` |

There is **no** named Navigator route table. `MaterialApp.home` is `TitleScreen`; everything else is `Navigator.push` / `pushReplacement`. Deep link: `/?battle=<encoded>` (`QrBattleService.extractBattleParam` in `main.dart`) opens guest preview, skipping title.

Feature-specific clicks: `features/`. Map entries you did not drive are not proved.

### Isolate

Two instances **are** possible: different `--web-port` values (8091 vs 8092) are different origins, so `localStorage` / `shared_preferences` do not collide. Open each origin in its own Cursor Agent browser tab/profile when proving two-player URL flow.

**Refuse to double-drive a shared instance.** If 8091 is already serving a Flutter app you did not start (doctor pid mismatch, or a graphics session), do not navigate to it. Launch on 8092 or stop.

Do not open two Drive sessions against the same origin: home `shared_preferences` (coins, onboarding flags, equipped gacha id) is process-global per origin.

### Out of scope (Playwright)

Do **not** use Playwright, headed Chrome, Cloud Agent browsers, or Grok Bot's browser for this Drive. If the user **explicitly** asks for the strict pixel-diff merge gate (home vs `master`), leave this skill and use the **separate merge-gate skill** (headless Playwright, `--mute-audio`, Mac Claude Code Opus MCP). Never headed Chrome on that path.

---

## Evidence

Root: `.local/verify-ssb/evidence/<run-id>/` (created at Launch). Cleanup must not delete this directory.

Proof standards:

1. Exercise the **real user path** (title taps → home → feature). Do not seed `SharedPreferences` from a snippet and jump to a screen via a test harness.
2. Capture **the action and the resulting state**, not one final frame. Minimum per feature: **screenshot** before the click, **screenshot** after, plus one observable (text, AppBar, snackbar, currency digit, log line, `localStorage` key). Screenshots are for **the user to judge**. Do not pixel-diff vs `master` on this path.
3. Side effects for this app are **origin `localStorage`** (Flutter `shared_preferences`). After a CPU win you should see `battle_count` / `win_count` / `coins` change if you read storage; after onboarding skip, `onboarding_completed` is true. Reading storage is supporting evidence, not a substitute for the UI.
4. Do not mock `BattleEngine`, gacha RNG, or network. There is no game backend. `?battle=` is the character payload. Sentry/Firebase are no-op without dart-defines; ignore them.
5. Audio is **not** evidence. Prefer mute (see Mac notes). Mute toggles `BGM` / `SE` on the battle overlay are optional chrome, not a pass criterion unless the bug is mute.

Suggested files:

```text
.local/verify-ssb/evidence/<run-id>/
  00-title.png
  01-home.png
  <feature>-before.png
  <feature>-after.png
  notes.md          # what was clicked, what text appeared, port, run-id
```

`notes.md` must name the feature file under `features/` and quote the on-screen strings that proved it.

---

## Cleanup

```bash
./.cursor/skills/verify-ssb/helpers/cleanup.sh "$RUN_DIR"
```

- Kills **only** the process group recorded at Launch (`pgid` / `spawn_pid` / listen `pid`). Never `pkill flutter` / `killall dart`.
- Removes `$RUN_DIR` (pid/port/log).
- **Leaves** `.local/verify-ssb/evidence/<run-id>/` in place.
- Closes the Cursor Agent browser tab/session this run opened, if the tool lets you. Do not close other browsers or a graphics-session Chrome.

After cleanup, confirm evidence files still exist (`ls "$EVIDENCE_DIR"`). A cleanup that ate the proof failed.

---

## Helpers

All under `.cursor/skills/verify-ssb/helpers/`. Executable. Invocation is in Launch / Doctor / Cleanup.

| Script | Purpose |
|---|---|
| `helpers/launch-web.sh <port> <run-dir> [release\|debug]` | detached `flutter run -d web-server` (`--release` default) on `127.0.0.1:<port>`; waits for the serve line; writes listen `pid`, `spawn_pid`, `pgid`, `serve-url`, `flutter.log`; refuses a busy port |
| `helpers/doctor.sh <run-dir>` | listen/spawn alive, port owned by us, **serve line in log**, then HTTP 200 + title |
| `helpers/cleanup.sh <run-dir>` | SIGTERM the recorded process group; delete run-dir; do not touch evidence |

---

## Maintenance

When screens or labels drift, run `/maintain-verification-skill` rather than quietly editing this map to hide a product bug. Cadence: after home/gacha/battle/friend UI PRs, or when a live pass cannot find a string listed here.
