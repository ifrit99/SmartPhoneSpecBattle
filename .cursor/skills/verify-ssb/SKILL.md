---
name: verify-ssb
description: Drive SmartPhoneSpecBattle (SPEC BATTLE) Flutter web UI the way a user does — headless Playwright, mute-audio, real selectors from this repo. Use when proving a feature, checking a regression in the running game, or verifying a UI/flow change before merge. Not the Grok Bot pixel-diff merge gate.
---

# Verify SmartPhoneSpecBattle (SPEC BATTLE)

You are writing instructions for the next agent, not a human. Drive the **real Flutter web app**, the way a player does. Do not call widget tests, `BattleEngine` directly, or test-only setters and then claim the feature works.

This Cloud Agent environment **cannot** execute this skill (no headed/headless Playwright MCP here, and this generator is forbidden from launching Chrome/Playwright/GUI). Live proof happens on the operator's Mac after this skill lands. Follow Launch → Doctor → Drive → Evidence → Cleanup on that Mac.

## What this skill is / is not

- **This skill** is the feature-flow map: launch web, click like a user, capture screenshots + observable state.
- **Not this skill:** the Grok Bot merge gate that pixel-diffs the home screen against `master` before squash-merge. That visual check is a **separate gate and is still required before merge**. A green `verify-ssb` pass does not replace it.
- **Not this skill:** `flutter analyze` / `flutter test` (required by `CLAUDE.md` for code changes; they do not prove the running UI).
- **Never** pass Playwright, Chrome, or this skill's Drive section to a Cloud Agent. Cloud Agents must not launch a browser.

## Surface

| Surface | Role |
|---|---|
| **Flutter web UI** (`lib/main.dart` → `TitleScreen`) | **Primary. This is what you drive.** Same surface Mac Playwright already uses for merge checks. Production: `https://ifrit99.github.io/SmartPhoneSpecBattle/` (`web/index.html` og:url). Local: `flutter run -d web-server`. |
| Android (`android/`) / iOS (`ios/`) | Secondary native shells. Web-MVP is the shipped product (`docs/TODO.md`). Do **not** make `flutter run` on a device/emulator the drive path. Native Android currently needs a compileSdk/AGP bump (`url_launcher`) and is out of scope. |
| Docker `flutter-dev` | `analyze`/`test` isolation only (`README.md`). Compose maps `8080:8080` but the container `CMD` is `tail -f /dev/null` — it does **not** serve the game until someone execs `flutter run` inside it. Do not use Docker as the default drive path. |
| `scripts/serve-iphone.sh` | LAN/Tailscale Safari on **port 8090**. Human-on-phone helper, not the Playwright path. |

App id: Dart package `spec_battle_game`, window title `SPEC BATTLE`, theme scaffold `#0D1B2A`. State lives in `shared_preferences` (web: origin-scoped `localStorage`, keys such as `onboarding_completed`, `first_battle_completed`, `coins`, `sound.bgmMuted`). BGM is `audioplayers` (`assets/sounds/Crimson_Gauntlet.mp3`); SE on web is `document.createElement('audio')` (`lib/data/web_se_player_web.dart`).

## Mac operator notes (read before Launch)

1. **Do not use a Documents checkout.** A clone under `~/Documents` hangs on this machine. Use a throwaway clone under `~/orca/workspaces/` (example: `~/orca/workspaces/ssb-verify`).
2. **Do not collide with an in-progress graphics session.** That session may already own Flutter / port 8080 / a Chrome profile. Default verify ports are **8091** and **8092**, not 8080 or 8090.
3. **Never pass Playwright to Cloud Agents.** Run Drive only in the Mac Cursor session that has Playwright MCP.
4. Chromium **must** be headless with `--mute-audio`. Never headed Chrome: game BGM hits AirPods.
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
```

Equivalent raw command:

```bash
FLUTTER_BIN="$(command -v flutter || true)"
[ -x "$FLUTTER_BIN" ] || FLUTTER_BIN="$HOME/development/flutter/bin/flutter"
"$FLUTTER_BIN" run -d web-server \
  --web-hostname 127.0.0.1 \
  --web-port 8091
```

**Ready when** the log contains a serve URL, typically:

```text
lib/main.dart is being served at http://127.0.0.1:8091
```

or `Waiting for connection from debug service on http://127.0.0.1:8091`. Then `curl -fsS http://127.0.0.1:8091` returns HTML whose `<title>` is `SPEC BATTLE` (`web/index.html`).

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

1. `pid` file in `RUN_DIR` still refers to a live process (and that process is still a descendant of the `flutter run` we started — do not doctor a random listener).
2. `lsof`/`lsof -iTCP:<port> -sTCP:LISTEN` shows **that pid** (or its child dart/flutter) owns the port.
3. `GET http://127.0.0.1:<port>/` is HTTP 200 and the body contains `<title>SPEC BATTLE</title>`.
4. After Playwright connects: the document has a Flutter surface (`canvas`, `flt-glass-pane`, or `flutter-view`) **and** enabling accessibility (below) reveals `SPEC BATTLE` and `TAP TO START` (`test/presentation/title_screen_test.dart`).

Fail means: do not Drive. Re-Launch on a free port, or Cleanup the stranded run first. Do not attach to someone else's Flutter process.

---

## Drive

Harness: **Playwright against Flutter web**, via the Mac Playwright MCP (or `playwright` in that same Mac session).

### Browser flags (mandatory)

```text
headless: true
args: ["--mute-audio"]
```

- Viewport: `390x844` (this UI is a mobile-game column; desktop width makes home a long unusual layout).
- Fresh **browser context** per run (isolates `localStorage` / `shared_preferences`).
- No `--headed`, no `channel: "chrome"` that opens a window, no connecting to an existing Chrome profile.

### Flutter web selectors

The app paints with CanvasKit/skwasm. Visible pixels are on a canvas; **stable handles are the semantics tree + exact widget text from this repo**.

After `page.goto(http://127.0.0.1:<port>/)` and Flutter first-frame:

1. If `getByRole('button', { name: 'Enable accessibility' })` or `flt-semantics-placeholder` exists, click it once. Wait for `flt-semantics`.
2. Prefer `getByRole('button', { name: '<exact label>' })`. Material `ElevatedButton` / `OutlinedButton` / `TextButton` expose their child text.
3. For `GestureDetector` / `InkWell` chrome that is **not** a Material button, use `getByText('<exact string>')` after semantics are on, then click. Do not use coordinates except as a last resort on the title canvas.
4. There are almost **no** `ValueKey`s on primary CTAs. Exceptions (input-state only, not navigation): URL input `ValueKey('error'|'ready'|'empty')` in `lib/presentation/screens/qr_scan_screen.dart`; backup import `ValueKey(_hasImportInput)` in `data_backup_screen.dart`. Do not invent `data-testid`s.

### Boot path (every cold context)

Web title (`lib/presentation/screens/title_screen.dart`):

1. Wait until `getByText('SPEC BATTLE')` and `getByText('TAP TO START')` are in the tree. Subtitle `スマホのスペックで戦え` fades in ~0.8s after logo; tap prompt ~1.4s. `v0.1.0` is at the bottom.
2. **First tap anywhere on the view** (the body is one `GestureDetector`). This only runs `SoundService.unlockAudio()` + `playBgm()` and **stays on the title**. Chromium `--mute-audio` keeps AirPods quiet; the Dart gate still requires this tap.
3. **Second tap** leaves the title (`pushReplacement` fade 600ms).
4. If `analytics_consent` is unanswered, dialog `プレイデータ送信へのご協力` with buttons `協力しない` / `協力する` (`analytics_consent_dialog.dart`). For a feature proof that is not Privacy, click **`協力しない`**.
5. If `onboarding_completed` is false, `OnboardingScreen`: `スキップ` (always visible) or `次へ` ×2 then `はじめる！`. Fast path: **`スキップ`**. Pages: `あなたのスマホが\nキャラクターに！` → `スペックが\n能力値に変わる` → `まずは1回\nバトルしてみよう！`.
6. Home (`HomeScreen`). First-run also shows `はじめてのバトル！` banner. Login popup `ログインボーナス！` / button `受け取る` may appear; dismiss with `受け取る` before asserting home chrome.

You are on home when several of these are visible (home is a long `SingleChildScrollView` — scroll):

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

Two instances **are** possible: different `--web-port` values (8091 vs 8092) are different origins, so `localStorage` / `shared_preferences` do not collide. Use two Playwright browser contexts as well.

**Refuse to double-drive a shared instance.** If 8091 is already serving a Flutter app you did not start (doctor pid mismatch, or a graphics session), do not `page.goto` it. Launch on 8092 or stop.

Do not open two Playwright pages against the same origin: home `shared_preferences` (coins, onboarding flags, equipped gacha id) is process-global per origin.

---

## Evidence

Root: `.local/verify-ssb/evidence/<run-id>/` (created at Launch). Cleanup must not delete this directory.

Proof standards:

1. Exercise the **real user path** (title taps → home → feature). Do not seed `SharedPreferences` from a snippet and jump to a screen via a test harness.
2. Capture **the action and the resulting state**, not one final frame. Minimum per feature: screenshot before the click, screenshot after, plus one observable (text, AppBar, snackbar, currency digit, log line, `localStorage` key).
3. Side effects for this app are **origin `localStorage`** (Flutter `shared_preferences`). After a CPU win you should see `battle_count` / `win_count` / `coins` change if you read storage; after onboarding skip, `onboarding_completed` is true. Reading storage is supporting evidence, not a substitute for the UI.
4. Do not mock `BattleEngine`, gacha RNG, or network. There is no game backend. `?battle=` is the character payload. Sentry/Firebase are no-op without dart-defines; ignore them.
5. Audio is **not** evidence (muted). Mute toggles `BGM` / `SE` on the battle overlay are optional chrome, not a pass criterion unless the bug is mute.

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

- Kills **only** the pid recorded at Launch (process group of that `flutter run`). Never `pkill flutter` / `killall dart`.
- Removes `$RUN_DIR` (pid/port/log).
- **Leaves** `.local/verify-ssb/evidence/<run-id>/` in place.
- Closes the Playwright browser/context this run opened. Do not close other browsers.

After cleanup, confirm evidence files still exist (`ls "$EVIDENCE_DIR"`). A cleanup that ate the proof failed.

---

## Helpers

All under `.cursor/skills/verify-ssb/helpers/`. Executable. Invocation is in Launch / Doctor / Cleanup.

| Script | Purpose |
|---|---|
| `helpers/launch-web.sh <port> <run-dir>` | `flutter run -d web-server` on `127.0.0.1:<port>`; writes `pid`, `port`, `flutter.log`; refuses a busy port |
| `helpers/doctor.sh <run-dir>` | pid live, port owned by us, HTTP 200 + title `SPEC BATTLE` |
| `helpers/cleanup.sh <run-dir>` | SIGTERM the recorded pid group; delete run-dir; do not touch evidence |

---

## Maintenance

When screens or labels drift, run `/maintain-verification-skill` rather than quietly editing this map to hide a product bug. Cadence: after home/gacha/battle/friend UI PRs, or when a live pass cannot find a string listed here.
