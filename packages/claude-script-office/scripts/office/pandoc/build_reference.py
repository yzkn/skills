"""pandoc reference-doc テンプレート（reference.docx / reference.pptx）を生成する。

office-pandoc スキルの補助スクリプト。

- reference.pptx: theme.json の `_source` が指すスライドマスター（potx）**そのもの**を基底に構築する。
  背景画像・図形・マスターデザインを完全に保持したまま、pandoc が名前で照合する
  レイアウト（Title Slide 等）へ potx のレイアウトを改名して割り当て、potx に存在しない
  レイアウト（Two Content / Comparison / Content with Caption）はコンテンツから
  合成する。未使用レイアウト・サンプルスライド・未参照メディアは削除して軽量化する。
- reference.docx: pandoc 組み込みのデフォルト reference をベースに、theme.json の
  デザイントークン（potx から抽出）を OOXML パッチとして適用する。

使い方:
    python .claude/scripts/office/pandoc/build_reference.py [--theme <テーマ名>]
    （--theme 省略時は themes/ 配下の全テーマを生成）

入力: themes/<テーマ名>/theme.json（extract_potx_theme.py で生成、または手書きのトークン定義。
      `_source` の potx パスを reference.pptx の基底として読み込む。
      `_source` を持たないテーマの pptx は、pandoc デフォルト reference への
      テーマ移植方式〈配色・フォント・16:9 スケーリング・日本語化〉で生成する）
出力: themes/<テーマ名>/reference.docx / reference.pptx

docx に適用するデザイン:
- 配色: theme.json の clrScheme 12 色をテーマにそのまま移植
- フォント: 見出し=major、本文=minor（欧文・日本語とも）
- 見出し色を dk2 直接指定に変更（テーマによっては accent1 が薄灰色で
  themeColor="accent1" 参照のままだと見出しが灰色になる）、
  用紙を A4 に変更、既定の東アジア言語を ja-JP に変更
"""
import argparse
import io
import json
import re
import subprocess
import sys
import zipfile
from pathlib import Path

DIR = Path(__file__).parent
A4_PGSZ = '<w:pgSz w:w="11906" w:h="16838" />'
A4_PGMAR = ('<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" '
            'w:header="720" w:footer="720" w:gutter="0" />')

# コードブロック・インラインコード用フォント（欧文 / 日本語）
CODE_LATIN = "Consolas"
CODE_EA = "游ゴシック"

# レガシー MS フォント → 游フォントの置換表
# （pandoc デフォルトテーマの script="Jpan" フォールバック等に残存するため）
LEGACY_FONT_MAP = {
    "ＭＳ Ｐゴシック": "游ゴシック",
    "ＭＳ ゴシック": "游ゴシック",
    "ＭＳ Ｐ明朝": "游明朝",
    "ＭＳ 明朝": "游明朝",
}

# pandoc が名前で照合するレイアウト（左）に割り当てる potx のレイアウト（右）。
# 値は例。potx 直接ベース方式を使う場合は、使う potx のレイアウト名に合わせて書き換える
PANDOC_LAYOUT_MAP = {
    "Title Slide": "表紙",
    "Section Header": "中表紙",
    "Title and Content": "コンテンツ",
    "Blank": "空白",
}

# potx に存在しないレイアウトの合成元と、左右コンテンツの間隔（EMU）
SYNTH_BASE = "コンテンツ"
SYNTH_GAP = 300000
SYNTH_CAPTION_H = 600000  # Comparison の見出しテキスト行の高さ

# docx サンプル本文の日本語化（<w:t> ノード単位の完全一致）
# pandoc は reference の本文を変換に使わないが、スタイル見本として日本語化しておく
DOCX_JP_SAMPLES = [
    ("Title", "文書タイトル"),
    ("Subtitle", "サブタイトル"),
    ("Author", "作成者"),
    ("Date", "日付"),
    ("Abstract", "概要"),
    *[(f"Heading {i}", f"見出し {i}") for i in range(1, 10)],
    ("First Paragraph.", "最初の段落（First Paragraph）です。"),
    ("Body Text. Body Text Char.", "本文（Body Text）の段落です。"),
    ("Verbatim Char", "インラインコード"),
    ("Hyperlink", "ハイパーリンク"),
    ("Footnote.", "脚注参照。"),
    ("Block Text.", "引用（Block Text）の段落です。"),
    ("Table caption.", "表キャプション。"),
    ("Image Caption", "図キャプション"),
    ("Footnote Text.", "脚注（Footnote Text）です。"),
    ("Footnote Block Text", "脚注内の引用（Footnote Block Text）"),
]

# docx サンプル本文のうち、同一文字列が複数回登場するもの（出現順に異なる訳語を割り当てる）
DOCX_JP_SAMPLES_SEQ = [
    ("Table", ["項目", "説明"]),                                  # 表ヘッダーの 2 セル
    ("DefinitionTerm", ["用語A", "用語B"]),                       # 定義リスト 2 組
    ("Definition", ["用語Aの定義の説明です。", "用語Bの定義の説明です。"]),
]


def fail(msg):
    print(f"ERROR: {msg}")
    sys.exit(1)


def pandoc_default(name: str) -> bytes:
    r = subprocess.run(["pandoc", "--print-default-data-file", name],
                       capture_output=True)
    if r.returncode != 0 or not r.stdout:
        fail(f"pandoc デフォルト {name} の取得に失敗: {r.stderr.decode(errors='replace')}")
    return r.stdout


def sub_checked(pattern, repl, text, label, count=0, flags=0):
    new, n = re.subn(pattern, repl, text, count=count, flags=flags)
    if n == 0:
        fail(f"パッチ不発: {label}（pandoc のデフォルト構造が変わった可能性。パターン: {pattern}）")
    return new


def patch_theme_xml(xml: str, theme: dict) -> str:
    """theme1.xml（docx / pptx 共通）に配色とフォントを移植する"""
    for key, val in theme["colors"].items():
        xml = sub_checked(
            rf"(<a:{key}>).*?(</a:{key}>)",
            rf'\g<1><a:srgbClr val="{val}"/>\g<2>',
            xml, f"clrScheme {key}", count=1, flags=re.S)

    def patch_font_block(block_name, latin, ea, xml):
        m = re.search(rf"<a:{block_name}>.*?</a:{block_name}>", xml, flags=re.S)
        if not m:
            fail(f"パッチ不発: fontScheme {block_name}")
        block = m.group(0)
        block = sub_checked(r'(<a:latin\b[^>]*?typeface=")[^"]*(")',
                            rf"\g<1>{latin}\g<2>", block,
                            f"{block_name} latin", count=1)
        block = sub_checked(r'(<a:ea\b[^>]*?typeface=")[^"]*(")',
                            rf"\g<1>{ea}\g<2>", block,
                            f"{block_name} ea", count=1)
        return xml[:m.start()] + block + xml[m.end():]

    f = theme["fonts"]
    xml = patch_font_block("majorFont", f["major_latin"], f["major_ea"], xml)
    xml = patch_font_block("minorFont", f["minor_latin"], f["minor_ea"], xml)

    # スクリプト別フォールバック（script="Jpan" 等）に残るレガシー MS フォントを游フォントへ
    for legacy, yu in LEGACY_FONT_MAP.items():
        xml = xml.replace(f'typeface="{legacy}"', f'typeface="{yu}"')

    # テーマ表示名（<a:theme> ルート要素のみ。clrScheme 等の name="Office" は照合に使われうるため触らない）
    display = theme.get("_display_name", "Custom テーマ")
    xml = re.sub(r'(<a:theme[^>]*name=")[^"]*(")',
                 lambda m: m.group(1) + display + m.group(2), xml, count=1)
    return xml


def patch_zip(data: bytes, patchers: dict) -> bytes:
    """zip 内の指定エントリをテキスト変換（entry 順序は維持する）"""
    out = io.BytesIO()
    with zipfile.ZipFile(io.BytesIO(data)) as zin, \
         zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zout:
        names = zin.namelist()
        for target in patchers:
            if target not in names:
                fail(f"エントリが存在しない: {target}")
        for info in zin.infolist():
            content = zin.read(info.filename)
            if info.filename in patchers:
                content = patchers[info.filename](content.decode("utf-8")).encode("utf-8")
            zout.writestr(info, content)
    return out.getvalue()


def _sp_blocks(xml):
    """spTree 直下の <p:sp> ブロックを列挙する（p:sp は入れ子にならない）"""
    return list(re.finditer(r"<p:sp>.*?</p:sp>", xml, flags=re.S))


def _sp_geometry(sp: str):
    off = re.search(r'<a:off x="(\d+)" y="(\d+)"/>', sp)
    ext = re.search(r'<a:ext cx="(\d+)" cy="(\d+)"/>', sp)
    if not off or not ext:
        fail("合成元コンテンツ ph に xfrm（座標）がない")
    return int(off.group(1)), int(off.group(2)), int(ext.group(1)), int(ext.group(2))


def _make_ph_sp(tmpl: str, cnv_id: int, name: str, ph_xml: str, x, y, cx, cy) -> str:
    """コンテンツ ph の sp を複製し、ID・名前・ph 属性・座標を差し替える"""
    s = re.sub(r'(<p:cNvPr id=")\d+(" name=")[^"]*(")',
               rf"\g<1>{cnv_id}\g<2>{name}\g<3>", tmpl, count=1)
    s = sub_checked(r"<p:ph[^>]*/>", ph_xml, s, "ph 属性の差し替え", count=1)
    s = sub_checked(r'<a:off x="\d+" y="\d+"/>', f'<a:off x="{x}" y="{y}"/>', s, "off", count=1)
    s = sub_checked(r'<a:ext cx="\d+" cy="\d+"/>', f'<a:ext cx="{cx}" cy="{cy}"/>', s, "ext", count=1)
    return s


def _synth_layout(base_xml: str, new_name: str, ph_specs) -> str:
    """コンテンツを元に、指定のプレースホルダー構成のレイアウトを合成する。

    ph_specs: (ph_xml, x, y, cx, cy) のリスト。元の idx=1 コンテンツ ph を
    テンプレートとして置き換え、リード文の body ph は削除する。
    """
    xml = sub_checked(r'(<p:cSld name=")[^"]*(")', rf"\g<1>{new_name}\g<2>",
                      base_xml, "cSld name", count=1)
    content_m = lead_m = None
    for m in _sp_blocks(xml):
        s = m.group(0)
        ph = re.search(r"<p:ph[^>]*/>", s)
        if not ph:
            continue
        if 'idx="1"' in ph.group(0):
            content_m = m
        elif 'type="body"' in ph.group(0):
            lead_m = m
    if content_m is None:
        fail(f"合成元 '{SYNTH_BASE}' に idx=1 のコンテンツ ph がない")
    tmpl = content_m.group(0)
    new_sps = "".join(
        _make_ph_sp(tmpl, 900 + i, f"コンテンツ プレースホルダー {900 + i}", *spec)
        for i, spec in enumerate(ph_specs))
    xml = xml[:content_m.start()] + new_sps + xml[content_m.end():]
    if lead_m is not None:
        xml = xml.replace(lead_m.group(0), "", 1)
    return xml


def _synth_specs(x, y, cx, cy):
    """合成レイアウト 3 種のプレースホルダー構成（PowerPoint 標準レイアウトに準拠）"""
    half = (cx - SYNTH_GAP) // 2
    rx = x + half + SYNTH_GAP
    cap_h = SYNTH_CAPTION_H
    body_y = y + cap_h + 80000
    body_cy = cy - cap_h - 80000
    text_w = cx * 35 // 100
    return {
        "Two Content": [
            ('<p:ph sz="half" idx="1"/>', x, y, half, cy),
            ('<p:ph sz="half" idx="2"/>', rx, y, half, cy),
        ],
        "Comparison": [
            ('<p:ph type="body" sz="quarter" idx="1"/>', x, y, half, cap_h),
            ('<p:ph sz="quarter" idx="2"/>', x, body_y, half, body_cy),
            ('<p:ph type="body" sz="quarter" idx="3"/>', rx, y, half, cap_h),
            ('<p:ph sz="quarter" idx="4"/>', rx, body_y, half, body_cy),
        ],
        "Content with Caption": [
            ('<p:ph type="body" idx="1"/>', x, y, text_w, cy),
            ('<p:ph idx="2"/>', x + text_w + SYNTH_GAP, y, cx - text_w - SYNTH_GAP, cy),
        ],
    }


def _resolve(base_dir: str, target: str) -> str:
    import posixpath
    return posixpath.normpath(posixpath.join(base_dir, target))


def _verify_package(parts: dict) -> None:
    """参照整合性のセルフチェック。

    宙に浮いた relationship・rels に無い r:id 参照・実在しないパートへの
    Content_Types Override は、いずれも PowerPoint の修復ダイアログの原因になる。
    """
    issues = []
    rels_ids = {}
    for name, data in parts.items():
        if not name.endswith(".rels"):
            continue
        base = name.rsplit("/_rels/", 1)[0] if "/_rels/" in name else ""
        ids = set()
        for m in re.finditer(r"<Relationship ([^>]*)/>", data.decode("utf-8")):
            attrs = dict(re.findall(r'(\w+)="([^"]*)"', m.group(1)))
            ids.add(attrs.get("Id", ""))
            target = attrs.get("Target", "")
            if attrs.get("TargetMode") == "External" or target.startswith(("http", "file")):
                continue
            if _resolve(base, target) not in parts:
                issues.append(f"{name}: {attrs.get('Id')} -> {target} が存在しない")
        rels_ids[name] = ids
    for name, data in parts.items():
        if not name.endswith(".xml") or name.endswith(".rels"):
            continue
        d, _, fn = name.rpartition("/")
        rels_name = f"{d}/_rels/{fn}.rels" if d else f"_rels/{fn}.rels"
        ids = rels_ids.get(rels_name, set())
        for m in re.finditer(r'r:(?:id|embed|link|dm|lo|qs|cs)="(rId\d+)"',
                             data.decode("utf-8")):
            if m.group(1) not in ids:
                issues.append(f"{name}: {m.group(1)} への参照が {rels_name} に無い")
    ct = parts["[Content_Types].xml"].decode("utf-8")
    for pn in re.findall(r'<Override PartName="([^"]*)"', ct):
        if pn.lstrip("/") not in parts:
            issues.append(f"[Content_Types].xml: 存在しないパートへの Override: {pn}")
    if issues:
        fail("参照整合性チェックに失敗:\n  " + "\n  ".join(issues))


# ---------------------------------------------------------------------------
# potx を持たないテーマ用のフォールバック: pandoc デフォルト reference への
# テーマ移植方式（配色・フォント・16:9 スケーリング・日本語化）
# ---------------------------------------------------------------------------

# pptx マスター・レイアウトのプレースホルダー文言の日本語化
# （編集時の表示のみに影響。pandoc の変換出力には現れない）
PPTX_JP_PROMPTS = [
    ("Click to edit Master title style", "マスター タイトルの書式設定"),
    ("Click to edit Master text styles", "マスター テキストの書式設定"),
    ("Edit Master text styles", "マスター テキストの書式設定"),
    ("Click to edit Master subtitle style", "マスター サブタイトルの書式設定"),
    ("Second level", "第 2 レベル"),
    ("Third level", "第 3 レベル"),
    ("Fourth level", "第 4 レベル"),
    ("Fifth level", "第 5 レベル"),
    ("Click icon to add picture", "アイコンをクリックして画像を追加"),
    ("Click to add text", "テキストを入力"),
    ("Click to add title", "タイトルを入力"),
    ("Click to edit Master notes styles", "マスター ノートの書式設定"),
]

# pptx サンプルスライド・ノートの本文の日本語化（<a:t> ノード単位の完全一致）
# pandoc は reference のスライド本文を変換に使わないが、テンプレートを開いたときの
# 見本として日本語化しておく
PPTX_JP_SAMPLES = [
    ("Presentation Title", "プレゼンテーションタイトル"),
    ("Presentation Subtitle", "サブタイトル"),
    ("Slide Title for Two-Content", "2 カラムのスライドタイトル"),
    ("Slide Title", "スライドタイトル"),
    ("Hello", "こんにちは"),
    (", world.", "、世界。"),
    ("Section header", "セクション見出し"),
    ("Some content on ", "左側の"),
    ("the left.", "コンテンツ。"),
    ("Some content on the right.", "右側のコンテンツ。"),
    ("Here", "これは"),
    (" is a note", "ノートです"),
    ("With another paragraph.", "別の段落もあります。"),
    ("A", "この"),
    (" speaker note on ", "スライドにも"),
    ("this slide too.", "ノートがあります。"),
]

def _scale_attr(xml: str, attr: str, factor: float) -> str:
    return re.sub(rf' {attr}="(-?\d+)"',
                  lambda m: f' {attr}="{round(int(m.group(1)) * factor)}"',
                  xml)


def scale_pptx_text_attrs(xml: str, fx: float, fy: float) -> str:
    """文字サイズ（1/100 pt）・字下げ・タブ幅・段落間隔をスライド拡大率に合わせる"""
    for attr in ("sz", "marL", "marR", "indent", "defTabSz"):
        xml = _scale_attr(xml, attr, fx)
    xml = re.sub(r'(<a:spcPts val=")(\d+)(")',
                 lambda m: f"{m.group(1)}{round(int(m.group(2)) * fy)}{m.group(3)}",
                 xml)
    return xml


def scale_pptx_geometry(xml: str, fx: float, fy: float) -> str:
    """スライドサイズ変更に合わせてプレースホルダーの座標・サイズ・文字サイズを拡縮する。

    pandoc デフォルト reference のレイアウトは旧スライドサイズ（9144000×5143500）
    前提の絶対座標で置かれているため、sldSz だけ変更するとコンテンツが左上に寄る。
    """
    if abs(fx - 1.0) < 1e-9 and abs(fy - 1.0) < 1e-9:
        return xml
    # 位置・サイズ（EMU）: a:off / a:chOff の x,y と a:ext / a:chExt の cx,cy
    for attr in ("x", "cx"):
        xml = _scale_attr(xml, attr, fx)
    for attr in ("y", "cy"):
        xml = _scale_attr(xml, attr, fy)
    return scale_pptx_text_attrs(xml, fx, fy)


def japanize_pptx_xml(xml: str) -> str:
    """マスター・レイアウト・スライド・ノートのプレースホルダー文言、
    サンプル本文、言語属性を日本語化する"""
    for en, ja in PPTX_JP_PROMPTS:
        xml = xml.replace(f">{en}<", f">{ja}<")
    for en, ja in PPTX_JP_SAMPLES:
        xml = xml.replace(f">{en}</a:t>", f">{ja}</a:t>")
    xml = xml.replace('lang="en-US"', 'lang="ja-JP"')
    return xml


def build_pptx_transplant(theme: dict) -> bytes:
    """potx を持たないテーマ用: pandoc デフォルト reference にテーマを移植して pptx を生成する"""
    sz = theme["slide_size"]
    default = pandoc_default("reference.pptx")
    with zipfile.ZipFile(io.BytesIO(default)) as z:
        names = z.namelist()
        pres_xml = z.read("ppt/presentation.xml").decode("utf-8")

    # 旧スライドサイズとの比率（レイアウト座標のスケーリングに使う）
    m = re.search(r'<p:sldSz cx="(\d+)" cy="(\d+)"', pres_xml)
    if not m:
        fail("パッチ不発: 旧 sldSz の取得")
    fx = sz["cx"] / int(m.group(1))
    fy = sz["cy"] / int(m.group(2))

    def patch_pres(xml):
        xml = sub_checked(r"<p:sldSz[^>]*/>",
                          f'<p:sldSz cx="{sz["cx"]}" cy="{sz["cy"]}"/>',
                          xml, "sldSz", count=1)
        # defaultTextStyle（marL / indent / defTabSz / sz）のみ追随させる
        # （座標系のスケーリングを掛けると設定済みの sldSz・notesSz まで再拡大されるため不可）
        return japanize_pptx_xml(scale_pptx_text_attrs(xml, fx, fy))

    def patch_master(xml):
        # タイトルの文字色を基調色（tx2 → clrMap 経由で dk2）にする
        m = re.search(r"<p:titleStyle>.*?</p:titleStyle>", xml, flags=re.S)
        if not m:
            fail("パッチ不発: slideMaster titleStyle")
        block = sub_checked(r'(<a:solidFill><a:schemeClr val=")tx1("/></a:solidFill>)',
                            r"\g<1>tx2\g<2>", m.group(0),
                            "titleStyle color", count=1)
        xml = xml[:m.start()] + block + xml[m.end():]
        return japanize_pptx_xml(scale_pptx_geometry(xml, fx, fy))

    def patch_slide_part(xml):
        return japanize_pptx_xml(scale_pptx_geometry(xml, fx, fy))

    patchers = {"ppt/presentation.xml": patch_pres}
    for name in names:
        if re.fullmatch(r"ppt/theme/theme\d+\.xml", name):
            # ノートマスター用テーマ（theme2 等）も含めてすべて potx のテーマに置換
            patchers[name] = lambda x: patch_theme_xml(x, theme)
        elif re.fullmatch(r"ppt/slideMasters/slideMaster\d+\.xml", name):
            patchers[name] = patch_master
        elif re.fullmatch(r"ppt/(slideLayouts/slideLayout|slides/slide)\d+\.xml", name):
            # スライドサイズ前提の絶対座標を持つパートはスケーリング + 日本語化
            patchers[name] = patch_slide_part
        elif re.fullmatch(r"ppt/(notesMasters/notesMaster|notesSlides/notesSlide)\d+\.xml", name):
            # ノートはページサイズが別（notesSz）のためスケーリングしない
            patchers[name] = japanize_pptx_xml

    return patch_zip(default, patchers)


def build_pptx_from_potx(potx_path: Path) -> bytes:
    with zipfile.ZipFile(potx_path) as z:
        parts = {i.filename: z.read(i.filename) for i in z.infolist()}
        order = [i.filename for i in z.infolist()]

    # --- レイアウトの棚卸し（cSld name → パート番号） ---
    layout_name_to_num = {}
    for name in parts:
        m = re.fullmatch(r"ppt/slideLayouts/slideLayout(\d+)\.xml", name)
        if m:
            csld = re.search(r'<p:cSld name="([^"]*)"', parts[name].decode("utf-8"))
            layout_name_to_num.setdefault(csld.group(1) if csld else "", int(m.group(1)))

    keep = {}  # pandoc レイアウト名 -> パート番号
    for pd_name, src_name in PANDOC_LAYOUT_MAP.items():
        if src_name not in layout_name_to_num:
            fail(f"potx にレイアウト '{src_name}'（{pd_name} 用）が見つからない")
        keep[pd_name] = layout_name_to_num[src_name]

    def lpath(num):
        return f"ppt/slideLayouts/slideLayout{num}.xml"

    def lrels(num):
        return f"ppt/slideLayouts/_rels/slideLayout{num}.xml.rels"

    # --- 既存レイアウトの改名（pandoc が照合する英語標準名へ） ---
    for pd_name, num in keep.items():
        xml = parts[lpath(num)].decode("utf-8")
        xml = sub_checked(r'(<p:cSld name=")[^"]*(")', rf"\g<1>{pd_name}\g<2>",
                          xml, f"cSld name → {pd_name}", count=1)
        if pd_name == "Title Slide":
            # pandoc は Title Slide のタイトルを ctrTitle 型・サブタイトルを subTitle 型・
            # 日付を dt 型で探す（型が合わないと空の <p:sp/>（スキーマ違反）を出力する）
            def retype(m):
                s = m.group(0)
                if 'name="Subtitle"' in s:
                    s = s.replace('<p:ph type="body"', '<p:ph type="subTitle"', 1)
                elif 'name="Version+Date"' in s:
                    s = s.replace('<p:ph type="body"', '<p:ph type="dt"', 1)
                else:
                    s = s.replace('<p:ph type="title"', '<p:ph type="ctrTitle"', 1)
                return s
            xml = re.sub(r"<p:sp>.*?</p:sp>", retype, xml, flags=re.S)
            for needed in ('type="ctrTitle"', 'type="subTitle"', 'type="dt"'):
                if needed not in xml:
                    fail(f"Title Slide の ph 型変換に失敗: {needed} が作れなかった")
        parts[lpath(num)] = xml.encode("utf-8")

    # --- 不足レイアウトの合成（コンテンツベース） ---
    base_num = keep["Title and Content"]
    base_xml = parts[lpath(base_num)].decode("utf-8")
    content_sp = next((m.group(0) for m in _sp_blocks(base_xml)
                       if re.search(r'<p:ph[^>]*idx="1"[^>]*/>', m.group(0))), None)
    if content_sp is None:
        fail(f"'{SYNTH_BASE}' に idx=1 コンテンツ ph がない")
    geom = _sp_geometry(content_sp)
    next_num = max(int(re.fullmatch(r"ppt/slideLayouts/slideLayout(\d+)\.xml", n).group(1))
                   for n in parts if re.fullmatch(r"ppt/slideLayouts/slideLayout\d+\.xml", n)) + 1
    for pd_name, specs in _synth_specs(*geom).items():
        num = next_num
        next_num += 1
        parts[lpath(num)] = _synth_layout(base_xml, pd_name, specs).encode("utf-8")
        parts[lrels(num)] = parts[lrels(base_num)]  # 参照メディア・マスターは合成元と同じ
        order.extend([lpath(num), lrels(num)])
        keep[pd_name] = num

    keep_nums = set(keep.values())

    # --- マスターの参照整理（不要レイアウトの除去 + 合成レイアウトの登録） ---
    mrels_path = "ppt/slideMasters/_rels/slideMaster1.xml.rels"
    mxml_path = "ppt/slideMasters/slideMaster1.xml"
    mrels = parts[mrels_path].decode("utf-8")
    mxml = parts[mxml_path].decode("utf-8")

    removed_rids = []
    def drop_rel(m):
        rid, target = m.group(1), m.group(2)
        lm = re.search(r"slideLayout(\d+)\.xml$", target)
        if lm and int(lm.group(1)) not in keep_nums:
            removed_rids.append(rid)
            return ""
        return m.group(0)
    mrels = re.sub(r'<Relationship Id="(rId\d+)"[^>]*Target="([^"]*)"[^>]*/>', drop_rel, mrels)
    for rid in removed_rids:
        mxml = sub_checked(rf'<p:sldLayoutId id="\d+" r:id="{rid}"/>', "", mxml,
                           f"sldLayoutId {rid} の除去", count=1)

    next_rid = max(int(m.group(1)) for m in re.finditer(r'Id="rId(\d+)"', mrels)) + 1
    next_lid = max(int(m.group(1)) for m in re.finditer(r'<p:sldLayoutId id="(\d+)"', mxml)) + 1
    add_rels, add_lids = [], []
    for pd_name in _synth_specs(*geom):
        num = keep[pd_name]
        add_rels.append(
            f'<Relationship Id="rId{next_rid}" Type="http://schemas.openxmlformats.org/'
            f'officeDocument/2006/relationships/slideLayout" '
            f'Target="../slideLayouts/slideLayout{num}.xml"/>')
        add_lids.append(f'<p:sldLayoutId id="{next_lid}" r:id="rId{next_rid}"/>')
        next_rid += 1
        next_lid += 1
    mrels = sub_checked(r"</Relationships>", "".join(add_rels) + "</Relationships>",
                        mrels, "master rels への追加", count=1)
    mxml = sub_checked(r"</p:sldLayoutIdLst>", "".join(add_lids) + "</p:sldLayoutIdLst>",
                       mxml, "sldLayoutIdLst への追加", count=1)
    parts[mrels_path] = mrels.encode("utf-8")
    parts[mxml_path] = mxml.encode("utf-8")

    # --- 不要パートの削除（コアパートのホワイトリスト方式） ---
    # potx にはサンプルスライドの残骸（customXml / charts / diagrams / embeddings /
    # handoutMaster / authors / changesInfos 等）が含まれる。pandoc はこれらを出力へ
    # コピーしないのに presentation.xml.rels の参照は引き継ぐため、reference に残すと
    # 変換出力が宙に浮いた relationship を持ち PowerPoint の修復ダイアログを招く。
    core_re = re.compile(
        r"^(\[Content_Types\]\.xml|_rels/\.rels|docProps/.*|"
        r"ppt/(presentation\.xml|_rels/presentation\.xml\.rels|"
        r"slideMasters/.*|slideLayouts/.*|theme/.*|notesMasters/.*|media/.*|"
        r"presProps\.xml|viewProps\.xml|tableStyles\.xml))$")
    drop = set()
    for name in parts:
        if not core_re.fullmatch(name):
            drop.add(name)
            continue
        m = re.fullmatch(r"ppt/slideLayouts/(?:_rels/)?slideLayout(\d+)\.xml(?:\.rels)?", name)
        if m and int(m.group(1)) not in keep_nums:
            drop.add(name)
    for name in drop:
        del parts[name]

    # presentation.xml: 削除済みパート・スライドへの参照を残さない
    # （sldIdLst / handoutMasterIdLst / カスタムショー / extLst 内のセクション定義
    #   p14:sectionLst は削除済みスライド ID を指したままになるため丸ごと除去する）
    pres = parts["ppt/presentation.xml"].decode("utf-8")
    for tag in ("p:sldIdLst", "p:handoutMasterIdLst", "p:custShowLst",
                "p:custDataLst", "p:extLst"):
        pres = re.sub(rf"<{tag}>.*?</{tag}>", "", pres, flags=re.S)
    parts["ppt/presentation.xml"] = pres.encode("utf-8")

    # presentation.xml.rels: 実在しないパートへの relationship をすべて除去する
    def drop_dangling(m):
        attrs = dict(re.findall(r'(\w+)="([^"]*)"', m.group(1)))
        target = attrs.get("Target", "")
        if attrs.get("TargetMode") == "External" or target.startswith(("http", "file")):
            return m.group(0)
        return m.group(0) if _resolve("ppt", target) in parts else ""
    prels = parts["ppt/_rels/presentation.xml.rels"].decode("utf-8")
    prels = re.sub(r"<Relationship ([^>]*)/>", drop_dangling, prels)
    parts["ppt/_rels/presentation.xml.rels"] = prels.encode("utf-8")

    # --- 未参照メディアの削除（残存パートの .rels から到達可能なものだけ残す） ---
    referenced = set()
    for name, data in parts.items():
        if name.endswith(".rels"):
            base_dir = name.rsplit("/_rels/", 1)[0] if "/_rels/" in name else ""
            for t in re.findall(r'Target="([^"]*)"', data.decode("utf-8")):
                if not t.startswith(("http", "file")):
                    referenced.add(_resolve(base_dir, t))
    for name in [n for n in parts
                 if n.startswith("ppt/media/") and n not in referenced]:
        del parts[name]

    # --- [Content_Types].xml: potx→pptx 変換・削除パートの除去・合成レイアウトの登録 ---
    ct = parts["[Content_Types].xml"].decode("utf-8")
    ct = sub_checked("presentationml.template.main", "presentationml.presentation.main",
                     ct, "potx→pptx コンテンツタイプ", count=1)
    ct = re.sub(r'<Override PartName="([^"]*)"[^>]*/>',
                lambda m: m.group(0) if m.group(1).lstrip("/") in parts else "", ct)
    adds = "".join(
        f'<Override PartName="/{lpath(keep[n])}" ContentType='
        f'"application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>'
        for n in _synth_specs(*geom))
    ct = sub_checked(r"</Types>", adds + "</Types>", ct, "Content_Types への追加", count=1)
    parts["[Content_Types].xml"] = ct.encode("utf-8")

    # docProps/app.xml は削除済みパートへの参照（スライドタイトル一覧等）が残るため最小化
    if "docProps/app.xml" in parts:
        parts["docProps/app.xml"] = (
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/'
            'extended-properties"><Application>Microsoft PowerPoint</Application></Properties>'
        ).encode("utf-8")

    _verify_package(parts)

    # --- zip 再構築（元の並びを維持し、[Content_Types].xml を先頭に） ---
    out = io.BytesIO()
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zout:
        for name in order:
            if name in parts:
                zout.writestr(name, parts[name])
    return out.getvalue()


def docx_style_overrides(theme: dict):
    """日本語文書向けに再定義する段落・文字・表スタイル（ブロック完全置換）と新規追加スタイル。

    OOXML は要素の並び順が厳格（CT_PPr / CT_RPr / CT_TblPrBase のシーケンス）なため、
    部分挿入ではなく <w:style> ブロックごと置き換える。
    """
    dk2 = theme["colors"]["dk2"]        # 基調色（見出し・表ヘッダー）
    lt2 = theme["colors"]["lt2"]        # 淡色（引用の罫線）
    acc2 = theme["colors"]["accent2"]   # 表の外枠
    hlink = theme["colors"]["hlink"]
    gray_text = "595959"                # 補足系文字色
    gray_line = "D8D8D8"                # 表の内側罫線

    replacements = {
        # 本文: 両端揃え（日本語ビジネス文書の標準）
        "BodyText": f'''<w:style w:type="paragraph" w:styleId="BodyText">
  <w:name w:val="Body Text" /><w:basedOn w:val="Normal" /><w:link w:val="BodyTextChar" /><w:qFormat />
  <w:pPr><w:spacing w:before="180" w:after="180" /><w:jc w:val="both" /></w:pPr>
</w:style>''',
        # 文書タイトル: 基調色
        "Title": f'''<w:style w:type="paragraph" w:styleId="Title">
  <w:name w:val="Title" /><w:basedOn w:val="Normal" /><w:next w:val="BodyText" /><w:link w:val="TitleChar" />
  <w:uiPriority w:val="10" /><w:qFormat />
  <w:pPr><w:spacing w:after="80" w:line="240" w:lineRule="auto" /><w:contextualSpacing /><w:jc w:val="center" /></w:pPr>
  <w:rPr><w:rFonts w:asciiTheme="majorHAnsi" w:eastAsiaTheme="majorEastAsia" w:hAnsiTheme="majorHAnsi" w:cstheme="majorBidi" /><w:color w:val="{dk2}" /><w:sz w:val="56" /><w:szCs w:val="56" /></w:rPr>
</w:style>''',
        # サブタイトル: グレー
        "Subtitle": f'''<w:style w:type="paragraph" w:styleId="Subtitle">
  <w:name w:val="Subtitle" /><w:basedOn w:val="Title" /><w:next w:val="BodyText" /><w:link w:val="SubtitleChar" />
  <w:uiPriority w:val="11" /><w:qFormat />
  <w:pPr><w:numPr><w:ilvl w:val="1" /></w:numPr></w:pPr>
  <w:rPr><w:rFonts w:eastAsiaTheme="majorEastAsia" w:cstheme="majorBidi" /><w:color w:val="{gray_text}" /><w:spacing w:val="15" /><w:sz w:val="28" /><w:szCs w:val="28" /></w:rPr>
</w:style>''',
        # 引用: 左罫線 + グレー文字（日本語では斜体を使わない）
        "BlockText": f'''<w:style w:type="paragraph" w:styleId="BlockText">
  <w:name w:val="Block Text" /><w:basedOn w:val="BodyText" /><w:next w:val="BodyText" />
  <w:uiPriority w:val="9" /><w:unhideWhenUsed /><w:qFormat />
  <w:pPr><w:pBdr><w:left w:val="single" w:sz="18" w:space="8" w:color="{lt2}" /></w:pBdr><w:spacing w:before="100" w:after="100" /><w:ind w:firstLine="0" w:left="480" w:right="480" /></w:pPr>
  <w:rPr><w:color w:val="{gray_text}" /></w:rPr>
</w:style>''',
        # キャプション共通: 斜体をやめ、グレー 9pt（Table/Image Caption は basedOn で継承）
        "Caption": f'''<w:style w:type="paragraph" w:styleId="Caption">
  <w:name w:val="Caption" /><w:basedOn w:val="Normal" /><w:link w:val="BodyTextChar" />
  <w:pPr><w:spacing w:before="0" w:after="120" /></w:pPr>
  <w:rPr><w:color w:val="{gray_text}" /><w:sz w:val="18" /><w:szCs w:val="18" /></w:rPr>
</w:style>''',
        # 脚注: 9pt
        "FootnoteText": '''<w:style w:type="paragraph" w:styleId="FootnoteText">
  <w:name w:val="Footnote Text" /><w:basedOn w:val="Normal" /><w:next w:val="FootnoteText" />
  <w:uiPriority w:val="9" /><w:unhideWhenUsed /><w:qFormat />
  <w:rPr><w:sz w:val="18" /><w:szCs w:val="18" /></w:rPr>
</w:style>''',
        # ハイパーリンク: テーマの hlink 色 + 下線
        "Hyperlink": f'''<w:style w:type="character" w:styleId="Hyperlink">
  <w:name w:val="Hyperlink" /><w:basedOn w:val="BodyTextChar" />
  <w:rPr><w:color w:val="{hlink}" /><w:u w:val="single" /></w:rPr>
</w:style>''',
        # インラインコード: 等幅（欧文 + 日本語）+ 薄灰背景
        "VerbatimChar": f'''<w:style w:type="character" w:customStyle="1" w:styleId="VerbatimChar">
  <w:name w:val="Verbatim Char" /><w:basedOn w:val="BodyTextChar" />
  <w:rPr><w:rFonts w:ascii="{CODE_LATIN}" w:eastAsia="{CODE_EA}" w:hAnsi="{CODE_LATIN}" w:cs="{CODE_LATIN}" /><w:sz w:val="20" /><w:szCs w:val="20" /><w:shd w:val="clear" w:color="auto" w:fill="F2F2F2" /></w:rPr>
</w:style>''',
        # 表: ヘッダー行 = 基調色地に白字太字、外枠 accent2・内側は薄灰罫線
        "Table": f'''<w:style w:type="table" w:default="1" w:styleId="Table">
  <w:name w:val="Table" /><w:basedOn w:val="TableNormal" /><w:semiHidden /><w:unhideWhenUsed /><w:qFormat />
  <w:tblPr>
    <w:tblInd w:w="0" w:type="dxa" />
    <w:tblBorders><w:top w:val="single" w:sz="6" w:space="0" w:color="{acc2}" /><w:bottom w:val="single" w:sz="6" w:space="0" w:color="{acc2}" /><w:insideH w:val="single" w:sz="4" w:space="0" w:color="{gray_line}" /></w:tblBorders>
    <w:tblCellMar><w:top w:w="40" w:type="dxa" /><w:left w:w="108" w:type="dxa" /><w:bottom w:w="40" w:type="dxa" /><w:right w:w="108" w:type="dxa" /></w:tblCellMar>
  </w:tblPr>
  <w:tblStylePr w:type="firstRow">
    <w:rPr><w:b /><w:color w:val="FFFFFF" /></w:rPr>
    <w:tcPr><w:tcBorders><w:bottom w:val="single" w:sz="6" w:space="0" w:color="{dk2}" /></w:tcBorders><w:shd w:val="clear" w:color="auto" w:fill="{dk2}" /><w:vAlign w:val="center" /></w:tcPr>
  </w:tblStylePr>
</w:style>''',
    }

    additions = [
        # コードブロック（pandoc は "Source Code" 段落スタイルを使用するがデフォルトには未定義）
        f'''<w:style w:type="paragraph" w:customStyle="1" w:styleId="SourceCode">
  <w:name w:val="Source Code" /><w:basedOn w:val="Normal" />
  <w:pPr>
    <w:keepLines />
    <w:pBdr><w:top w:val="single" w:sz="4" w:space="4" w:color="{gray_line}" /><w:left w:val="single" w:sz="4" w:space="4" w:color="{gray_line}" /><w:bottom w:val="single" w:sz="4" w:space="4" w:color="{gray_line}" /><w:right w:val="single" w:sz="4" w:space="4" w:color="{gray_line}" /></w:pBdr>
    <w:shd w:val="clear" w:color="auto" w:fill="F7F7F7" />
    <w:spacing w:before="120" w:after="120" w:line="240" w:lineRule="auto" />
    <w:jc w:val="left" />
  </w:pPr>
  <w:rPr><w:rFonts w:ascii="{CODE_LATIN}" w:eastAsia="{CODE_EA}" w:hAnsi="{CODE_LATIN}" w:cs="{CODE_LATIN}" /><w:sz w:val="18" /><w:szCs w:val="18" /></w:rPr>
</w:style>''',
    ]
    return replacements, additions


def build_docx(theme: dict) -> bytes:
    heading_hex = theme["colors"]["dk2"]

    def patch_styles(xml):
        # themeColor="accent1" 参照の見出し・タイトル色を dk2 直接指定に置換
        xml = sub_checked(
            r'<w:color [^>]*w:themeColor="accent1"[^>]*/>',
            f'<w:color w:val="{heading_hex}" />',
            xml, "heading colors (accent1)")
        # 既定の東アジア言語を日本語にする
        xml = re.sub(r'(<w:lang [^>]*w:eastAsia=")[^"]*(")', r"\g<1>ja-JP\g<2>", xml)
        # 日本語文書向けスタイルのブロック置換と追加
        replacements, additions = docx_style_overrides(theme)
        for sid, block in replacements.items():
            xml = sub_checked(
                rf'<w:style [^>]*w:styleId="{sid}">.*?</w:style>',
                block.replace("\\", "\\\\"),
                xml, f"style {sid}", count=1, flags=re.S)
        for block in additions:
            xml = sub_checked(
                r"</w:styles>",
                block.replace("\\", "\\\\") + "</w:styles>",
                xml, "styles 末尾への追加", count=1)
        return xml

    def japanize_docx_samples(xml):
        # スタイル見本の英語サンプル本文を日本語化（<w:t> ノード単位の完全一致）
        for en, ja in DOCX_JP_SAMPLES:
            xml = xml.replace(f">{en}</w:t>", f">{ja}</w:t>")
        # 同一文字列の繰り返しには出現順に別の訳語を割り当てる
        for en, ja_list in DOCX_JP_SAMPLES_SEQ:
            for ja in ja_list:
                xml = xml.replace(f">{en}</w:t>", f">{ja}</w:t>", 1)
        return xml

    def patch_document(xml):
        # pandoc デフォルトの sectPr に pgSz は無い（無指定だと Letter で出力される）ため、
        # 既存があれば置換、無ければ sectPr 末尾（CT_SectPr の並び順で footnotePr の後）に挿入する
        if re.search(r"<w:pgSz[^>]*/>", xml):
            xml = sub_checked(r"<w:pgSz[^>]*/>", A4_PGSZ, xml, "pgSz", count=1)
        else:
            xml = sub_checked(
                r"(</w:footnotePr>\s*)(</w:sectPr>)",
                rf"\g<1>{A4_PGSZ}{A4_PGMAR}\g<2>",
                xml, "pgSz 挿入位置（sectPr）", count=1, flags=re.S)
        return japanize_docx_samples(xml)

    def patch_settings(xml):
        # テーマフォントの東アジア言語を日本語にする（Word が日本語本文に minorEastAsia を使う）
        return sub_checked(
            r"<w:themeFontLang [^>]*/>",
            '<w:themeFontLang w:val="en-US" w:eastAsia="ja-JP" />',
            xml, "themeFontLang", count=1)

    return patch_zip(pandoc_default("reference.docx"), {
        "word/theme/theme1.xml": lambda x: patch_theme_xml(x, theme),
        "word/styles.xml": patch_styles,
        "word/document.xml": patch_document,
        "word/footnotes.xml": japanize_docx_samples,
        "word/settings.xml": patch_settings,
    })


def build_theme(theme_dir: Path):
    """1 テーマ分の reference.docx / reference.pptx を生成する"""
    theme_path = theme_dir / "theme.json"
    if not theme_path.exists():
        fail(f"{theme_path} がありません。先に extract_potx_theme.py を実行してください。")
    theme = json.loads(theme_path.read_text(encoding="utf-8"))

    # pptx: theme.json の _source（potx）を基底に構築。_source を持たないテーマは
    # pandoc デフォルト reference へのテーマ移植方式（フォールバック）で生成する
    src = theme.get("_source", "")
    if src:
        potx = Path(src)
        if not potx.is_absolute():
            potx = DIR.parents[3] / potx  # _source はリポジトリルート相対
        if not potx.exists():
            fail(f"[{theme_dir.name}] 基底 potx が見つからない: {potx}\n"
                 "theme.json の _source を確認するか、extract_potx_theme.py を再実行してください。")
        (theme_dir / "reference.pptx").write_bytes(build_pptx_from_potx(potx))
        print(f"OK: {theme_dir / 'reference.pptx'} (基底: {potx.name})")
    else:
        (theme_dir / "reference.pptx").write_bytes(build_pptx_transplant(theme))
        print(f"OK: {theme_dir / 'reference.pptx'} (テーマ移植方式)")

    (theme_dir / "reference.docx").write_bytes(build_docx(theme))
    print(f"OK: {theme_dir / 'reference.docx'}")


def main():
    parser = argparse.ArgumentParser(description="pandoc reference-doc テンプレートの生成")
    parser.add_argument("--theme", default=None,
                        help="生成対象のテーマ名（themes/ 配下のディレクトリ名）。省略時は全テーマ")
    args = parser.parse_args()

    themes_dir = DIR / "themes"
    if args.theme:
        targets = [themes_dir / args.theme]
        if not targets[0].is_dir():
            available = sorted(p.name for p in themes_dir.iterdir() if p.is_dir())
            fail(f"テーマ '{args.theme}' がありません。利用可能: {available}")
    else:
        targets = sorted(p for p in themes_dir.iterdir()
                         if p.is_dir() and (p / "theme.json").exists())
        if not targets:
            fail(f"{themes_dir} にテーマがありません。")

    for theme_dir in targets:
        build_theme(theme_dir)


if __name__ == "__main__":
    main()
