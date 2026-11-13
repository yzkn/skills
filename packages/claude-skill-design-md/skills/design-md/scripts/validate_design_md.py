#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""DESIGN.md の構造を検証する（Python 標準ライブラリのみ）。

検証するのは構造だけである。front matter のキー・本文セクションの名前と順序・
必須値の有無を見る。色の妥当性・コントラスト比・トークンの実装との一致は検証しない。

仕様の出典は .claude/skills/design-md/references/spec-summary.md を参照。

使い方:
    python .claude/skills/design-md/scripts/validate_design_md.py <path> [--json]

終了コード:
    0 = ERROR なし（WARN・INFO は出ることがある）
    1 = ERROR あり
    2 = ファイルを読めない等の実行時エラー
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

# 仕様の front matter トップレベルキー（spec-summary.md 「2. YAML front matter」）
KNOWN_KEYS = {
    "version", "name", "description", "omitted",
    "colors", "typography", "rounded", "spacing", "components",
}
REQUIRED_KEYS = {"name"}

# 仕様の本文セクション（正式名 -> 順序）と別称
CANONICAL_SECTIONS = [
    "Overview", "Colors", "Typography", "Layout",
    "Elevation & Depth", "Shapes", "Components", "Do's and Don'ts",
]
ALIASES = {
    "brand & style": "Overview",
    "layout & spacing": "Layout",
    "elevation": "Elevation & Depth",
}
# 本リポジトリで追加を認めるセクション（design-dna の出所記録など）
REPO_EXTRA_SECTIONS = {"provenance", "notes"}

FENCE = re.compile(r"^\s*(```|~~~)")
H2 = re.compile(r"^##\s+(.+?)\s*$")
TOP_KEY = re.compile(r"^([A-Za-z_][A-Za-z0-9_-]*)\s*:(.*)$")
CHILD_KEY = re.compile(r"^\s+([A-Za-z_\"'][^:]*?)\s*:")
PENDING = re.compile(r"==[^=]+==")


def normalize(name: str) -> str:
    """見出し名を正式名へ寄せる（別称・アポストロフィの揺れ・大小文字を吸収）。"""
    key = name.strip().replace("’", "'").lower()
    key = re.sub(r"\s+", " ", key)
    if key in ALIASES:
        return ALIASES[key]
    for canon in CANONICAL_SECTIONS:
        if canon.lower() == key:
            return canon
    return name.strip()


def split_front_matter(lines: list[str]) -> tuple[list[str], list[str], str | None]:
    """先頭の --- で囲まれた front matter と本文に分ける。"""
    if not lines or lines[0].strip() != "---":
        return [], lines, "front matter がない（1 行目が `---` で始まっていない）"
    for i in range(1, len(lines)):
        if lines[i].strip() in ("---", "..."):
            return lines[1:i], lines[i + 1:], None
    return [], lines, "front matter の終端 `---` が見つからない"


def parse_front_matter(fm: list[str]) -> tuple[dict[str, str], list[str], list[str]]:
    """トップレベルのキーと値、colors 直下の子キー、omitted の要素を取り出す。

    YAML パーサは使わず、インデントで階層を判定する簡易走査である。
    複雑な YAML（アンカー・複数行スカラー）は検証対象外とする。
    """
    top: dict[str, str] = {}
    color_keys: list[str] = []
    omitted: list[str] = []
    current = None
    for raw in fm:
        line = raw.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        m = TOP_KEY.match(line)
        if m:
            current = m.group(1)
            top[current] = m.group(2).strip()
            if current == "omitted" and top[current].startswith("["):
                omitted += [s.strip(" \"'") for s in top[current].strip("[]").split(",") if s.strip()]
            continue
        if current == "colors":
            c = CHILD_KEY.match(line)
            if c:
                color_keys.append(c.group(1).strip("\"'"))
        elif current == "omitted":
            item = line.strip()
            if item.startswith("-"):
                omitted.append(item.lstrip("- ").strip(" \"'"))
    return top, color_keys, omitted


def collect_sections(body: list[str]) -> list[str]:
    """本文の h2 見出しを、コードフェンス内を除いて拾う。"""
    sections: list[str] = []
    in_fence = False
    for raw in body:
        if FENCE.match(raw):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        m = H2.match(raw)
        if m:
            sections.append(m.group(1))
    return sections


def validate(path: Path) -> list[tuple[str, str]]:
    findings: list[tuple[str, str]] = []
    text = path.read_text(encoding="utf-8-sig")
    lines = text.splitlines()

    fm, body, fm_error = split_front_matter(lines)
    if fm_error:
        findings.append(("ERROR", fm_error))
        top, color_keys, omitted = {}, [], []
    else:
        top, color_keys, omitted = parse_front_matter(fm)

        for key in sorted(REQUIRED_KEYS - set(top)):
            findings.append(("ERROR", f"front matter に必須キー `{key}` がない"))
        if "name" in top and not top["name"]:
            findings.append(("ERROR", "`name` の値が空である"))
        for key in sorted(set(top) - KNOWN_KEYS):
            findings.append(("WARN", f"仕様にないトップレベルキー `{key}`（誤記か、仕様更新の可能性）"))
        if "version" not in top:
            findings.append(("WARN", "`version` が無い（仕様は alpha のため `version: alpha` を明示する）"))
        if "colors" in top and not color_keys:
            findings.append(("WARN", "`colors` にトークンが 1 つも定義されていない"))
        if color_keys and "primary" not in color_keys:
            findings.append(("ERROR", "`colors` に `primary` がない（仕様は primary パレットを必須とする）"))

    omitted_norm = {normalize(s) for s in omitted}
    sections = collect_sections(body)
    seen: dict[str, int] = {}
    last_index = -1

    for order, raw_name in enumerate(sections):
        canon = normalize(raw_name)
        if canon in seen:
            findings.append(("ERROR", f"セクション `{canon}` が重複している"))
            continue
        seen[canon] = order
        if canon not in CANONICAL_SECTIONS:
            level = "INFO" if canon.lower() in REPO_EXTRA_SECTIONS else "WARN"
            findings.append((level, f"仕様外のセクション `{raw_name}`"))
            continue
        idx = CANONICAL_SECTIONS.index(canon)
        if idx < last_index:
            findings.append((
                "ERROR",
                f"セクション `{canon}` の位置が仕様の順序に反する"
                f"（`{CANONICAL_SECTIONS[last_index]}` より後に置かれている）",
            ))
        last_index = max(last_index, idx)

    for canon in CANONICAL_SECTIONS:
        if canon not in seen and canon not in omitted_norm:
            findings.append(("WARN", f"セクション `{canon}` が無い（意図的なら front matter の `omitted` に列挙する）"))

    if "Do's and Don'ts" not in seen and "Do's and Don'ts" not in omitted_norm:
        findings.append(("WARN", "`Do's and Don'ts` はアンチパターンをガードレール化する欄であり、省略は避ける"))

    pending = sum(len(PENDING.findall(line)) for line in lines)
    if pending:
        findings.append(("INFO", f"未確定マーカー `==〜==` が {pending} 件ある（design-docs.md の表記規約）"))

    return findings


def main() -> int:
    # Windows の既定コンソール符号化（cp932）では日本語の指摘が化けるため UTF-8 に固定する
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")

    ap = argparse.ArgumentParser(description="DESIGN.md の構造を検証する")
    ap.add_argument("path", help="検証する DESIGN.md のパス")
    ap.add_argument("--json", action="store_true", help="結果を JSON で出力する")
    args = ap.parse_args()

    path = Path(args.path)
    if not path.is_file():
        print(f"ERROR: ファイルがない: {path}", file=sys.stderr)
        return 2

    try:
        findings = validate(path)
    except OSError as exc:
        print(f"ERROR: 読み込みに失敗した: {exc}", file=sys.stderr)
        return 2

    errors = [f for f in findings if f[0] == "ERROR"]
    if args.json:
        print(json.dumps(
            {"path": str(path), "findings": [{"level": lv, "message": msg} for lv, msg in findings],
             "error_count": len(errors)},
            ensure_ascii=False, indent=2,
        ))
    else:
        print(f"# DESIGN.md 構造検証: {path}")
        if not findings:
            print("指摘なし（構造は仕様に適合している）")
        for level, message in findings:
            print(f"{level}: {message}")
        print(f"--- ERROR {len(errors)} 件 / 指摘 {len(findings)} 件")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
