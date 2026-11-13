"""potx/pptx からテーマ情報を抽出して theme.json を生成する。

office-pandoc スキルの補助スクリプト。スライドマスター（.potx）のデザイン
（配色・フォント・スライドサイズ・レイアウト名）を pandoc reference-doc
生成用のトークンファイル theme.json に書き出す。

使い方:
    python .claude/scripts/office/pandoc/extract_potx_theme.py <potx/pptxパス> --theme <テーマ名>

出力: このスクリプトと同じディレクトリの themes/<テーマ名>/theme.json（--theme は必須）
"""
import argparse
import json
import sys
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

NS = {
    "a": "http://schemas.openxmlformats.org/drawingml/2006/main",
    "p": "http://schemas.openxmlformats.org/presentationml/2006/main",
}

COLOR_KEYS = ["dk1", "lt1", "dk2", "lt2",
              "accent1", "accent2", "accent3", "accent4", "accent5", "accent6",
              "hlink", "folHlink"]


def color_value(elem):
    """srgbClr / sysClr のどちらでも 6 桁 HEX を返す"""
    srgb = elem.find("a:srgbClr", NS)
    if srgb is not None:
        return srgb.get("val").upper()
    sysclr = elem.find("a:sysClr", NS)
    if sysclr is not None:
        return (sysclr.get("lastClr") or "000000").upper()
    raise ValueError(f"unsupported color element under {elem.tag}")


def font_pair(font_elem):
    latin = font_elem.find("a:latin", NS)
    ea = font_elem.find("a:ea", NS)
    return {
        "latin": latin.get("typeface") if latin is not None else "",
        "ea": ea.get("typeface") if ea is not None else "",
    }


def main():
    parser = argparse.ArgumentParser(description="potx からテーマトークンを抽出する")
    parser.add_argument("potx", help="抽出元の .potx / .pptx パス")
    parser.add_argument("--theme", required=True,
                        help="出力先テーマ名（themes/<名前>/theme.json に書き出す。必須）")
    args = parser.parse_args()
    src = Path(args.potx)
    if not src.exists():
        print(f"ERROR: not found: {src}")
        sys.exit(1)

    theme_dir = Path(__file__).parent / "themes" / args.theme
    theme_dir.mkdir(parents=True, exist_ok=True)
    out_path = theme_dir / "theme.json"

    with zipfile.ZipFile(src) as z:
        theme_xml = z.read("ppt/theme/theme1.xml")
        pres_xml = z.read("ppt/presentation.xml")
        layout_names = []
        for name in sorted(n for n in z.namelist()
                           if n.startswith("ppt/slideLayouts/slideLayout") and n.endswith(".xml")):
            root = ET.fromstring(z.read(name))
            csld = root.find("p:cSld", NS)
            layout_names.append(csld.get("name") if csld is not None else "")

    theme_root = ET.fromstring(theme_xml)
    theme_elem = theme_root  # <a:theme name="...">
    scheme = theme_root.find(".//a:clrScheme", NS)
    colors = {}
    for key in COLOR_KEYS:
        node = scheme.find(f"a:{key}", NS)
        colors[key] = color_value(node)

    font_scheme = theme_root.find(".//a:fontScheme", NS)
    major = font_pair(font_scheme.find("a:majorFont", NS))
    minor = font_pair(font_scheme.find("a:minorFont", NS))

    pres_root = ET.fromstring(pres_xml)
    sldsz = pres_root.find("p:sldSz", NS)

    result = {
        "_source": str(src).replace("\\", "/"),
        "_theme_name": theme_elem.get("name", ""),
        "slide_size": {"cx": int(sldsz.get("cx")), "cy": int(sldsz.get("cy"))},
        "fonts": {
            "major_latin": major["latin"],  # 見出し（欧文）
            "major_ea": major["ea"],        # 見出し（日本語）
            "minor_latin": minor["latin"],  # 本文（欧文）
            "minor_ea": minor["ea"],        # 本文（日本語）
        },
        "colors": colors,
        "layouts": layout_names,
    }

    out_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"OK: wrote {out_path}")
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
