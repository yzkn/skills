#!/usr/bin/env python3
"""visual-doc の生成物を機械的に検証する。

検証項目:
  1. 自己完結性（外部リソース参照・外部 JS の不在）
  2. AI slop 兆候（紫グラデ・グラデ見出し・transition-all・等幅 3 列グリッド）
  3. WCAG コントラスト比（:root と prefers-color-scheme の両テーマ）
  4. SVG の viewBox はみ出しとテキスト幅の概算

使い方:
  python .claude/skills/visual-doc/scripts/verify_output.py <生成した .html>

終了コード: 0=すべて合格 / 1=不合格あり / 2=引数・ファイルの誤り
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

for _s in (sys.stdout, sys.stderr):
    if hasattr(_s, "reconfigure"):
        _s.reconfigure(encoding="utf-8", errors="replace")

# 塗り面（--c-*-fill）の上に載せる文字は常に白（.on-fill）である前提で検証する。
# 淡色面（--c-*-soft）の上は本文色（--text）。
TEXT_PAIRS = [
    ("本文 --text / --bg", "--text", "--bg", 4.5),
    ("本文 --text / --surface", "--text", "--surface", 4.5),
    ("補助 --text-sub / --bg", "--text-sub", "--bg", 4.5),
    ("--text / --c-info-soft（表ヘッダ・コード）", "--text", "--c-info-soft", 4.5),
    ("--text / --c-warn-soft（注記）", "--text", "--c-warn-soft", 4.5),
]
FILLS = ["--c-ok-fill", "--c-info-fill", "--c-warn-fill", "--c-err-fill", "--c-proc-fill"]
# SVG の図形境界・矢印線は「内容の理解に必要な図形」= 非テキスト 3:1（WCAG 1.4.11）
GRAPHIC_PAIRS = [("--c-muted", "--bg"), ("--c-ok", "--bg"), ("--c-info", "--bg"),
                 ("--c-warn", "--bg"), ("--c-err", "--bg"), ("--c-proc", "--bg")]

failures: list[str] = []


def lum(color: str) -> float:
    r, g, b = (int(color[i:i + 2], 16) / 255 for i in (1, 3, 5))
    f = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)


def ratio(a: str, b: str) -> float:
    hi, lo = max(lum(a), lum(b)), min(lum(a), lum(b))
    return (hi + 0.05) / (lo + 0.05)


def judge(cond: bool, label: str) -> str:
    if not cond:
        failures.append(label)
    return "OK" if cond else "**NG**"


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    target = Path(sys.argv[1])
    if not target.is_file():
        print(f"ファイルが見つからない: {target}", file=sys.stderr)
        return 2
    html = target.read_text(encoding="utf-8")
    print(f"# 検証対象: {target}（{len(html)} バイト）")

    # 1. 自己完結性
    ext = re.findall(r'(?:src|href|@import|url\()\s*=?\s*["\']?(?:https?:)?//[^"\')\s]+', html)
    js = re.findall(r"<script[^>]*src=", html)
    print("\n## 1. 自己完結性")
    print(f"{judge(not ext, '外部リソース参照')} 外部リソース参照: {len(ext)} 件 {ext[:5] if ext else ''}")
    print(f"{judge(not js, '外部 JS')} 外部 JS: {len(js)} 件")

    # 2. AI slop 兆候
    print("\n## 2. AI slop 兆候（anti-slop-review の Critical 項目）")
    slop = {
        "紫グラデ (#667eea/#764ba2)": len(re.findall(r"667eea|764ba2", html, re.I)),
        "グラデ見出し (background-clip: text)": len(re.findall(r"background-clip\s*:\s*text", html, re.I)),
        "transition: all": len(re.findall(r"transition\s*:\s*all", html, re.I)),
        "等幅 3 列グリッド repeat(3,": len(re.findall(r"repeat\(3,", html)),
    }
    for k, v in slop.items():
        print(f"{judge(v == 0, k)} {k}: {v}")
    grad = len(re.findall(r"linear-gradient|radial-gradient", html, re.I))
    print(f"{'--' if grad == 0 else '!!'} グラデーションの使用: {grad} 件"
          f"{'（意味を持つ場合のみ許容。装飾なら除去する）' if grad else ''}")

    # 3. コントラスト比
    roots = re.findall(r":root[^{]*\{(.*?)\}", html, re.S)
    themes = [("ライト", dict(re.findall(r"(--[a-z-]+):\s*(#[0-9a-fA-F]{6})", roots[0])))] if roots else []
    if len(roots) > 1:
        merged = dict(themes[0][1])
        merged.update(dict(re.findall(r"(--[a-z-]+):\s*(#[0-9a-fA-F]{6})", roots[1])))
        themes.append(("ダーク", merged))
    else:
        failures.append("ダークテーマ未定義（prefers-color-scheme）")
        print("\n**NG** ダークテーマ（prefers-color-scheme）の :root が見つからない")

    for name, tk in themes:
        print(f"\n## 3. コントラスト比（{name}テーマ）")
        print("| 組み合わせ | 比 | 基準 | 判定 |")
        print("|---|---|---|---|")
        for label, fg, bg, need in TEXT_PAIRS:
            if fg not in tk or bg not in tk:
                continue
            r = ratio(tk[fg], tk[bg])
            print(f"| {label} | {r:.2f}:1 | {need} | {judge(r >= need, f'{name}: {label}')} |")
        for fill in FILLS:
            if fill not in tk:
                continue
            r = ratio("#ffffff", tk[fill])
            print(f"| 白文字 .on-fill / {fill} | {r:.2f}:1 | 4.5 | {judge(r >= 4.5, f'{name}: white/{fill}')} |")
        for fg, bg in GRAPHIC_PAIRS:
            if fg not in tk or bg not in tk:
                continue
            r = ratio(tk[fg], tk[bg])
            print(f"| 図形境界 {fg} / {bg} | {r:.2f}:1 | 3.0 | {judge(r >= 3.0, f'{name}: {fg}/{bg}')} |")

    # 4. SVG
    print("\n## 4. SVG の座標とテキスト幅")
    for i, svg in enumerate(re.findall(r"<svg\b.*?</svg>", html, re.S), 1):
        vb = re.search(r'viewBox="0 0 (\d+(?:\.\d+)?) (\d+(?:\.\d+)?)"', svg)
        if not vb:
            print(f"**NG** SVG#{i}: viewBox が無い（レスポンシブにならない）")
            failures.append(f"SVG#{i} viewBox")
            continue
        vw, vh = float(vb.group(1)), float(vb.group(2))
        has_title = "<title>" in svg
        print(f"SVG#{i}: viewBox {vw:.0f}x{vh:.0f} / <title> {judge(has_title, f'SVG#{i} title')}")
        over = [g for g in re.findall(r'<rect x="(\d+)" y="(\d+)" width="(\d+)" height="(\d+)"', svg)
                if int(g[0]) + int(g[2]) > vw or int(g[1]) + int(g[3]) > vh]
        print(f"{judge(not over, f'SVG#{i} はみ出し')} viewBox をはみ出す rect: {len(over)} 件 {over or ''}")
        # 日本語 1 文字 ≒ font-size、半角 ≒ font-size*0.55 で概算し、同じ中心 x を持つ rect 幅と比較
        boxes = {int(m.group(1)) + int(m.group(3)) // 2: int(m.group(3))
                 for m in re.finditer(r'<rect x="(\d+)" y="(\d+)" width="(\d+)"', svg)}
        wide = []
        for m in re.finditer(r'<text x="(\d+)"[^>]*font-size="(\d+)"[^>]*>([^<]+)</text>', svg):
            cx, fs, txt = int(m.group(1)), int(m.group(2)), m.group(3)
            if cx not in boxes:
                continue
            w = sum(fs if ord(c) > 0x2000 else fs * 0.55 for c in txt)
            if w > boxes[cx] - 8:
                wide.append((txt, round(w), boxes[cx]))
        print(f"{judge(not wide, f'SVG#{i} テキスト幅')} 親 rect に収まらないテキスト: {len(wide)} 件")
        for txt, w, box in wide:
            print(f"    幅 {w} > {box - 8}: 「{txt}」")
        # ドーナツ・進捗リング: stroke-dasharray の合計が円周（2πr）と一致するか
        bad_ring = []
        for c in re.findall(r"<circle\b[^>]*>", svg, re.S):
            r = re.search(r'\br="(\d+(?:\.\d+)?)"', c)
            da = re.search(r'stroke-dasharray="\s*(\d+(?:\.\d+)?)[ ,]+(\d+(?:\.\d+)?)', c)
            if not (r and da):
                continue
            circ = 2 * 3.14159265 * float(r.group(1))
            total = float(da.group(1)) + float(da.group(2))
            if abs(total - circ) / circ > 0.01:      # 1% 以上ずれていれば計算間違い
                bad_ring.append((r.group(1), round(total, 1), round(circ, 1)))
        if re.search(r"stroke-dasharray", svg):
            print(f"{judge(not bad_ring, f'SVG#{i} 円周計算')} dasharray と円周(2πr)の不一致: {len(bad_ring)} 件")
            for rr, total, circ in bad_ring:
                print(f"    r={rr}: dasharray 合計 {total} ≠ 円周 {circ}")

    print("\n## 判定")
    if failures:
        print(f"**NG {len(failures)} 件**: " + " / ".join(failures))
        return 1
    print("OK すべて合格")
    return 0


if __name__ == "__main__":
    sys.exit(main())
