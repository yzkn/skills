#!/usr/bin/env python3
"""クロスツール検証: 一次変換の出力を、**別ツール**で再変換した結果と突き合わせる。

規約: `.claude/skills/office/SKILL.md`「変換の検証（クロスツール検証）」
同一ツールの再実行は同じ欠落を同じように再現するため検証にならない。本スクリプトは
一次変換に使ったエンジンと検証エンジンが一致する場合、実行せずエラー終了する。

使い方:
    # 正方向（Office/PDF → Markdown）: 原本と一次変換の md を渡す
    python verify_conversion.py <原本> <一次変換.md>

    # 往復（Markdown 正本 → docx/pptx）: 生成物と正本 md を渡す
    python verify_conversion.py <生成物.docx> <正本.md> --mode roundtrip

主なオプション:
    --primary-engine  一次変換のエンジン（既定 auto: md 冒頭の read_document コメントから推定）
    --verify-engine   検証エンジン（既定 auto: 原本の形式から選択。一次と異なるものを選ぶ）。
                      カンマ区切りで複数指定すると全エンジンで照合する（例: openpyxl,anytomd）
    --out-dir         検証出力の保存先（既定: 一時ディレクトリ。成果物ディレクトリを指定しない）
    --json            指標を JSON で出力する

終了コード:
    0 = 差分なし / 1 = 差分あり（ユーザーに報告して採用方針を確認する） / 2 = 実行不能
    複数の検証エンジンを指定した場合は、1 つでも差分があれば 1、1 つでも実行不能なら 2。
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from datetime import date
from pathlib import Path

RATIO_MIN = 0.9   # 正方向: 正規化後の本文文字数比の下限
RATIO_MAX = 1.1   # 正方向: 同上限
RT_RATIO_MIN = 0.8  # 往復: 目次・スライド分割で増減するため広くとる
RT_RATIO_MAX = 1.3
TOKEN_SAMPLE = 10  # 報告するトークン差分のサンプル数

# 原本形式 → 検証エンジンの既定（pandoc は xlsx / pptx / pdf を入力として読めない）
DEFAULT_VERIFY = {
    ".docx": "pandoc",
    ".csv": "pandoc",
    ".xlsx": "openpyxl",
    ".xlsm": "openpyxl",
    ".pptx": "python-pptx",
    ".pdf": "pdftotext",
}
# 低レベルパーサを markitdown と共有するため、パーサ由来の欠落は検出できないエンジン
# （markitdown も内部で openpyxl / python-pptx を使う。anydoc・anytomd は Rust 実装で共有しない）
SHARED_PARSER = {"openpyxl", "python-pptx"}
SHARED_PARSER_PRIMARIES = {"markitdown"}  # 上記の制約が問題になる一次エンジン
# anytomd が読めない形式（PDF は対象外）
ANYTOMD_UNSUPPORTED = {".pdf"}
PLAIN_TEXT_ENGINES = {"pdftotext"}  # Markdown 記法を持たない出力（表・見出し指標は対象外）


def _init_stdout():
    """stdout / stderr を UTF-8 固定にする（Windows の既定 cp932 では報告が化ける）。"""
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", newline="\n")
        except Exception:
            pass


def read_text(path: Path) -> str:
    """UTF-8 優先で読み、失敗時は cp932 → 置換の順にフォールバックする。改行は LF に正規化する。

    Windows でリダイレクト保存された変換結果には `\\r\\r\\n` が混入することがあり、
    正規化しないと表の各行が空行で分断されて表の個数を誤検出する。
    """
    data = path.read_bytes()
    text = None
    for enc in ("utf-8", "cp932"):
        try:
            text = data.decode(enc)
            break
        except UnicodeDecodeError:
            continue
    if text is None:
        print(f"WARNING: {path.name} の文字コードを判定できず置換復号しました。", file=sys.stderr)
        text = data.decode("utf-8", errors="replace")
    if "\r\r\n" in text:
        print(f"WARNING: {path.name} に \\r\\r\\n が含まれます（Windows のリダイレクト保存による改行の二重変換）。"
              "比較のため正規化しますが、保存済みファイルの改行修正を検討してください。", file=sys.stderr)
    return text.replace("\r\r\n", "\n").replace("\r\n", "\n").replace("\r", "\n")


def detect_primary_engine(md: str) -> str:
    """一次変換の md 冒頭コメントからエンジンを推定する。判定できない場合は unknown。"""
    m = re.search(r"<!--\s*read_document:\s*engine=([a-zA-Z0-9_-]+)", md)
    return m.group(1) if m else "unknown"


# --- 検証側の再変換 ---------------------------------------------------------

def run(cmd: list, **kw) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, **kw)


def verify_pandoc(src: Path, out: Path) -> Path:
    fmt = "csv" if src.suffix.lower() == ".csv" else "docx"
    r = run(["pandoc", "-f", fmt, "-t", "gfm", "--wrap=none", str(src), "-o", str(out)])
    if r.returncode != 0:
        die(f"pandoc の実行に失敗しました: {r.stderr.decode('utf-8', 'replace')[:300]}")
    return out


def verify_pdftotext(src: Path, out: Path) -> Path:
    out = out.with_suffix(".txt")
    r = run(["pdftotext", "-layout", str(src), str(out)])
    if r.returncode != 0:
        die(f"pdftotext の実行に失敗しました: {r.stderr.decode('utf-8', 'replace')[:300]}")
    return out


def verify_read_document(src: Path, out: Path, engine: str) -> Path:
    """read_document.py をエンジン固定で実行する（anydoc / markitdown / docling / anytomd）。"""
    script = Path(__file__).with_name("read_document.py")
    env = {**os.environ, "PYTHONUTF8": "1", "PYTHONIOENCODING": "utf-8"}
    r = run([sys.executable, str(script), str(src), "--force-engine", engine], env=env)
    if r.returncode != 0:
        die(f"{engine} での再変換に失敗しました: {r.stderr.decode('utf-8', 'replace')[:300]}")
    out.write_text(r.stdout.decode("utf-8", "replace"), encoding="utf-8")
    return out


def verify_openpyxl(src: Path, out: Path) -> Path:
    """openpyxl でシート単位に Markdown 表を組み立てる（非表示シートも含める）。"""
    try:
        import openpyxl
    except ImportError:
        die("openpyxl が未導入です（pip install openpyxl）。")
    wb = openpyxl.load_workbook(str(src), read_only=True, data_only=True)
    lines = []
    for ws in wb.worksheets:
        lines.append(f"## {ws.title}\n")
        if ws.sheet_state != "visible":
            # 非表示の注記はコメントで出す（本文文字数の指標に影響させない）
            lines.append(f"<!-- sheet_state: {ws.sheet_state} -->")
        rows = [[("" if v is None else str(v)) for v in row] for row in ws.iter_rows(values_only=True)]
        rows = [r for r in rows if any(c.strip() for c in r)]
        if rows:
            width = max(len(r) for r in rows)
            lines.append("| " + " | ".join(rows[0] + [""] * (width - len(rows[0]))) + " |")
            lines.append("|" + "---|" * width)
            for r in rows[1:]:
                lines.append("| " + " | ".join(r + [""] * (width - len(r))) + " |")
        lines.append("")
    out.write_text("\n".join(lines), encoding="utf-8")
    return out


def verify_python_pptx(src: Path, out: Path) -> Path:
    """python-pptx でスライド単位にテキスト・表・ノートを組み立てる。"""
    try:
        from pptx import Presentation
    except ImportError:
        die("python-pptx が未導入です（pip install python-pptx）。")
    prs = Presentation(str(src))
    lines = []
    for i, slide in enumerate(prs.slides, 1):
        # スライド番号はコメントで出す（見出し・本文文字数の指標を markitdown 側と揃えるため）
        lines.append(f"<!-- Slide number: {i} -->")
        title = slide.shapes.title
        # python-pptx は都度ラッパーを生成するため識別は shape_id で行う（`is` では一致しない）
        title_id = title.shape_id if title is not None else None
        if title is not None and title.text_frame.text.strip():
            lines.append(f"# {title.text_frame.text.strip()}")
        for shape in slide.shapes:
            if shape.shape_id == title_id:
                continue
            if shape.has_text_frame and shape.text_frame.text.strip():
                lines.append(shape.text_frame.text)
            if shape.has_table:
                lines.extend(_pptx_table_lines(shape.table))
        if slide.has_notes_slide and slide.notes_slide.notes_text_frame.text.strip():
            lines.append(f"<!-- notes: {slide.notes_slide.notes_text_frame.text} -->")
        lines.append("")
    out.write_text("\n".join(lines), encoding="utf-8")
    return out


def _pptx_table_lines(table) -> list:
    rows = [[c.text.replace("\n", " ") for c in row.cells] for row in table.rows]
    if not rows:
        return []
    out = ["| " + " | ".join(rows[0]) + " |", "|" + "---|" * len(rows[0])]
    out += ["| " + " | ".join(r) + " |" for r in rows[1:]]
    return out


VERIFIERS = {
    "pandoc": verify_pandoc,
    "pdftotext": verify_pdftotext,
    "openpyxl": verify_openpyxl,
    "python-pptx": verify_python_pptx,
    "anydoc": lambda s, o: verify_read_document(s, o, "anydoc"),
    "markitdown": lambda s, o: verify_read_document(s, o, "markitdown"),
    "docling": lambda s, o: verify_read_document(s, o, "docling"),
    "anytomd": lambda s, o: verify_read_document(s, o, "anytomd"),
}


# --- 指標 -------------------------------------------------------------------

SEP_ROW = re.compile(r"^[\s|:\-]+$")
MARKUP = re.compile(r"[|#*`_>\-]")
TOKEN_PATTERNS = [
    r"\d{4}-\d{2}-\d{2}", r"\d{4}/\d{1,2}/\d{1,2}", r"\d+年\d+月(?:\d+日)?",
    r"\d{1,3}(?:,\d{3})+", r"\d+(?:\.\d+)?%",
]


def normalized_len(text: str) -> int:
    """記法差の影響を除いた本文文字数。HTML コメント・表区切り行・記法文字・空白を除去する。"""
    t = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    t = "\n".join(l for l in t.splitlines() if not SEP_ROW.fullmatch(l))
    return len("".join(MARKUP.sub("", t).split()))


def headings(text: str) -> list:
    return [l.lstrip("#").strip() for l in text.splitlines() if l.startswith("#")]


def tables(text: str) -> list:
    """連続する `|` 行を 1 表として (行数, 列数) を返す。"""
    result, rows, cols = [], 0, 0
    for line in text.splitlines() + [""]:
        s = line.strip()
        if s.startswith("|"):
            if not SEP_ROW.fullmatch(s):
                rows += 1
                cols = max(cols, max(0, s.count("|") - 1))
            continue
        if rows:
            result.append((rows, cols))
        rows, cols = 0, 0
    return result


def tokens(text: str) -> set:
    found = set()
    for pat in TOKEN_PATTERNS:
        found.update(re.findall(pat, text))
    return found


# エンジン固有のラベル。内容ではない表記差で見出し数・文字数比がずれるため、照合前に除く
# （実測: 同一 pptx で anytomd は「## Slide 1: タイトル」「> Note: …」、markitdown はノートを「### Notes:」見出しにする）
ENGINE_LABELS = {
    "anytomd": [
        (re.compile(r"(?m)^(#{1,6} )Slide \d+: "), r"\1"),
        (re.compile(r"(?m)^#{1,6} Slide \d+\s*$"), ""),  # タイトルの無いスライド
        (re.compile(r"(?m)^> Note: "), "> "),
    ],
    "markitdown": [
        (re.compile(r"(?m)^#{1,6} Notes:\s*$"), ""),
    ],
}


def strip_engine_labels(text: str, engine: str) -> str:
    for pattern, repl in ENGINE_LABELS.get(engine, []):
        text = pattern.sub(repl, text)
    return text


def squash(text: str) -> str:
    """記法文字と空白を除いた比較用の文字列（見出しの残存確認に使う）。"""
    t = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    return "".join(MARKUP.sub("", t).split())


def collect(text: str) -> dict:
    tbl = tables(text)
    return {
        "見出し数": len(headings(text)),
        "見出し": headings(text),
        "表の個数": len(tbl),
        "表の総行数": sum(r for r, _ in tbl),
        "本文文字数": normalized_len(text),
        "トークン": tokens(text),
        "本文": squash(text),
    }


# --- 判定 -------------------------------------------------------------------

def judge_forward(a: dict, b: dict, plain: bool, rmin: float, rmax: float) -> list:
    """正方向: 構造が一致することを求める。差分の説明文リストを返す（空なら差分なし）。"""
    diffs = []
    if not plain:
        for key in ("見出し数", "表の個数", "表の総行数"):
            if a[key] != b[key]:
                diffs.append(f"{key}が不一致（一次 {a[key]} / 検証 {b[key]}）")
    diffs += _judge_ratio(a, b, rmin, rmax)
    diffs += _judge_tokens(a, b)
    return diffs


def judge_roundtrip(a: dict, b: dict, plain: bool, rmin: float, rmax: float) -> list:
    """往復: 正本(a)の見出し・トークンが再変換結果(b)に残っていることを求める。"""
    diffs = []
    lost = [h for h in a["見出し"] if h and squash(h) not in b["本文"]]
    if lost:
        diffs.append(f"正本の見出しが再変換結果に見つからない: {lost[:TOKEN_SAMPLE]}")
    if not plain and a["表の総行数"] > b["表の総行数"]:
        diffs.append(f"表の総行数が減っている（正本 {a['表の総行数']} / 再変換 {b['表の総行数']}）")
    diffs += _judge_ratio(a, b, rmin, rmax)
    diffs += _judge_tokens(a, b, one_way=True)
    return diffs


def _judge_ratio(a: dict, b: dict, rmin: float, rmax: float) -> list:
    if b["本文文字数"] == 0:
        return ["検証側の本文文字数が 0（再変換に失敗した可能性）"]
    ratio = a["本文文字数"] / b["本文文字数"]
    if not rmin <= ratio <= rmax:
        return [f"本文文字数比が範囲外（{ratio:.3f} / 許容 {rmin}〜{rmax}）"]
    return []


def _judge_tokens(a: dict, b: dict, one_way: bool = False) -> list:
    diffs = []
    only_a = sorted(a["トークン"] - b["トークン"])
    only_b = sorted(b["トークン"] - a["トークン"])
    if only_a:
        diffs.append(f"一次にあり検証にない数値・日付: {only_a[:TOKEN_SAMPLE]}")
    if only_b and not one_way:
        diffs.append(f"検証にあり一次にない数値・日付: {only_b[:TOKEN_SAMPLE]}")
    return diffs


# --- 出力 -------------------------------------------------------------------

def die(msg: str):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(2)


def pandoc_version() -> str:
    r = run(["pandoc", "--version"])
    if r.returncode != 0:
        return "pandoc"
    return r.stdout.decode("utf-8", "replace").splitlines()[0].strip()


def report(args, primary_engine, verify_label, verify_path, a, b, plain, diffs):
    ratio = a["本文文字数"] / b["本文文字数"] if b["本文文字数"] else 0
    print(f"# クロスツール検証: {Path(args.source).name}（モード: {args.mode}）")
    print(f"変換(一次): {primary_engine}  /  検証: {verify_label}")
    print(f"検証出力: {verify_path}")
    print()
    print(f"{'指標':<20}{'一次':>10}{'検証':>10}")
    for key in ("見出し数", "表の個数", "表の総行数", "本文文字数"):
        mark = "（対象外）" if plain and key != "本文文字数" else ""
        print(f"{key:<20}{a[key]:>10}{b[key]:>10} {mark}")
    print(f"{'トークン数':<20}{len(a['トークン']):>10}{len(b['トークン']):>10}")
    print(f"{'本文文字数比':<20}{ratio:>10.3f}")
    print()
    if diffs:
        print("判定: 差分あり（独断でどちらかを採用せず、ユーザーに報告して採用方針を確認する）")
        for d in diffs:
            print(f"  - {d}")
    else:
        print("判定: 差分なし")
        print(f"注記: <!-- 変換: {primary_engine} / 検証: {verify_label}"
              f"（{date.today().isoformat()}・差分なし） -->")


def anydoc_installed() -> bool:
    """anydoc CLI が使えるか（グローバルインストール済みか）。"""
    from shutil import which
    return which("anydoc") is not None


def anytomd_installed() -> bool:
    """anytomd CLI が使えるか（PATH または ~/.cargo/bin）。判定は read_document.py と共有する。"""
    sys.path.insert(0, str(Path(__file__).parent))
    from read_document import _anytomd_command
    return _anytomd_command() is not None


def fallback_verify_engine(primary_engine: str, ext: str) -> str:
    """既定の検証エンジンが一次と同じだったときの退避先を選ぶ。

    独立実装（Rust）の anydoc・anytomd を優先し、未導入なら markitdown、PDF で
    どちらも使えない場合は Docling に退避する。
    """
    for cand in ("anydoc", "anytomd", "markitdown", "docling"):
        if cand == primary_engine:
            continue
        if cand == "anydoc" and not anydoc_installed():
            continue
        if cand == "anytomd" and (ext in ANYTOMD_UNSUPPORTED or not anytomd_installed()):
            continue
        return cand
    return "docling" if ext == ".pdf" else "markitdown"


def auto_verify_engine(args, primary_engine: str, ext: str) -> str:
    if args.mode == "roundtrip":
        # pandoc で生成した docx / pptx を別ツールで読み戻す。Rust 実装が使えればそちらを優先する。
        if anydoc_installed():
            return "anydoc"
        return "anytomd" if anytomd_installed() else "markitdown"
    engine = DEFAULT_VERIFY.get(ext)
    if engine is None:
        die(f"検証エンジンを自動選択できない形式です: {ext}（--verify-engine で指定してください）")
    if engine == primary_engine:  # 一次と同じなら別ツールへ退避
        return fallback_verify_engine(primary_engine, ext)
    # markitdown 一次の xlsx / pptx は、パーサを共有しない anytomd を優先する
    if engine in SHARED_PARSER and primary_engine in SHARED_PARSER_PRIMARIES and anytomd_installed():
        return "anytomd"
    return engine


def select_verify_engines(args, primary_engine: str) -> list:
    ext = Path(args.source).suffix.lower()
    if args.verify_engine == "auto":
        engines = [auto_verify_engine(args, primary_engine, ext)]
    else:
        engines = list(dict.fromkeys(e.strip() for e in args.verify_engine.split(",") if e.strip()))
        if not engines:
            die("--verify-engine に検証エンジンを指定してください。")
    for engine in engines:
        if engine == primary_engine:
            die(f"一次変換と検証で同じツール（{engine}）は使えません。別ツールを --verify-engine で指定してください。")
        if engine not in VERIFIERS:
            die(f"未知の検証エンジンです: {engine}")
        if engine == "anytomd" and ext in ANYTOMD_UNSUPPORTED:
            die(f"anytomd は {ext} を読めません。別の検証エンジンを指定してください。")
    return engines


def main():
    _init_stdout()
    ap = argparse.ArgumentParser(description="変換結果を別ツールで再変換して突き合わせる")
    ap.add_argument("source", help="原本（正方向）または生成物（往復モード）")
    ap.add_argument("primary", help="一次変換の出力 md（往復モードでは Markdown 正本）")
    ap.add_argument("--mode", choices=["forward", "roundtrip"], default="forward")
    ap.add_argument("--primary-engine", default="auto",
                    help="auto / anydoc / markitdown / docling / pandoc など")
    ap.add_argument("--verify-engine", default="auto",
                    help=f"auto または {', '.join(VERIFIERS)}（カンマ区切りで複数指定可）")
    ap.add_argument("--out-dir", help="検証出力の保存先（既定: 一時ディレクトリ）")
    ap.add_argument("--ratio-min", type=float)
    ap.add_argument("--ratio-max", type=float)
    ap.add_argument("--json", action="store_true", help="指標を JSON で出力する")
    args = ap.parse_args()

    src, primary_path = Path(args.source), Path(args.primary)
    for p in (src, primary_path):
        if not p.exists():
            die(f"ファイルが存在しません: {p}")

    primary_text = read_text(primary_path)
    primary_engine = args.primary_engine
    if primary_engine == "auto":
        primary_engine = "pandoc" if args.mode == "roundtrip" else detect_primary_engine(primary_text)
        if primary_engine == "unknown":
            die("一次変換のエンジンを判定できません（--primary-engine で明示してください）。"
                "read_document.py の出力なら冒頭に engine コメントが付きます。")

    verify_engines = select_verify_engines(args, primary_engine)
    for engine in verify_engines:
        if engine in SHARED_PARSER and primary_engine in SHARED_PARSER_PRIMARIES:
            print(f"INFO: {engine} は markitdown と低レベルパーサを共有します。"
                  "パーサ由来の欠落は検出できません（独立した検証には --verify-engine anytomd、"
                  "または LibreOffice headless で csv/txt に変換して照合してください）。", file=sys.stderr)
        if engine == "anytomd" and primary_engine == "anydoc":
            print("INFO: anytomd は anydoc と ZIP 展開・XML 字句解析のクレート（zip / quick-xml）を共有します。"
                  "本文の解釈は別実装ですが、最下層に起因する欠落は検出できません。", file=sys.stderr)

    out_dir = Path(args.out_dir) if args.out_dir else Path(tempfile.mkdtemp(prefix="verify_conversion_"))
    out_dir.mkdir(parents=True, exist_ok=True)
    default_range = (RT_RATIO_MIN, RT_RATIO_MAX) if args.mode == "roundtrip" else (RATIO_MIN, RATIO_MAX)
    rmin = args.ratio_min if args.ratio_min is not None else default_range[0]
    rmax = args.ratio_max if args.ratio_max is not None else default_range[1]
    judge = judge_roundtrip if args.mode == "roundtrip" else judge_forward
    a = collect(strip_engine_labels(primary_text, primary_engine))

    payloads, any_diff = [], False
    for i, engine in enumerate(verify_engines):
        verify_path = VERIFIERS[engine](src, out_dir / f"verify_{engine}.md")
        b = collect(strip_engine_labels(read_text(verify_path), engine))
        verify_label = pandoc_version() if engine == "pandoc" else engine
        plain = engine in PLAIN_TEXT_ENGINES
        diffs = judge(a, b, plain, rmin, rmax)
        any_diff = any_diff or bool(diffs)
        if args.json:
            payloads.append({
                "source": str(src), "mode": args.mode,
                "primary_engine": primary_engine, "verify_engine": verify_label,
                "verify_output": str(verify_path),
                "primary": {k: v for k, v in a.items() if k not in ("トークン", "見出し", "本文")},
                "verify": {k: v for k, v in b.items() if k not in ("トークン", "見出し", "本文")},
                "diffs": diffs,
            })
        else:
            if i:
                print()
            report(args, primary_engine, verify_label, verify_path, a, b, plain, diffs)

    if args.json:
        # 検証エンジンが 1 つなら従来どおりのオブジェクト、複数なら配列で出す
        print(json.dumps(payloads[0] if len(payloads) == 1 else payloads, ensure_ascii=False, indent=2))
    sys.exit(1 if any_diff else 0)


if __name__ == "__main__":
    main()
