#!/usr/bin/env python3
"""color — 色空間変換・WCAG コントラスト比・色覚多様性シミュレーション（標準ライブラリのみ）。

Claude が暗算で出すと誤る値（相対輝度・コントラスト比・色差）を機械的に算出する。
用途: ux-review / anti-slop-review / ui-ux-pro-max の配色判定を目視から数値へ置き換える。
"""

from __future__ import annotations

import argparse
import colorsys
import re

from _common import Abort, emit, run

# sRGB(D65) -> XYZ。ΔE 計算のためだけに使う（IEC 61966-2-1 の標準行列）。
RGB_TO_XYZ = (
    (0.4124564, 0.3575761, 0.1804375),
    (0.2126729, 0.7151522, 0.0721750),
    (0.0193339, 0.1191920, 0.9503041),
)
WHITE_D65 = (0.95047, 1.00000, 1.08883)

# 色覚多様性の再現行列（線形 RGB 上で適用）。Viénot・Brettel らの手法に基づく近似で、
# 医学的診断には使えない。目的は「2 色が識別できなくなる組み合わせ」の機械検出に限る。
CVD_MATRIX = {
    "protanopia": ((0.11238, 0.88762, 0.0), (0.11238, 0.88762, 0.0), (0.00401, -0.00401, 1.0)),
    "deuteranopia": ((0.29275, 0.70725, 0.0), (0.29275, 0.70725, 0.0), (-0.02234, 0.02234, 1.0)),
    "tritanopia": ((1.0, 0.14461, -0.14461), (0.0, 0.85653, 0.14347), (0.0, 0.85653, 0.14347)),
}
# CIE76 ΔE の段階判定。規格値ではなく経験的な目安であり、境界付近の判断は人が行う。
# 変換後のコントラスト比（WCAG 1.4.11 の 3:1 = 非テキストの達成基準）を併記して補う。
DELTA_E_CRITICAL = 10.0  # これ未満: 変換後ほぼ同色。色だけで区別させてはならない
DELTA_E_WARN = 25.0      # これ未満: 明度が近く小さな要素では判別が難しい
CONTRAST_NON_TEXT = 3.0  # WCAG 2.1 達成基準 1.4.11（非テキストのコントラスト）


def parse_color(text: str) -> tuple[int, int, int]:
    """#rgb / #rrggbb / rgb(r,g,b) / r,g,b を受け取る。色名は解釈しない（曖昧さを持ち込まない）。"""
    s = text.strip().lower()
    m = re.fullmatch(r"#?([0-9a-f]{3})", s)
    if m:
        return tuple(int(c * 2, 16) for c in m.group(1))  # type: ignore[return-value]
    m = re.fullmatch(r"#?([0-9a-f]{6})", s)
    if m:
        h = m.group(1)
        return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))
    m = re.fullmatch(r"(?:rgba?\()?\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*\)?", s)
    if m:
        vals = tuple(int(g) for g in m.groups())
        if all(0 <= v <= 255 for v in vals):
            return vals  # type: ignore[return-value]
    raise Abort(f"色として解釈できない: {text}（#rrggbb / #rgb / rgb(r,g,b) / r,g,b のいずれかで指定する）")


def to_hex(rgb: tuple[int, int, int]) -> str:
    return "#{:02x}{:02x}{:02x}".format(*rgb)


def _linear(channel: int) -> float:
    c = channel / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _from_linear(value: float) -> int:
    v = min(1.0, max(0.0, value))
    srgb = v * 12.92 if v <= 0.0031308 else 1.055 * (v ** (1 / 2.4)) - 0.055
    return int(round(srgb * 255))


def luminance(rgb: tuple[int, int, int]) -> float:
    """WCAG 2.1 の相対輝度。"""
    r, g, b = (_linear(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast_ratio(fg: tuple[int, int, int], bg: tuple[int, int, int]) -> float:
    l1, l2 = luminance(fg), luminance(bg)
    hi, lo = max(l1, l2), min(l1, l2)
    return (hi + 0.05) / (lo + 0.05)


def to_lab(rgb: tuple[int, int, int]) -> tuple[float, float, float]:
    lin = [_linear(c) for c in rgb]
    xyz = [sum(RGB_TO_XYZ[i][j] * lin[j] for j in range(3)) / WHITE_D65[i] for i in range(3)]
    f = [(v ** (1 / 3)) if v > 0.008856 else (7.787 * v + 16 / 116) for v in xyz]
    return (116 * f[1] - 16, 500 * (f[0] - f[1]), 200 * (f[1] - f[2]))


def delta_e76(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    la, lb = to_lab(a), to_lab(b)
    return sum((x - y) ** 2 for x, y in zip(la, lb)) ** 0.5


def simulate_cvd(rgb: tuple[int, int, int], kind: str) -> tuple[int, int, int]:
    mat = CVD_MATRIX[kind]
    lin = [_linear(c) for c in rgb]
    out = [sum(mat[i][j] * lin[j] for j in range(3)) for i in range(3)]
    return tuple(_from_linear(v) for v in out)  # type: ignore[return-value]


def wcag_verdict(ratio: float) -> dict:
    """WCAG 2.1 の達成基準に対する合否。1.4.3(AA)/1.4.6(AAA)/1.4.11(非テキスト)。"""
    return {
        "AA_normal_text_4.5": ratio >= 4.5,
        "AA_large_text_3.0": ratio >= 3.0,
        "AAA_normal_text_7.0": ratio >= 7.0,
        "AAA_large_text_4.5": ratio >= 4.5,
        "AA_non_text_3.0": ratio >= 3.0,
    }


def cmd_convert(args) -> int:
    rgb = parse_color(args.color)
    h, l, s = colorsys.rgb_to_hls(*(c / 255 for c in rgb))
    hv, sv, vv = colorsys.rgb_to_hsv(*(c / 255 for c in rgb))
    lab = to_lab(rgb)
    return emit({
        "input": args.color,
        "hex": to_hex(rgb),
        "rgb": list(rgb),
        "hsl": [round(h * 360, 1), round(s * 100, 1), round(l * 100, 1)],
        "hsv": [round(hv * 360, 1), round(sv * 100, 1), round(vv * 100, 1)],
        "lab": [round(v, 2) for v in lab],
        "relative_luminance": round(luminance(rgb), 4),
    }, args.out)


def cmd_contrast(args) -> int:
    fg, bg = parse_color(args.fg), parse_color(args.bg)
    ratio = contrast_ratio(fg, bg)
    verdict = wcag_verdict(ratio)
    failed = [k for k, ok in verdict.items() if not ok]
    return emit({
        "fg": to_hex(fg), "bg": to_hex(bg),
        "contrast_ratio": round(ratio, 2),
        "wcag_2_1": verdict,
        "failed": failed,
        "note": "大文字テキストは 18pt 以上または 14pt 以上の太字（WCAG 2.1 の定義）",
    }, args.out)


def _pair_risk(kind: str, src: tuple, dst: tuple, sim_a: tuple, sim_b: tuple) -> dict | None:
    """変換後の 2 色が区別できるかを ΔE と明度差（コントラスト比）の両面で見る。"""
    de = delta_e76(sim_a, sim_b)
    ratio = contrast_ratio(sim_a, sim_b)
    if de >= DELTA_E_WARN:
        return None
    level = "critical" if de < DELTA_E_CRITICAL else "warning"
    if level == "warning" and ratio >= CONTRAST_NON_TEXT:
        # 色味が近くても明度差で区別できる場合は警告に留めず、明度差を根拠に許容する。
        return None
    return {
        "kind": kind, "level": level,
        "pair": [to_hex(src), to_hex(dst)],
        "simulated_pair": [to_hex(sim_a), to_hex(sim_b)],
        "delta_e76": round(de, 1),
        "simulated_contrast_ratio": round(ratio, 2),
        "message": (f"{kind} では区別が難しい（ΔE {round(de, 1)} / 変換後のコントラスト比 "
                    f"{round(ratio, 2)}:1）。色以外の手掛かり（文字・形・パターン）を併用する"),
    }


def cmd_cvd(args) -> int:
    colors = [parse_color(c) for c in args.colors]
    kinds = list(CVD_MATRIX) if args.kind == "all" else [args.kind]
    result: dict = {"input": [to_hex(c) for c in colors], "simulated": {}, "risks": []}
    for kind in kinds:
        sim = [simulate_cvd(c, kind) for c in colors]
        result["simulated"][kind] = [to_hex(c) for c in sim]
        for i in range(len(sim)):
            for j in range(i + 1, len(sim)):
                risk = _pair_risk(kind, colors[i], colors[j], sim[i], sim[j])
                if risk:
                    result["risks"].append(risk)
    result["verdict"] = "risk" if result["risks"] else "ok"
    result["thresholds"] = {"delta_e_critical": DELTA_E_CRITICAL, "delta_e_warning": DELTA_E_WARN,
                            "contrast_non_text": CONTRAST_NON_TEXT,
                            "note": "ΔE の閾値は経験的な目安（規格値ではない）。境界付近は人が判断する"}
    return emit(result, args.out)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="vnl.py color", description="色空間変換・コントラスト比・色覚多様性シミュレーション")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("convert", help="色空間の相互変換と相対輝度")
    p.add_argument("color")
    p.set_defaults(func=cmd_convert)

    p = sub.add_parser("contrast", help="WCAG 2.1 コントラスト比と達成基準の合否")
    p.add_argument("fg", help="前景色（文字色）")
    p.add_argument("bg", help="背景色")
    p.set_defaults(func=cmd_contrast)

    p = sub.add_parser("cvd", help="色覚多様性シミュレーションと識別困難な組み合わせの検出")
    p.add_argument("colors", nargs="+", help="1 色以上。2 色以上なら組み合わせの識別性も判定する")
    p.add_argument("--kind", choices=[*CVD_MATRIX, "all"], default="all")
    p.set_defaults(func=cmd_cvd)

    for p in (parser, *sub.choices.values()):
        if p is not parser:
            p.add_argument("--out", help="結果 JSON の退避先（指定時 stdout には要約のみ）")
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(run(main, __import__("sys").argv[1:]))
