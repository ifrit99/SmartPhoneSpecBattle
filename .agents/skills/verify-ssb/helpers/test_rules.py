#!/usr/bin/env python3
"""Unit tests for verify-ssb judgment rules (no Chrome)."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from cdp_drive import first_failure
from serve_with_headers import parse_headers_file


def _console(text: str, level: str = "error") -> dict:
    return {
        "method": "Runtime.consoleAPICalled",
        "params": {"type": level, "args": [{"value": text}]},
    }


def _request(url: str, request_id: str, received_at: float) -> dict:
    return {
        "method": "Network.requestWillBeSent",
        "_received_at": received_at,
        "params": {"requestId": request_id, "request": {"url": url}},
    }


class FirstFailureTest(unittest.TestCase):
    def test_csp_console(self) -> None:
        events = [_console("Refused to load the script because of Content Security Policy")]
        self.assertEqual(first_failure(events, "127.0.0.1", 9, 1.0)[0], "CSP")

    def test_exception_thrown(self) -> None:
        events = [
            {
                "method": "Runtime.exceptionThrown",
                "params": {"exceptionDetails": {"text": "Uncaught"}},
            }
        ]
        self.assertEqual(first_failure(events, "127.0.0.1", 9, 1.0)[0], "例外")

    def test_firebase_before_title(self) -> None:
        events = [
            _request("https://www.gstatic.com/firebasejs/12.18.0/firebase-app.js", "a", 0.5)
        ]
        rule, hit = first_failure(events, "127.0.0.1", 9, 1.0)
        self.assertEqual(rule, "起動時の Firebase")
        self.assertIn("www.gstatic.com/firebasejs/", hit)

    def test_firebase_after_title_ignored(self) -> None:
        events = [
            _request("https://identitytoolkit.googleapis.com/v1", "b", 2.0)
        ]
        self.assertIsNone(first_failure(events, "127.0.0.1", 9, 1.0))

    def test_same_origin_http_400(self) -> None:
        events = [
            {
                "method": "Network.responseReceived",
                "params": {
                    "requestId": "c",
                    "response": {"url": "http://127.0.0.1:9/missing.js", "status": 404},
                },
            }
        ]
        rule, hit = first_failure(events, "127.0.0.1", 9, 1.0)
        self.assertEqual(rule, "同じオリジンの読み込み")
        self.assertIn("404", hit)

    def test_same_origin_loading_failed(self) -> None:
        events = [
            _request("http://127.0.0.1:9/main.dart.js", "d", 0.2),
            {
                "method": "Network.loadingFailed",
                "params": {"requestId": "d", "errorText": "net::ERR_ABORTED"},
            },
        ]
        self.assertEqual(first_failure(events, "127.0.0.1", 9, 1.0)[0], "同じオリジンの読み込み")

    def test_font_loading_failed_ignored(self) -> None:
        events = [
            _request("https://fonts.gstatic.com/s/x.woff2", "e", 0.2),
            {
                "method": "Network.loadingFailed",
                "params": {"requestId": "e", "errorText": "net::ERR_NAME_NOT_RESOLVED"},
            },
        ]
        self.assertIsNone(first_failure(events, "127.0.0.1", 9, 1.0))

    def test_other_error_level(self) -> None:
        events = [_console("unexpected boom", "error")]
        self.assertEqual(first_failure(events, "127.0.0.1", 9, 1.0)[0], "それ以外の error レベル")

    def test_warning_ignored(self) -> None:
        events = [_console("Automatic fallback to software WebGL", "warning")]
        self.assertIsNone(first_failure(events, "127.0.0.1", 9, 1.0))


class ParseHeadersFileTest(unittest.TestCase):
    def test_reads_star_block_only(self) -> None:
        text = """# comment
/other
  X-Other: no
/*
  Content-Security-Policy: default-src 'self'
  X-Frame-Options: DENY
/assets/*
  Cache-Control: public
"""
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "_headers"
            path.write_text(text, encoding="utf-8")
            headers = parse_headers_file(path)
        self.assertEqual(
            headers,
            [
                ("Content-Security-Policy", "default-src 'self'"),
                ("X-Frame-Options", "DENY"),
            ],
        )

    def test_missing_star_block_exits(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "_headers"
            path.write_text("/only\n  X-A: 1\n", encoding="utf-8")
            with self.assertRaises(SystemExit):
                parse_headers_file(path)


if __name__ == "__main__":
    unittest.main()
