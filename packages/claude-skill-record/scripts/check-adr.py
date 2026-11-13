#!/usr/bin/env python3
"""doc/adr/ の ADR を読み取り専用で検査する（書き換えは一切しない）。

検査する項目:
  - ファイル名（YYYYMMDD_NNN_<タイトル>.md）、番号の欠番と重複、H1 の番号との一致
  - 日時・ステータスの行、ステータスの値（提案中 / 承認済み / 却下 で始まる）
  - 必須の節（コンテキスト → 検討した選択肢 → 決定 → 理由 → 影響）とその順序
  - 「**関連:**」行の書式と参照先（ADR-NNN を 確定|却下|置換|廃止|補足|訂正）
  - 本文中の ADR-NNN の参照先があるか、相対リンクの先があるか
  - commit を添えない行番号での参照（警告のみ）

ADR は書き換え禁止のため、既存の ADR の違反は直せない。そこで、番号が --since 以上の
ADR の違反だけを ERROR（終了コード 1）とし、それより前の ADR は --all を付けたときだけ
NOTE として表示する。

使い方:
  python .claude/scripts/check-adr.py                 # 検査（--since 以上だけ ERROR）
  python .claude/scripts/check-adr.py --all           # 既存の ADR の違反も NOTE で表示
  python .claude/scripts/check-adr.py --status        # 各 ADR の現在のステータスと、未決着の「提案中」を一覧
  python .claude/scripts/check-adr.py --dir <パス> --since <番号>
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

DEFAULT_SINCE = 1  # この番号以上の ADR の違反を ERROR にする。運用の途中で書式を改めたら、改めた番号に上げる
SECTIONS = ["コンテキスト", "検討した選択肢", "決定", "理由", "影響"]
STATUS_VALUES = ("提案中", "承認済み", "却下")
RELATIONS = ("確定", "却下", "置換", "廃止", "補足", "訂正")
# 後の ADR の関連行が、参照先の現在のステータスをどう変えるか
EFFECT = {"確定": "承認済み", "却下": "却下", "置換": "置換済み", "廃止": "廃止"}

FILE_RE = re.compile(r"^(\d{8})_(\d{3})_(.+)\.md$")
H1_RE = re.compile(r"^# ADR-(\d+):\s*\S")
STATUS_RE = re.compile(r"^\*\*ステータス:\*\*\s*(.*)$")
DATE_RE = re.compile(r"^\*\*日時:\*\*\s*\d{4}-\d{2}-\d{2}")
REL_LINE_RE = re.compile(r"^\*\*関連:\*\*\s*(.*)$")
REL_ITEM_RE = re.compile(r"^\[?ADR-(\d+)\]?(?:\([^)\s]*\))?\s*を\s*(\S+)$")  # リンクの形も可
ADR_REF_RE = re.compile(r"ADR-(\d{1,3})(?!\d)")
LINK_RE = re.compile(r"\]\(([^)\s]+)\)")
LINE_NO_RE = re.compile(r"\d+\s?行目")
COMMIT_RE = re.compile(r"\b[0-9a-f]{7,40}\b")
INLINE_CODE_RE = re.compile(r"`[^`]*`")


class Adr:
    def __init__(self, path: Path, num: int):
        self.path = path
        self.num = num
        self.lines = path.read_text(encoding="utf-8-sig").splitlines()
        self.status = ""
        self.relations: list[tuple[int, str]] = []
        for line in self.lines:
            m = STATUS_RE.match(line)
            if m and not self.status:
                self.status = m.group(1).strip()
            m = REL_LINE_RE.match(line)
            if m:
                for item in re.split(r"\s*(?:、|/|,)\s*", m.group(1).strip()):
                    rm = REL_ITEM_RE.match(item.strip())
                    if rm:
                        self.relations.append((int(rm.group(1)), rm.group(2)))

    def body_lines(self):
        """コードブロックの外の行を (行番号, 行) で返す。"""
        fenced = False
        for i, line in enumerate(self.lines, 1):
            if line.lstrip().startswith("```"):
                fenced = not fenced
                continue
            if not fenced:
                yield i, line


def load(adr_dir: Path) -> tuple[dict[int, list[Adr]], list[str]]:
    by_num: dict[int, list[Adr]] = {}
    stray: list[str] = []
    for p in sorted(adr_dir.glob("*.md")):
        m = FILE_RE.match(p.name)
        if not m:
            if p.name.lower() != "readme.md":
                stray.append(p.name)
            continue
        by_num.setdefault(int(m.group(2)), []).append(Adr(p, int(m.group(2))))
    return by_num, stray


def check_one(a: Adr, nums: set[int], by_num: dict[int, list[Adr]]) -> list[tuple[str, str]]:
    """(重さ, メッセージ) の一覧を返す。重さは E（違反）または W（警告）。"""
    out: list[tuple[str, str]] = []
    h1 = next((l for l in a.lines if l.startswith("# ")), "")
    m = H1_RE.match(h1)
    if not m:
        out.append(("E", "1 行目の見出しが「# ADR-<番号>: <タイトル>」の形でない"))
    elif int(m.group(1)) != a.num:
        out.append(("E", f"見出しの番号 ADR-{m.group(1)} がファイル名の番号 {a.num:03d} と違う"))
    if not any(DATE_RE.match(l) for l in a.lines):
        out.append(("E", "「**日時:** YYYY-MM-DD」の行が無い"))
    if not a.status:
        out.append(("E", "「**ステータス:**」の行が無い"))
    elif not a.status.startswith(STATUS_VALUES):
        out.append(("E", f"ステータス「{a.status}」が {' / '.join(STATUS_VALUES)} のどれでも始まらない"))

    heads = [l[3:].strip() for _, l in a.body_lines() if l.startswith("## ")]
    pos = []
    for s in SECTIONS:
        if s in heads:
            pos.append(heads.index(s))
        else:
            out.append(("E", f"必須の節「## {s}」が無い"))
    if pos != sorted(pos):
        out.append(("E", f"必須の節の順序が {' → '.join(SECTIONS)} になっていない"))

    for i, line in a.body_lines():
        rm = REL_LINE_RE.match(line)
        if rm:
            for item in re.split(r"\s*(?:、|/|,)\s*", rm.group(1).strip()):
                im = REL_ITEM_RE.match(item.strip())
                if not im:
                    out.append(("E", f"{i} 行目: 関連「{item}」が「ADR-NNN を {'|'.join(RELATIONS)}」の形でない"))
                    continue
                t, rel = int(im.group(1)), im.group(2)
                if rel not in RELATIONS:
                    out.append(("E", f"{i} 行目: 関連の種類「{rel}」は {'|'.join(RELATIONS)} のどれでもない"))
                if t not in nums:
                    out.append(("E", f"{i} 行目: 関連先 ADR-{t:03d} が存在しない"))
                elif t >= a.num:
                    out.append(("E", f"{i} 行目: 関連先 ADR-{t:03d} が自分より新しい（関連は過去の ADR に向ける）"))
                elif rel in ("確定", "却下"):
                    target = by_num[t][0]
                    if not target.status.startswith("提案中"):
                        out.append(("E", f"{i} 行目: ADR-{t:03d} を{rel}としたが、その ADR は「提案中」ではない"))
        prose = INLINE_CODE_RE.sub("", line)  # インラインコード内の例示は参照として扱わない
        for ref in ADR_REF_RE.findall(prose):
            if int(ref) not in nums:
                out.append(("E", f"{i} 行目: 参照先 ADR-{int(ref):03d} が存在しない"))
        for target in LINK_RE.findall(prose):
            if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I) or target.startswith("#"):
                continue
            rel_path = target.split("#", 1)[0]
            if rel_path and not (a.path.parent / rel_path).resolve().exists():
                out.append(("E", f"{i} 行目: 相対リンクの先「{rel_path}」が存在しない"))
        if LINE_NO_RE.search(prose) and not COMMIT_RE.search(line):
            out.append(("W", f"{i} 行目: commit を添えない行番号での参照（対象のファイルが変わると箇所がずれる）"))
    return out


def effective_status(by_num: dict[int, list[Adr]]) -> dict[int, tuple[str, int | None]]:
    eff: dict[int, tuple[str, int | None]] = {}
    for n, adrs in by_num.items():
        eff[n] = (adrs[0].status.split("（")[0] or "（無し）", None)
    for n in sorted(by_num):
        for t, rel in by_num[n][0].relations:
            if t in eff and rel in EFFECT:
                eff[t] = (EFFECT[rel], n)
    return eff


def print_status(by_num: dict[int, list[Adr]]) -> None:
    eff = effective_status(by_num)
    print("番号 | 記載のステータス | 現在のステータス | 決めた ADR")
    for n in sorted(by_num):
        declared = by_num[n][0].status.split("（")[0]
        cur, via = eff[n]
        print(f"{n:03d} | {declared} | {cur} | {'' if via is None else f'ADR-{via:03d}'}")
    pending = [n for n in sorted(by_num) if eff[n][0].startswith("提案中")]
    print(f"\n未決着の「提案中」: {len(pending)} 件（関連行で 確定・却下・置換・廃止 されていないもの）")
    for n in pending:
        mentions = [m for m in sorted(by_num) if m > n and any(
            int(r) == n for _, l in by_num[m][0].body_lines() for r in ADR_REF_RE.findall(l))]
        hint = "、".join(f"{m:03d}" for m in mentions) if mentions else "なし"
        print(f"  ADR-{n:03d}（後の ADR からの言及: {hint}）")


def main() -> int:
    for s in (sys.stdout, sys.stderr):
        try:
            s.reconfigure(encoding="utf-8")
        except (AttributeError, ValueError):
            pass
    ap = argparse.ArgumentParser(description="ADR を読み取り専用で検査する")
    ap.add_argument("--dir", default="doc/adr", help="ADR のディレクトリ（既定: doc/adr）")
    ap.add_argument("--since", type=int, default=DEFAULT_SINCE,
                    help=f"この番号以上の ADR の違反を ERROR にする（既定: {DEFAULT_SINCE}）")
    ap.add_argument("--all", action="store_true", help="--since より前の ADR の違反も NOTE で表示する")
    ap.add_argument("--status", action="store_true", help="現在のステータスと未決着の「提案中」を一覧する")
    args = ap.parse_args()

    adr_dir = Path(args.dir)
    if not adr_dir.is_dir():
        print(f"ERROR: ディレクトリが無い: {adr_dir}", file=sys.stderr)
        return 2
    by_num, stray = load(adr_dir)
    if not by_num:
        print("ADR がありません。")
        return 0
    if args.status:
        print_status(by_num)
        return 0

    nums = set(by_num)
    errors = warns = notes = 0
    for name in stray:
        print(f"WARN  {name}: ファイル名が YYYYMMDD_NNN_<タイトル>.md の形でない")
        warns += 1
    for n, adrs in sorted(by_num.items()):
        if len(adrs) > 1:
            print(f"ERROR 番号 {n:03d} が重複: {', '.join(a.path.name for a in adrs)}")
            errors += 1
    missing = [n for n in range(1, max(nums) + 1) if n not in nums]
    if missing:
        print(f"WARN  欠番: {', '.join(f'{n:03d}' for n in missing)}")
        warns += 1

    for n in sorted(by_num):
        a = by_num[n][0]
        new = n >= args.since
        for sev, msg in check_one(a, nums, by_num):
            if new:
                label = "ERROR" if sev == "E" else "WARN "
                errors += sev == "E"
                warns += sev == "W"
            elif args.all:
                label = "NOTE "
                notes += 1
            else:
                notes += 1
                continue
            print(f"{label} {a.path.name}: {msg}")

    hidden = "" if args.all else "（--all で表示）"
    print(f"\n検査した ADR: {len(by_num)} 件 / ERROR {errors} / WARN {warns} / "
          f"ADR-{args.since:03d} より前の所見 {notes} 件{hidden}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
