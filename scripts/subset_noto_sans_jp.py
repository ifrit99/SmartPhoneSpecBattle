#!/usr/bin/env python3
"""アプリ内で使う日本語 + ASCII グリフだけに Noto Sans JP をサブセットする。

元フォント（Google Fonts の NotoSansJP-Regular.ttf 全量）を渡し、
`assets/fonts/NotoSansJP-Regular.ttf` を上書きする。
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "assets" / "fonts" / "NotoSansJP-Regular.ttf"


def collect_unicodes() -> list[int]:
    """lib 配下の実コピー + 日本語UIに必要な固定レンジを集める。"""
    chars: set[str] = set()
    # ASCII 印字可能
    chars.update(chr(i) for i in range(0x20, 0x7F))
    # ひらがな・カタカナ（小書き・長音含む）
    chars.update(chr(i) for i in range(0x3040, 0x30FF + 1))
    # CJK 記号・句読点
    chars.update(chr(i) for i in range(0x3000, 0x303F + 1))
    # 全角英数・半角カナ
    chars.update(chr(i) for i in range(0xFF01, 0xFF9F + 1))
    # 一般句読点（ダッシュ・引用符など）
    chars.update(chr(i) for i in range(0x2010, 0x2027 + 1))
    chars.update("…→←↑↓×÷±・／〜～※▲▼▶◀")

    for path in (ROOT / "lib").rglob("*.dart"):
        for ch in path.read_text(encoding="utf-8"):
            if ord(ch) >= 0x20:
                chars.add(ch)

    return sorted({ord(ch) for ch in chars})


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="全量 NotoSansJP-Regular.ttf")
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help="書き出し先（既定: assets/fonts/NotoSansJP-Regular.ttf）",
    )
    args = parser.parse_args()
    if not args.source.is_file():
        print(f"source not found: {args.source}", file=sys.stderr)
        return 1

    unicodes = collect_unicodes()
    pyftsubset = Path.home() / ".local" / "bin" / "pyftsubset"
    command = "pyftsubset" if not pyftsubset.is_file() else str(pyftsubset)

    with tempfile.TemporaryDirectory() as tmp:
        uni_path = Path(tmp) / "unicodes.txt"
        uni_path.write_text(
            ",".join(f"U+{code:04X}" for code in unicodes) + "\n",
            encoding="utf-8",
        )
        dest = Path(tmp) / "subset.ttf"
        subprocess.run(
            [
                command,
                str(args.source),
                f"--unicodes-file={uni_path}",
                f"--output-file={dest}",
                "--ignore-missing-unicodes",
                "--no-hinting",
                "--recommended-glyphs",
                "--legacy-cmap",
                "--layout-features=*",
                "--name-IDs=*",
                "--recalc-bounds",
            ],
            check=True,
        )
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_bytes(dest.read_bytes())

    src_kb = args.source.stat().st_size / 1024
    out_kb = args.output.stat().st_size / 1024
    print(
        f"subset {args.output}  unicodes={len(unicodes)}  "
        f"{src_kb:.0f}KB -> {out_kb:.0f}KB"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
