#!/usr/bin/env python3
"""Drive SPEC BATTLE boot-title through Chrome DevTools Protocol over a pipe."""

from __future__ import annotations

import argparse
import base64
import json
import os
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any
from urllib.parse import urlparse


FIREBASE_URL_MARKERS = (
    "identitytoolkit.googleapis.com",
    "securetoken.googleapis.com",
    "firestore.googleapis.com",
    "www.gstatic.com/firebasejs/",
    "firebase_js_preload.js",
)
FONT_HOSTS = ("fonts.gstatic.com", "fonts.googleapis.com")
UX_TIMING_MARK = "[UxTiming] cold_to_title"
TITLE_TEXTS = ("SPEC BATTLE", "TAP TO START")

HOST_RESOLVER_RULES = (
    "MAP identitytoolkit.googleapis.com ~NOTFOUND,"
    "MAP securetoken.googleapis.com ~NOTFOUND,"
    "MAP firestore.googleapis.com ~NOTFOUND"
)


class CdpError(RuntimeError):
    pass


class PipeCdp:
    """Chrome --remote-debugging-pipe client (NUL-delimited JSON)."""

    def __init__(self, cmd_fd: int, event_fd: int) -> None:
        self._cmd_fd = cmd_fd
        self._event_fd = event_fd
        self._buf = b""
        self._next_id = 0
        self._pending: dict[int, dict[str, Any] | None] = {}
        self._event_cursor = 0
        self.events: list[dict[str, Any]] = []

    def send(
        self,
        method: str,
        params: dict[str, Any] | None = None,
        session_id: str | None = None,
        timeout: float = 15.0,
    ) -> Any:
        self._next_id += 1
        msg_id = self._next_id
        payload: dict[str, Any] = {"id": msg_id, "method": method}
        if params:
            payload["params"] = params
        if session_id:
            payload["sessionId"] = session_id
        raw = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        os.write(self._cmd_fd, raw + b"\x00")
        self._pending[msg_id] = None
        deadline = time.monotonic() + timeout
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise CdpError(f"timeout waiting for {method} #{msg_id}")
            self._pump(remaining)
            if self._pending.get(msg_id) is not None:
                result = self._pending.pop(msg_id)
                assert result is not None
                if "error" in result:
                    raise CdpError(f"{method} failed: {result['error']}")
                return result.get("result")

    def wait_event(
        self,
        matcher,
        timeout: float,
    ) -> dict[str, Any] | None:
        deadline = time.monotonic() + timeout
        while True:
            while self._event_cursor < len(self.events):
                event = self.events[self._event_cursor]
                self._event_cursor += 1
                if matcher(event):
                    return event
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                return None
            self._pump(remaining)

    def pump_until(self, timeout: float) -> None:
        deadline = time.monotonic() + timeout
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                return
            self._pump(remaining)

    def _pump(self, timeout: float) -> None:
        ready, _, _ = select.select([self._event_fd], [], [], max(timeout, 0.0))
        if not ready:
            return
        chunk = os.read(self._event_fd, 65536)
        if not chunk:
            raise CdpError("chrome closed the CDP pipe")
        self._buf += chunk
        while True:
            msg = self._pop_message()
            if msg is None:
                return
            if "id" in msg and msg["id"] in self._pending:
                self._pending[msg["id"]] = msg
            elif "method" in msg:
                msg["_received_at"] = time.monotonic()
                self.events.append(msg)

    def _pop_message(self) -> dict[str, Any] | None:
        while True:
            nul = self._buf.find(b"\x00")
            if nul < 0:
                return None
            body = self._buf[:nul]
            self._buf = self._buf[nul + 1 :]
            if body:
                return json.loads(body.decode("utf-8"))


def find_chrome() -> str:
    env = os.environ.get("CHROME_EXECUTABLE")
    if env:
        if not os.path.isfile(env) or not os.access(env, os.X_OK):
            raise SystemExit("CHROME_EXECUTABLE is not an executable file")
        return env
    for name in (
        "google-chrome",
        "google-chrome-stable",
        "chromium-browser",
        "chromium",
    ):
        path = shutil.which(name)
        if path:
            return path
    raise SystemExit("chrome not found (google-chrome or CHROME_EXECUTABLE)")


def start_chrome(chrome: str, profile_dir: Path, url: str) -> tuple[subprocess.Popen, PipeCdp]:
    cmd_r, cmd_w = os.pipe()
    evt_r, evt_w = os.pipe()
    os.set_inheritable(cmd_r, True)
    os.set_inheritable(evt_w, True)

    def preexec() -> None:
        # close_fds=True would close the remapped 3/4 after this runs.
        os.dup2(cmd_r, 3)
        os.dup2(evt_w, 4)
        for fd in (cmd_r, evt_w, cmd_w, evt_r):
            if fd not in (0, 1, 2, 3, 4):
                try:
                    os.close(fd)
                except OSError:
                    pass

    args = [
        chrome,
        "--headless=new",
        "--mute-audio",
        "--remote-debugging-pipe",
        f"--user-data-dir={profile_dir}",
        "--window-size=390,844",
        f"--host-resolver-rules={HOST_RESOLVER_RULES}",
        "--no-first-run",
        "--no-default-browser-check",
        "--disable-extensions",
        "--disable-sync",
        "--disable-background-networking",
        "--disable-component-update",
        "--disable-features=Translate,AcceptCHFrame,MediaRouter,OptimizationHints",
        "--no-sandbox",
        "--disable-dev-shm-usage",
        "--disable-gpu",
        "about:blank",
    ]
    proc = subprocess.Popen(
        args,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        preexec_fn=preexec,
        close_fds=False,
    )
    os.close(cmd_r)
    os.close(evt_w)
    cdp = PipeCdp(cmd_w, evt_r)
    # Touch `url` so callers can log the intended page even before navigate.
    _ = url
    return proc, cdp


def console_text(event: dict[str, Any]) -> str:
    params = event.get("params") or {}
    if event.get("method") == "Runtime.consoleAPICalled":
        parts: list[str] = []
        for arg in params.get("args") or []:
            if "value" in arg:
                parts.append(str(arg["value"]))
            elif "description" in arg:
                parts.append(str(arg["description"]))
            elif "unserializableValue" in arg:
                parts.append(str(arg["unserializableValue"]))
        return " ".join(parts)
    if event.get("method") == "Log.entryAdded":
        entry = params.get("entry") or {}
        return str(entry.get("text") or "")
    if event.get("method") == "Runtime.exceptionThrown":
        details = params.get("exceptionDetails") or {}
        exc = details.get("exception") or {}
        return str(
            details.get("text")
            or exc.get("description")
            or exc.get("value")
            or ""
        )
    return ""


def console_level(event: dict[str, Any]) -> str:
    params = event.get("params") or {}
    method = event.get("method")
    if method == "Runtime.consoleAPICalled":
        return str(params.get("type") or "log")
    if method == "Log.entryAdded":
        return str((params.get("entry") or {}).get("level") or "info")
    if method == "Runtime.exceptionThrown":
        return "error"
    return "log"


def request_url(event: dict[str, Any]) -> str:
    params = event.get("params") or {}
    method = event.get("method")
    if method == "Network.requestWillBeSent":
        return str((params.get("request") or {}).get("url") or "")
    if method in ("Network.responseReceived", "Network.loadingFailed"):
        return str(params.get("url") or (params.get("request") or {}).get("url") or "")
    return ""


def is_font_url(url: str) -> bool:
    host = urlparse(url).hostname or ""
    return any(host == h or host.endswith("." + h) for h in FONT_HOSTS)


def firebase_marker(url: str) -> str | None:
    for marker in FIREBASE_URL_MARKERS:
        if marker in url:
            return marker
    return None


def origin_of(url: str) -> tuple[str, int | None]:
    parsed = urlparse(url)
    return parsed.hostname or "", parsed.port


def enable_page_session(cdp: PipeCdp, timeout: float) -> str:
    targets = cdp.send("Target.getTargets", timeout=timeout) or {}
    target_id = None
    for info in targets.get("targetInfos") or []:
        if info.get("type") == "page":
            target_id = info.get("targetId")
            break
    if not target_id:
        created = cdp.send(
            "Target.createTarget",
            {"url": "about:blank"},
            timeout=timeout,
        ) or {}
        target_id = created.get("targetId")
    if not target_id:
        raise CdpError("no page target")
    attached = cdp.send(
        "Target.attachToTarget",
        {"targetId": target_id, "flatten": True},
        timeout=timeout,
    ) or {}
    session_id = attached.get("sessionId")
    if not session_id:
        raise CdpError("attachToTarget returned no sessionId")
    return str(session_id)


def js_string(result: Any) -> str:
    if not isinstance(result, dict):
        return ""
    inner = result.get("result") or result
    if isinstance(inner, dict) and "value" in inner:
        return str(inner.get("value") or "")
    return str(inner.get("value") or "") if isinstance(inner, dict) else str(result or "")


def evaluate(cdp: PipeCdp, session_id: str, expression: str, timeout: float) -> Any:
    return cdp.send(
        "Runtime.evaluate",
        {
            "expression": expression,
            "returnByValue": True,
            "awaitPromise": True,
        },
        session_id=session_id,
        timeout=timeout,
    )


def collect_semantics_texts(cdp: PipeCdp, session_id: str, timeout: float) -> tuple[str, list[str]]:
    clicked = evaluate(
        cdp,
        session_id,
        """
(() => {
  const ph = document.querySelector('flt-semantics-placeholder');
  if (ph) { ph.click(); return 'placeholder'; }
  const btn = document.querySelector('[aria-label="Enable accessibility"]');
  if (btn) { btn.click(); return 'aria-button'; }
  return 'missing';
})()
""",
        timeout=timeout,
    )
    how = js_string(clicked)
    time.sleep(0.6)
    result = evaluate(
        cdp,
        session_id,
        """
(() => {
  const out = [];
  const seen = new Set();
  const add = (s) => {
    const t = (s || '').replace(/\\s+/g, ' ').trim();
    if (!t || seen.has(t)) return;
    seen.add(t);
    out.push(t);
  };
  for (const el of document.querySelectorAll('*')) {
    add(el.getAttribute && el.getAttribute('aria-label'));
    add(el.getAttribute && el.getAttribute('aria-valuetext'));
    if (el.tagName && el.tagName.toLowerCase().startsWith('flt-')) {
      add(el.textContent);
    }
  }
  return out;
})()
""",
        timeout=timeout,
    )
    value = result.get("result") if isinstance(result, dict) else None
    texts = []
    if isinstance(value, dict) and isinstance(value.get("value"), list):
        texts = [str(x) for x in value["value"]]
    return how, texts


def first_failure(
    events: list[dict[str, Any]],
    page_host: str,
    page_port: int | None,
    signal_at: float | None,
) -> tuple[str, str] | None:
    request_ids: dict[str, str] = {}
    for event in events:
        method = event.get("method")
        received_at = event.get("_received_at")
        text = console_text(event)
        level = console_level(event)

        if method == "Network.requestWillBeSent":
            params = event.get("params") or {}
            req_id = str(params.get("requestId") or "")
            url = request_url(event)
            if req_id:
                request_ids[req_id] = url
            marker = firebase_marker(url)
            if marker and (signal_at is None or (received_at or 0) <= signal_at):
                return ("起動時の Firebase", f"{marker} {url}")

        if method == "Network.responseReceived":
            params = event.get("params") or {}
            url = str((params.get("response") or {}).get("url") or request_ids.get(str(params.get("requestId") or ""), ""))
            status = int((params.get("response") or {}).get("status") or 0)
            host, port = origin_of(url)
            if (
                host == page_host
                and (page_port is None or port in (page_port, None))
                and status >= 400
            ):
                return ("同じオリジンの読み込み", f"HTTP {status} {url}")

        if method == "Network.loadingFailed":
            params = event.get("params") or {}
            url = request_ids.get(str(params.get("requestId") or ""), "")
            if not url:
                url = str(params.get("errorText") or "")
            if is_font_url(url):
                continue
            marker = firebase_marker(url)
            if marker and (signal_at is None or (received_at or 0) <= signal_at):
                return ("起動時の Firebase", f"{marker} {url}")
            host, port = origin_of(url)
            if host == page_host and (page_port is None or port in (page_port, None)):
                err = params.get("errorText") or params.get("blockedReason") or "loadingFailed"
                return ("同じオリジンの読み込み", f"{err} {url}")

        if method == "Runtime.exceptionThrown":
            return ("例外", text or "Runtime.exceptionThrown")

        lowered = text.lower()
        if "content security policy" in text or "content security policy" in lowered or "refused to" in lowered:
            return ("CSP", text)
        if "securitypolicyviolation" in lowered:
            return ("CSP", text)
        if level == "error" and (
            "uncaught" in lowered
            or "exception caught by" in lowered
            or "bad state:" in lowered
            or "stateerror" in lowered
        ):
            return ("例外", text)
        if level == "error" and text.strip():
            return ("それ以外の error レベル", text)
    return None


def drive(url: str, evidence_dir: Path, timeout: float, pid_file: Path | None) -> int:
    chrome = find_chrome()
    evidence_dir.mkdir(parents=True, exist_ok=True)
    profile_dir = Path(tempfile.mkdtemp(prefix="verify-ssb-chrome-"))
    proc: subprocess.Popen | None = None
    cdp: PipeCdp | None = None
    session_id: str | None = None
    chrome_err = ""
    verdict = "FAIL"
    rule = "制限時間内に cold_to_title が出ない"
    first_hit = ""
    signal_at: float | None = None
    ux_line = ""
    semantics_how = "not-run"
    semantics_texts: list[str] = []
    semantics_ok: dict[str, bool] | None = None
    screenshot_path = evidence_dir / "title.png"
    screenshot_error = ""
    notes: list[str] = []
    started = time.monotonic()

    try:
        proc, cdp = start_chrome(chrome, profile_dir, url)
        if pid_file is not None:
            pid_file.write_text(str(proc.pid), encoding="utf-8")
        # Give Chrome a moment to accept pipe messages.
        time.sleep(0.2)
        session_id = enable_page_session(cdp, timeout=15)
        for domain in ("Runtime", "Log", "Network", "Page"):
            cdp.send(f"{domain}.enable", session_id=session_id, timeout=10)
        cdp.send(
            "Emulation.setDeviceMetricsOverride",
            {
                "width": 390,
                "height": 844,
                "deviceScaleFactor": 1,
                "mobile": True,
            },
            session_id=session_id,
            timeout=10,
        )
        cdp.send(
            "Page.addScriptToEvaluateOnNewDocument",
            {
                "source": """
window.addEventListener('securitypolicyviolation', (e) => {
  console.error('Content Security Policy', e.effectiveDirective, e.blockedURI);
});
"""
            },
            session_id=session_id,
            timeout=10,
        )
        cdp.send("Page.navigate", {"url": url}, session_id=session_id, timeout=15)

        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            remaining = deadline - time.monotonic()
            event = cdp.wait_event(lambda ev: True, timeout=min(1.0, remaining))
            if event is None:
                continue
            text = console_text(event)
            if UX_TIMING_MARK in text and signal_at is None:
                signal_at = event.get("_received_at")
                ux_line = text
                break
        if signal_at is not None:
            # TAP TO START は cold_to_title の約 1.4s 後に点滅を始める。
            cdp.pump_until(1.6)
        else:
            cdp.pump_until(0.2)
        if session_id is not None:
            try:
                semantics_how, semantics_texts = collect_semantics_texts(
                    cdp, session_id, timeout=10
                )
            except CdpError as exc:
                semantics_how = f"error:{exc}"
                semantics_texts = []
            joined = "\n".join(semantics_texts)
            semantics_ok = {
                "SPEC BATTLE": "SPEC BATTLE" in joined,
                "TAP TO START": "TAP TO START" in joined,
            }
            try:
                shot = cdp.send(
                    "Page.captureScreenshot",
                    {"format": "png"},
                    session_id=session_id,
                    timeout=15,
                ) or {}
                png = shot.get("data")
                if not png:
                    screenshot_error = "empty screenshot data"
                else:
                    raw = base64.b64decode(png)
                    if len(raw) < 32 or not raw.startswith(b"\x89PNG"):
                        screenshot_error = "screenshot is not a PNG"
                    else:
                        screenshot_path.write_bytes(raw)
            except CdpError as exc:
                screenshot_error = str(exc)
        cdp.pump_until(0.2)
        page_host, page_port = origin_of(url)
        fail = first_failure(
            cdp.events,
            page_host,
            page_port,
            signal_at,
        )
        if fail is not None:
            verdict = "FAIL"
            rule, first_hit = fail
        elif signal_at is None:
            verdict = "FAIL"
            rule = "制限時間内に cold_to_title が出ない"
            first_hit = rule
        elif not screenshot_path.is_file() or screenshot_path.stat().st_size < 32:
            verdict = "FAIL"
            rule = "スクリーンショットが無い"
            first_hit = screenshot_error or "title.png missing"
        else:
            verdict = "PASS"
            rule = ""
            first_hit = ""
            if semantics_ok is not None:
                missed = [name for name, ok in semantics_ok.items() if not ok]
                if missed:
                    notes.append("semantics missed: " + ", ".join(missed))
            elif semantics_how != "placeholder" and semantics_how != "aria-button":
                notes.append(f"semantics not confirmed ({semantics_how})")
    except SystemExit:
        raise
    except Exception as exc:  # noqa: BLE001 — harness must turn crashes into FAIL
        verdict = "FAIL"
        rule = "例外"
        first_hit = str(exc)
    finally:
        if proc is not None:
            try:
                proc.send_signal(signal.SIGTERM)
                proc.wait(timeout=5)
            except Exception:
                proc.kill()
            if proc.stderr is not None:
                try:
                    chrome_err = proc.stderr.read().decode("utf-8", "replace")
                except Exception:
                    chrome_err = ""
        shutil.rmtree(profile_dir, ignore_errors=True)
        if chrome_err:
            (evidence_dir / "chrome.stderr.txt").write_text(chrome_err, encoding="utf-8")

    events_out = []
    if cdp is not None:
        for event in cdp.events:
            events_out.append(
                {
                    "method": event.get("method"),
                    "level": console_level(event),
                    "text": console_text(event),
                    "url": request_url(event),
                    "params": _jsonable(event.get("params")),
                }
            )

    elapsed_ms = int((time.monotonic() - started) * 1000)
    judgment = "PASS" if verdict == "PASS" else f"FAIL: {rule} ({first_hit})"
    if notes and verdict == "PASS":
        judgment = judgment + "; " + "; ".join(notes)
    payload = {
        "url": url,
        "verdict": verdict,
        "rule": rule or None,
        "first_hit": first_hit or None,
        "ux_timing": ux_line or None,
        "signal_at_ms": None if signal_at is None else int((signal_at - started) * 1000),
        "elapsed_ms": elapsed_ms,
        "semantics": {
            "how": semantics_how,
            "found": semantics_ok,
            "texts": semantics_texts,
        },
        "events": events_out,
    }
    (evidence_dir / "events.json").write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    (evidence_dir / "judgment.txt").write_text(judgment + "\n", encoding="utf-8")
    sys.stdout.write(judgment + "\n")
    sys.stdout.flush()
    return 0 if verdict == "PASS" else 1


def _jsonable(value: Any) -> Any:
    try:
        json.dumps(value)
        return value
    except TypeError:
        return str(value)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", required=True)
    parser.add_argument("--evidence", required=True, type=Path)
    parser.add_argument("--timeout", type=float, default=float(os.environ.get("VERIFY_TIMEOUT", "60")))
    parser.add_argument("--pid-file", type=Path, default=None)
    args = parser.parse_args(argv)
    try:
        return drive(args.url, args.evidence, args.timeout, args.pid_file)
    except SystemExit as exc:
        code = exc.code if isinstance(exc.code, int) else 2
        if code == 2 or "not found" in str(exc) or "CHROME_EXECUTABLE" in str(exc):
            sys.stderr.write(f"env: {exc}\n")
            return 2
        raise


if __name__ == "__main__":
    raise SystemExit(main())
