#!/usr/bin/env python3
"""assets/sample.html の <style> を assets/template.html から同期する。

CSS の正本は template.html の <style> ただ 1 箇所である。見本ページ
（sample.html）はブラウザで直接開けるよう CSS を内包する必要があるため、
両者に同じ CSS が存在する。手で二重管理せず、このスクリプトで同期する。

    python build_sample.py            # template.html の CSS を sample.html へ反映
    python build_sample.py --check    # 一致していれば 0、ずれていれば 1 を返す
    python build_sample.py --body F   # 本文断片 F から sample.html を新規生成

sample.html の <body> 側（見本の内容）はこのファイルではなく sample.html
自身が正本であり、--body を指定しない限り上書きされない。
"""
import argparse
import re
import sys
from pathlib import Path

# Windows の既定コンソールは cp932。日本語の診断メッセージで落ちないよう固定する。
for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

ASSETS = Path(__file__).resolve().parent.parent / "assets"
TEMPLATE = ASSETS / "template.html"
SAMPLE = ASSETS / "sample.html"
STYLE_RE = re.compile(r"<style>.*?</style>", re.S)

SKELETON = """<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>explainer-html コンポーネント見本</title>
{style}
</head>
<body>
{body}
</body>
</html>
"""


def read(path):
    if not path.is_file():
        sys.exit(f"ファイルが見つからない: {path}")
    return path.read_text(encoding="utf-8")


def extract_style(text, src):
    m = STYLE_RE.search(text)
    if not m:
        sys.exit(f"<style> ブロックが見つからない: {src}")
    return m.group(0)


def main():
    ap = argparse.ArgumentParser(description="sample.html の CSS を template.html と同期する")
    ap.add_argument("--check", action="store_true", help="同期せず一致だけを検査する")
    ap.add_argument("--body", help="本文断片のパス（sample.html を新規生成する場合）")
    args = ap.parse_args()

    style = extract_style(read(TEMPLATE), TEMPLATE)

    if args.body:
        body = read(Path(args.body)).strip()
        SAMPLE.write_text(SKELETON.format(style=style, body=body), encoding="utf-8", newline="\n")
        print(f"生成: {SAMPLE}（{SAMPLE.stat().st_size} バイト）")
        return 0

    sample = read(SAMPLE)
    current = extract_style(sample, SAMPLE)

    if current == style:
        print("一致: sample.html の CSS は template.html と同一")
        return 0

    if args.check:
        print("不一致: sample.html の CSS が template.html とずれている", file=sys.stderr)
        print("  -> python build_sample.py を実行して同期する", file=sys.stderr)
        return 1

    SAMPLE.write_text(STYLE_RE.sub(lambda _: style, sample, count=1), encoding="utf-8", newline="\n")
    print(f"同期: {SAMPLE} の CSS を template.html に合わせた")
    return 0


if __name__ == "__main__":
    sys.exit(main())
