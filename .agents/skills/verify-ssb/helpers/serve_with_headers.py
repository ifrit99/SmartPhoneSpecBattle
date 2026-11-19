#!/usr/bin/env python3
"""Serve a Flutter web build with Cloudflare-style web/_headers on 127.0.0.1."""

from __future__ import annotations

import argparse
import mimetypes
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Iterable


def parse_headers_file(path: Path) -> list[tuple[str, str]]:
    """Return header pairs for the `/*` Cloudflare Pages block."""
    lines = path.read_text(encoding="utf-8").splitlines()
    headers: list[tuple[str, str]] = []
    in_star = False
    for raw in lines:
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        if not raw.startswith((" ", "\t")):
            in_star = raw.strip() == "/*"
            continue
        if not in_star:
            continue
        stripped = raw.strip()
        if ":" not in stripped:
            continue
        name, value = stripped.split(":", 1)
        headers.append((name.strip(), value.strip()))
    if not headers:
        raise SystemExit(f"no /* headers found in {path}")
    return headers


def extra_mimetypes() -> None:
    mimetypes.add_type("application/javascript", ".js")
    mimetypes.add_type("application/javascript", ".mjs")
    mimetypes.add_type("application/wasm", ".wasm")
    mimetypes.add_type("application/json", ".json")
    mimetypes.add_type("application/json", ".map")
    mimetypes.add_type("font/ttf", ".ttf")
    mimetypes.add_type("font/otf", ".otf")
    mimetypes.add_type("font/woff2", ".woff2")


def make_handler(root: Path, extra: list[tuple[str, str]]):
    class HeaderHandler(SimpleHTTPRequestHandler):
        extra_headers = extra

        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=str(root), **kwargs)

        def end_headers(self) -> None:
            for name, value in self.extra_headers:
                self.send_header(name, value)
            super().end_headers()

        def log_message(self, fmt: str, *args: object) -> None:
            sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    return HeaderHandler


def serve(
    root: Path,
    headers_file: Path,
    bind: str,
    port: int,
    port_file: Path | None,
) -> None:
    extra_mimetypes()
    extra = parse_headers_file(headers_file)
    server = ThreadingHTTPServer((bind, port), make_handler(root, extra))
    bound_port = server.server_address[1]
    sys.stdout.write(f"VERIFY_SSB_PORT={bound_port}\n")
    sys.stdout.flush()
    if port_file is not None:
        port_file.parent.mkdir(parents=True, exist_ok=True)
        port_file.write_text(str(bound_port), encoding="utf-8")
    try:
        server.serve_forever()
    finally:
        server.server_close()


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--headers", required=True, type=Path)
    parser.add_argument("--bind", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=0)
    parser.add_argument("--port-file", type=Path, default=None)
    args = parser.parse_args(list(argv) if argv is not None else None)
    if not args.root.is_dir():
        raise SystemExit(f"root is not a directory: {args.root}")
    if not args.headers.is_file():
        raise SystemExit(f"headers file missing: {args.headers}")
    serve(args.root, args.headers, args.bind, args.port, args.port_file)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
