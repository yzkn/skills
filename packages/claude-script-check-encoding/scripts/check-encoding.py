"""テキストファイルの文字コード・改行コード・BOM が種別ごとの要件を満たすか検査する。

ファイルを新規作成・編集した直後に実行する。要件の根拠と落とし穴は
`.claude/docs/text-encoding.md` を参照。

使い方:
    python .claude/scripts/check-encoding.py <パス...>            # 検査のみ（既定）
    python .claude/scripts/check-encoding.py <パス...> --fix      # 違反を修正する
    python .claude/scripts/check-encoding.py .claude --quiet      # ディレクトリを再帰検査

終了コード: 0 = 違反なし / 1 = ERROR あり / 2 = 引数エラー
（WARN のみの場合は 0。ERROR は「そのまま実行・解析すると壊れる」ものだけに割り当てる）
"""
import sys
from pathlib import Path

for _s in (sys.stdout, sys.stderr):  # cp932 コンソールでも日本語を出す
    if hasattr(_s, "reconfigure"):
        _s.reconfigure(encoding="utf-8")

BOM = b"\xef\xbb\xbf"

# 拡張子 -> (BOM: "required"/"forbidden"/"any", 改行: "lf"/"crlf"/"any", 理由)
RULES = {
    ".ps1":  ("required", "any",  "PowerShell 5.1 は BOM の無い UTF-8 を cp932 として読むため、日本語が壊れて構文エラーになる"),
    ".psm1": ("required", "any",  "同上"),
    ".psd1": ("required", "any",  "同上"),
    ".sh":   ("forbidden", "lf",  "BOM は shebang を壊し、CRLF は Git Bash で $'\\r': command not found になる"),
    ".bash": ("forbidden", "lf",  "同上"),
    ".py":   ("forbidden", "any", "Python 3 の既定は UTF-8。BOM は一部ツールの読み取りを壊す"),
    ".json": ("forbidden", "any", "JSON パーサは BOM を受け付けないことがある"),
    ".md":   ("forbidden", "any", "BOM は不要で、差分や結合の際に紛れ込む"),
    ".txt":  ("forbidden", "any", "同上"),
    ".yml":  ("forbidden", "any", "YAML パーサは BOM を受け付けないことがある"),
    ".yaml": ("forbidden", "any", "同上"),
    ".toml": ("forbidden", "any", "同上"),
    ".js":   ("forbidden", "any", "BOM は不要"),
    ".mjs":  ("forbidden", "any", "同上"),
    ".ts":   ("forbidden", "any", "同上"),
    ".css":  ("forbidden", "any", "同上"),
    ".html": ("forbidden", "any", "同上"),
    ".bat":  ("any", "crlf", "cmd.exe は LF のみのバッチでラベル・goto を誤解釈することがある"),
    ".cmd":  ("any", "crlf", "同上"),
}

# 再帰検査で入らないディレクトリ（証跡・第三者由来・生成物・実行時状態）
SKIP_DIRS = {
    ".git", "node_modules", ".jobs", "__pycache__", ".venv", "venv",
    "dist", "prompt", "thought", "adr", "anthropics", "upstream", "for-human",
}


def scan_paths(paths):
    """引数のパスを、検査対象ファイルの一覧に展開する。"""
    files = []
    for raw in paths:
        p = Path(raw)
        if p.is_dir():
            for f in sorted(p.rglob("*")):
                if f.is_file() and f.suffix.lower() in RULES:
                    if any(part in SKIP_DIRS for part in f.parts):
                        continue
                    files.append(f)
        elif p.is_file():
            files.append(p)
        else:
            print(f"ERROR  存在しません: {raw}")
    return files


def check(path: Path):
    """1 ファイルを検査して (findings, data) を返す。findings は (level, message, kind)。"""
    data = path.read_bytes()
    if not data:
        return [], data
    ext = path.suffix.lower()
    if ext not in RULES:
        return [], data
    bom_req, eol_req, reason = RULES[ext]
    findings = []

    body = data[len(BOM):] if data.startswith(BOM) else data
    has_bom = data.startswith(BOM)
    if data.startswith(BOM * 2):
        findings.append(("ERROR", "BOM が重複している", "bom"))

    try:
        body.decode("utf-8")
    except UnicodeDecodeError as e:
        findings.append(("ERROR", f"UTF-8 として読めない（{e.reason} at byte {e.start}）", "encoding"))

    if bom_req == "required" and not has_bom:
        findings.append(("ERROR", f"BOM が無い: {reason}", "bom"))
    elif bom_req == "forbidden" and has_bom:
        findings.append(("ERROR", f"BOM がある: {reason}", "bom"))

    crlf = body.count(b"\r\n")
    lone_lf = body.count(b"\n") - crlf
    lone_cr = body.count(b"\r") - crlf
    if lone_cr:
        findings.append(("ERROR", f"単独の CR が {lone_cr} 個ある（古い Mac 形式の混入）", "eol"))
    if crlf and lone_lf:
        # 改行の指定が無い種別（.md 等）の混在は、git の `* text=auto` が格納時に LF へ
        # 正規化するため実行や解析を壊さない。差分が汚れるだけなので WARN に留める。
        level = "ERROR" if eol_req != "any" else "WARN"
        findings.append((level, f"CRLF と LF が混在している（CRLF {crlf} / LF {lone_lf}）", "eol"))
    elif eol_req == "lf" and crlf:
        findings.append(("ERROR", f"改行が CRLF（{crlf} 行）: {reason}", "eol"))
    elif eol_req == "crlf" and lone_lf and not crlf:
        findings.append(("WARN", f"改行が LF（{lone_lf} 行）: {reason}", "eol"))

    return findings, data


def fix(path: Path, data: bytes, findings) -> str:
    """検出した違反のうち、機械的に直せるもの（BOM・改行）を修正する。"""
    kinds = {k for _, _, k in findings}
    if "encoding" in kinds:
        return f"SKIP  {path}: UTF-8 として読めないため自動修正しない"
    ext = path.suffix.lower()
    bom_req, eol_req, _ = RULES[ext]

    body = data
    while body.startswith(BOM):
        body = body[len(BOM):]

    if "eol" in kinds:
        body = body.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
        if eol_req == "crlf":
            body = body.replace(b"\n", b"\r\n")

    out = (BOM + body) if bom_req == "required" else body
    if out == data:
        return f"OK    {path}: 変更なし"
    path.write_bytes(out)
    return f"FIXED {path}: {len(data)} -> {len(out)} バイト"


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    do_fix = "--fix" in sys.argv
    quiet = "--quiet" in sys.argv
    if not args:
        print(__doc__)
        return 2

    files = scan_paths(args)
    if not files:
        print("検査対象がありません（対応拡張子: " + " ".join(sorted(RULES)) + "）")
        return 0

    errors = warns = 0
    for f in files:
        findings, data = check(f)
        if not findings:
            if not quiet:
                print(f"OK     {f}")
            continue
        for level, msg, _ in findings:
            print(f"{level:<6} {f}: {msg}")
            if level == "ERROR":
                errors += 1
            else:
                warns += 1
        if do_fix:
            print("       " + fix(f, data, findings))

    print(f"\n検査 {len(files)} 件 / ERROR {errors} 件 / WARN {warns} 件"
          + ("（--fix で修正済み。再実行して 0 件になることを確認する）" if do_fix and errors else ""))
    return 1 if (errors and not do_fix) else 0


if __name__ == "__main__":
    sys.exit(main())
