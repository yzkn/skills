#!/usr/bin/env python3
"""bulk_ops.py — 多数ファイルの一括解析・一括変更をローカルで完結させ、要約だけを返す。

出典・派生元:
  mhattingpete/claude-skills-marketplace の execution-runtime（Apache License 2.0）
  の api/code_analysis.py・api/code_transform.py・security/pii_detector.py。
  本リポジトリへの移植にあたり以下を変更している。
    - パッケージ化と pip install を廃止（Python 標準ライブラリのみで単体実行）
    - git 操作 API（git_push を含む）を移植対象から除外
    - 全書き込み操作を dry-run 既定にし、--apply と git クリーン検査を必須化
    - 文字コード・改行・BOM を厳密に保持（Windows / cp932 環境対策）
    - 出力を要約 JSON に統一（詳細・差分はファイルへ退避）

設計方針: 中間データをコンテキストに載せない。stdout には要約 JSON のみを出す。
"""

from __future__ import annotations

import argparse
import ast
import json
import re
import subprocess
import sys
from difflib import unified_diff
from pathlib import Path

# --- 走査対象から常に除外する（証跡・第三者コード・生成物・VCS 内部） ---
EXCLUDE_DIRS = {
    ".git", ".jobs", ".venv", "venv", "env", "__pycache__", "node_modules",
    ".pytest_cache", ".mypy_cache", ".ruff_cache", "dist", "build", ".next", ".idea", ".vs",
}
EXCLUDE_RELS = (
    "doc/prompt", "doc/thought", "doc/adr",          # 証跡（不変・編集禁止）
    "guide/for-human",                                # 参照禁止（Office 原本）
    ".claude/skills/anthropics",                      # 第三者由来スキル（書き換え禁止）
)
DEFAULT_MAX_BYTES = 2 * 1024 * 1024

# Windows の既定コンソール（cp932）では日本語の要約出力が UnicodeEncodeError になる。
# 呼び出し側に PYTHONUTF8=1 を要求せず、ここで UTF-8 に固定する。
for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

DEBUG_PATTERNS = [
    r"^\s*print\s*\(",
    r"^\s*console\.(log|debug)\s*\(",
    r"^\s*debugger\s*;?\s*$",
    r"^\s*import\s+pdb\b",
    r"^\s*pdb\.set_trace\s*\(",
    r"^\s*breakpoint\s*\(",
]

# --- 機密情報パターン（値は決して出力しない。種別と行番号のみ報告する） ---
SECRET_PATTERNS = {
    "aws_access_key": [r"AKIA[0-9A-Z]{16}"],
    "aws_secret": [r"aws[_-]?secret[_-]?access[_-]?key[\"']?\s*[:=]\s*[\"'][A-Za-z0-9/+=]{40}[\"']"],
    "github_token": [r"gh[pousr]_[A-Za-z0-9]{36}"],
    "google_api_key": [r"AIza[0-9A-Za-z\-_]{35}"],
    "slack_token": [r"xox[pboa]-[0-9]{10,13}-[0-9]{10,13}-[0-9a-zA-Z]{24,32}"],
    "stripe_key": [r"[sp]k_live_[0-9a-zA-Z]{24}"],
    "jwt": [r"eyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]+"],
    "private_key": [r"-----BEGIN (?:RSA |DSA |EC |OPENSSH )?PRIVATE KEY-----"],
    "api_key": [r"api[_-]?key[\"']?\s*[:=]\s*[\"'][A-Za-z0-9_\-]{20,}[\"']"],
    "generic_secret": [
        r"(?:secret|token)[\"']?\s*[:=]\s*[\"'][A-Za-z0-9_\-/+=]{20,}[\"']",
        r"password[\"']?\s*[:=]\s*[\"'][^\"']{8,}[\"']",
    ],
    "database_url": [r"(?:postgres(?:ql)?|mysql|mongodb(?:\+srv)?)://[^:\s]+:[^@\s]+@[^\s\"']+"],
}
MASK_LABEL = {k: f"[REDACTED_{k.upper()}]" for k in SECRET_PATTERNS}


# ---------------------------------------------------------------- 基盤ユーティリティ

class Abort(Exception):
    """安全条件を満たさないため中断する（症状を隠した続行はしない）。"""


def repo_root(explicit: str | None) -> Path:
    root = Path(explicit).resolve() if explicit else Path.cwd().resolve()
    if not root.is_dir():
        raise Abort(f"root がディレクトリではない: {root}")
    return root


def resolve_in_root(target: str, root: Path) -> Path:
    """root の外を触らせない。シンボリックリンク経由の脱出も防ぐ。"""
    p = (root / target).resolve() if not Path(target).is_absolute() else Path(target).resolve()
    if root != p and root not in p.parents:
        raise Abort(f"リポジトリ root の外は対象にできない: {p}")
    return p


def iter_files(base: Path, pattern: str, root: Path, max_bytes: int) -> tuple[list[Path], dict]:
    skipped = {"excluded": 0, "too_large": 0}
    files: list[Path] = []
    candidates = [base] if base.is_file() else sorted(base.glob(pattern))
    for p in candidates:
        if not p.is_file():
            continue
        rel = p.relative_to(root).as_posix()
        if set(p.parts) & EXCLUDE_DIRS or rel.startswith(EXCLUDE_RELS):
            skipped["excluded"] += 1
            continue
        if p.stat().st_size > max_bytes:
            skipped["too_large"] += 1
            continue
        files.append(p)
    return files, skipped


def read_text(path: Path) -> tuple[str, bool] | None:
    """(本文, BOM の有無) を返す。改行は原文のまま保持する。復号できなければ None。"""
    data = path.read_bytes()
    if b"\x00" in data[:4096]:
        return None
    has_bom = data.startswith(b"\xef\xbb\xbf")
    try:
        return data[3:].decode("utf-8") if has_bom else data.decode("utf-8"), has_bom
    except UnicodeDecodeError:
        return None


def write_text(path: Path, text: str, has_bom: bool) -> None:
    """BOM と改行を保持して書き戻す。0 バイト化は書き込み前に拒否する。"""
    body = text.encode("utf-8")
    if not body and path.stat().st_size > 0:
        raise Abort(f"書き込み結果が 0 バイトになる: {path}")
    path.write_bytes((b"\xef\xbb\xbf" if has_bom else b"") + body)


def git_dirty(files: list[Path], root: Path) -> dict[str, list[str]]:
    """未コミットの変更・未追跡ファイルを検出する（git 履歴を唯一の復元手段とするため）。"""
    rels = [p.relative_to(root).as_posix() for p in files]
    out = {"modified": [], "untracked": []}
    if not rels:
        return out
    try:
        proc = subprocess.run(
            ["git", "-C", str(root), "status", "--porcelain", "--", *rels],
            capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        raise Abort(f"git status を実行できない（--force で無視できるが復元手段が無くなる）: {exc}")
    if proc.returncode != 0:
        raise Abort(f"git status が失敗した: {proc.stderr.strip()[:200]}")
    for line in proc.stdout.splitlines():
        status, _, name = line[:2], line[2], line[3:].strip().strip('"')
        if status == "??":
            out["untracked"].append(name)
        else:
            out["modified"].append(name)
    return out


def guard_writes(files: list[Path], root: Path, apply: bool, force: bool) -> dict:
    if not apply:
        return {"git_check": "skipped(dry-run)"}
    if force:
        return {"git_check": "skipped(--force)"}
    dirty = git_dirty(files, root)
    if dirty["modified"] or dirty["untracked"]:
        raise Abort(
            "対象に未コミットの変更／未追跡ファイルがあるため中断した（git が唯一の復元手段になるため）。"
            "コミットまたは退避してから再実行するか、意図的に上書きする場合のみ --force を付ける。 "
            f"modified={dirty['modified'][:10]} untracked={dirty['untracked'][:10]}"
        )
    return {"git_check": "clean"}


def emit(payload: dict, out: str | None, details: object = None) -> None:
    """stdout には要約のみ。詳細は --out のファイルへ退避する。"""
    if out and details is not None:
        Path(out).parent.mkdir(parents=True, exist_ok=True)
        Path(out).write_text(json.dumps(details, ensure_ascii=False, indent=2), encoding="utf-8")
        payload["details_file"] = out
    elif details is not None:
        payload["details_hint"] = "詳細を得るには --out <パス> を指定する（stdout には出さない）"
    print(json.dumps(payload, ensure_ascii=False, indent=2))


# ---------------------------------------------------------------- analyze / find

def py_complexity(node: ast.AST) -> int:
    """循環的複雑度の近似（分岐・ループ・例外・論理演算・内包表記の条件を加算）。"""
    score = 1
    for n in ast.walk(node):
        if isinstance(n, (ast.If, ast.For, ast.AsyncFor, ast.While, ast.ExceptHandler,
                          ast.IfExp, ast.Assert, ast.With, ast.AsyncWith)):
            score += 1
        elif isinstance(n, ast.BoolOp):
            score += len(n.values) - 1
        elif isinstance(n, ast.comprehension):
            score += len(n.ifs)
        elif isinstance(n, ast.match_case):
            score += 1
    return score


def cmd_analyze(args: argparse.Namespace) -> None:
    root = repo_root(args.root)
    base = resolve_in_root(args.path, root)
    files, skipped = iter_files(base, args.glob, root, args.max_bytes)

    per_file, unparsable, undecodable = [], [], 0
    for p in files:
        got = read_text(p)
        if got is None:
            undecodable += 1
            continue
        text, _ = got
        rel = p.relative_to(root).as_posix()
        try:
            tree = ast.parse(text, filename=str(p))
        except SyntaxError as exc:
            unparsable.append({"file": rel, "line": exc.lineno})
            continue
        funcs = [n for n in ast.walk(tree) if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))]
        classes = [n for n in ast.walk(tree) if isinstance(n, ast.ClassDef)]
        hotspots = sorted(
            ({"name": f.name, "line": f.lineno, "lines": (f.end_lineno or f.lineno) - f.lineno + 1,
              "complexity": py_complexity(f)} for f in funcs),
            key=lambda d: -d["complexity"],
        )
        per_file.append({
            "file": rel,
            "lines": len(text.splitlines()),
            "functions": len(funcs),
            "classes": len(classes),
            "max_complexity": hotspots[0]["complexity"] if hotspots else 0,
            "unused_imports": unused_imports(tree),
            "hotspots": [h for h in hotspots if h["complexity"] >= args.threshold],
        })

    over = [
        {"file": f["file"], **h}
        for f in per_file for h in f["hotspots"]
    ]
    over.sort(key=lambda d: -d["complexity"])
    summary = {
        "command": "analyze",
        "files_analyzed": len(per_file),
        "files_skipped": skipped,
        "files_undecodable": undecodable,
        "files_unparsable": len(unparsable),
        "total_lines": sum(f["lines"] for f in per_file),
        "total_functions": sum(f["functions"] for f in per_file),
        "total_classes": sum(f["classes"] for f in per_file),
        "functions_over_threshold": len(over),
        "threshold": args.threshold,
        "top_hotspots": over[: args.top],
        "files_with_unused_imports": sum(1 for f in per_file if f["unused_imports"]),
        "note": "複雑度は近似値。正式な保守性診断は complexity-analyzer サブエージェントを使う",
    }
    emit(summary, args.out, {"per_file": per_file, "unparsable": unparsable})


def unused_imports(tree: ast.AST) -> list[str]:
    """未使用の import 候補。`import a.b` は先頭要素 a の使用で使用済みと見なす。"""
    imported: dict[str, str] = {}
    for n in ast.walk(tree):
        if isinstance(n, ast.Import):
            for a in n.names:
                key = a.asname or a.name.split(".")[0]
                imported[key] = a.name
        elif isinstance(n, ast.ImportFrom):
            for a in n.names:
                if a.name == "*":
                    continue
                imported[a.asname or a.name] = f"{n.module or ''}.{a.name}"
    used: set[str] = set()
    for n in ast.walk(tree):
        if isinstance(n, ast.Name):
            used.add(n.id)
        elif isinstance(n, ast.Attribute) and isinstance(n.value, ast.Name):
            used.add(n.value.id)
    # __all__ とアノテーション文字列内の使用は追えないため「候補」に留める
    return sorted(k for k in imported if k not in used)


def cmd_find(args: argparse.Namespace) -> None:
    """関数・クラスの位置と署名（メタデータ）のみを返す。本文はコンテキストに載せない。"""
    root = repo_root(args.root)
    base = resolve_in_root(args.path, root)
    files, skipped = iter_files(base, args.glob, root, args.max_bytes)
    rx = re.compile(args.name_pattern) if args.name_pattern else None
    want_cls = args.kind == "class"

    hits = []
    for p in files:
        got = read_text(p)
        if got is None:
            continue
        try:
            tree = ast.parse(got[0], filename=str(p))
        except SyntaxError:
            continue
        for n in ast.walk(tree):
            if want_cls and isinstance(n, ast.ClassDef):
                item = {"name": n.name, "methods": [m.name for m in n.body
                        if isinstance(m, (ast.FunctionDef, ast.AsyncFunctionDef))]}
            elif not want_cls and isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef)):
                item = {"name": n.name, "args": [a.arg for a in n.args.args],
                        "is_async": isinstance(n, ast.AsyncFunctionDef),
                        "decorators": len(n.decorator_list)}
            else:
                continue
            if rx and not rx.search(item["name"]):
                continue
            hits.append({"file": p.relative_to(root).as_posix(),
                         "start_line": n.lineno, "end_line": n.end_lineno, **item})

    emit({"command": "find", "kind": args.kind, "files_scanned": len(files),
          "files_skipped": skipped, "matches": len(hits), "sample": hits[: args.top]},
         args.out, {"matches": hits})


# ---------------------------------------------------------------- 変更系（dry-run 既定）

def apply_edits(args: argparse.Namespace, transform, label: str) -> None:
    """transform(text) -> (new_text, count) を全対象に適用する共通処理。"""
    root = repo_root(args.root)
    base = resolve_in_root(args.path, root)
    files, skipped = iter_files(base, args.glob, root, args.max_bytes)

    changes, errors, diff_lines, targets = [], [], [], []
    for p in files:
        got = read_text(p)
        if got is None:
            continue
        text, has_bom = got
        try:
            new_text, count = transform(text)
        except re.error as exc:
            errors.append({"file": p.relative_to(root).as_posix(), "error": f"regex: {exc}"})
            continue
        if count == 0 or new_text == text:
            continue
        rel = p.relative_to(root).as_posix()
        changes.append({"file": rel, "replacements": count,
                        "delta_chars": len(new_text) - len(text)})
        if args.diff_out:
            diff_lines.extend(unified_diff(
                text.splitlines(keepends=True), new_text.splitlines(keepends=True),
                fromfile=f"a/{rel}", tofile=f"b/{rel}", n=2))
        if args.apply:
            targets.append((p, new_text, has_bom))

    guard = guard_writes([p for p, _, _ in targets], root, args.apply, args.force)
    written = 0
    for p, new_text, has_bom in targets:
        write_text(p, new_text, has_bom)
        written += 1

    if args.diff_out and diff_lines:
        Path(args.diff_out).parent.mkdir(parents=True, exist_ok=True)
        Path(args.diff_out).write_text("".join(diff_lines), encoding="utf-8")

    changes.sort(key=lambda d: -d["replacements"])
    emit({
        "command": label,
        "mode": "applied" if args.apply else "dry-run",
        **guard,
        "files_scanned": len(files),
        "files_skipped": skipped,
        "files_to_change" if not args.apply else "files_changed": len(changes),
        "files_written": written,
        "total_replacements": sum(c["replacements"] for c in changes),
        "top_files": changes[: args.top],
        "errors": errors[:10],
        "diff_file": args.diff_out if (args.diff_out and diff_lines) else None,
        "next_step": ("内容を確認したうえでユーザーの承認を得てから --apply を付けて再実行する"
                      if not args.apply else "git diff --stat で変更量を検証する"),
    }, args.out, {"changes": changes, "errors": errors})


def cmd_rename(args: argparse.Namespace) -> None:
    """識別子を単語境界付きで置換する（部分一致による誤爆を防ぐ）。"""
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", args.old) or \
       not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", args.new):
        raise Abort("rename は識別子（英数字とアンダースコア）のみを対象にする。任意文字列は replace を使う")
    rx = re.compile(rf"\b{re.escape(args.old)}\b")
    apply_edits(args, lambda t: rx.subn(args.new, t), "rename")


def cmd_replace(args: argparse.Namespace) -> None:
    rx = re.compile(args.search if args.regex else re.escape(args.search))
    repl = args.replace if args.regex else args.replace.replace("\\", "\\\\")
    apply_edits(args, lambda t: rx.subn(repl, t), "replace")


def cmd_strip_debug(args: argparse.Namespace) -> None:
    """デバッグ出力の行を削除する。複数行にまたがる呼び出しは検出できないため dry-run で必ず確認する。"""
    pats = [re.compile(p) for p in DEBUG_PATTERNS]

    def transform(text: str) -> tuple[str, int]:
        kept, removed = [], 0
        for line in text.splitlines(keepends=True):
            if any(p.search(line) for p in pats):
                removed += 1
                continue
            kept.append(line)
        return "".join(kept), removed

    apply_edits(args, transform, "strip-debug")


# ---------------------------------------------------------------- 機密情報

def scan_secrets(text: str) -> list[dict]:
    """検出結果は種別・行番号のみ。一致した値は決して返さない。"""
    found = []
    for kind, pats in SECRET_PATTERNS.items():
        for pat in pats:
            for m in re.finditer(pat, text, re.IGNORECASE):
                found.append({"type": kind, "line": text[: m.start()].count("\n") + 1})
    return found


def cmd_scan_secrets(args: argparse.Namespace) -> None:
    root = repo_root(args.root)
    base = resolve_in_root(args.path, root)
    files, skipped = iter_files(base, args.glob, root, args.max_bytes)
    per_file, total = [], 0
    for p in files:
        got = read_text(p)
        if got is None:
            continue
        hits = scan_secrets(got[0])
        if hits:
            total += len(hits)
            per_file.append({"file": p.relative_to(root).as_posix(),
                             "count": len(hits),
                             "types": sorted({h['type'] for h in hits}),
                             "lines": sorted({h['line'] for h in hits})[:20]})
    per_file.sort(key=lambda d: -d["count"])
    emit({"command": "scan-secrets", "files_scanned": len(files), "files_skipped": skipped,
          "files_with_hits": len(per_file), "total_hits": total, "top_files": per_file[: args.top],
          "note": "誤検知を含む簡易検出。コミット前の正式チェックは gitleaks（.githooks/pre-commit）",
          "next_step": "ヒットした行はユーザーに報告し、値そのものをコンテキストに読み込まない"},
         args.out, {"per_file": per_file})


def cmd_mask(args: argparse.Namespace) -> None:
    """ログ等を読む前にマスクする。入力ファイルは変更せず、マスク済みを別ファイルへ書く。"""
    root = repo_root(args.root)
    src = resolve_in_root(args.file, root)
    got = read_text(src)
    if got is None:
        raise Abort(f"UTF-8 として読めない、またはバイナリ: {src}")
    text, _ = got
    counts: dict[str, int] = {}
    for kind, pats in SECRET_PATTERNS.items():
        for pat in pats:
            text, n = re.subn(pat, MASK_LABEL[kind], text, flags=re.IGNORECASE)
            if n:
                counts[kind] = counts.get(kind, 0) + n
    dest = Path(args.out_file)
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(text, encoding="utf-8")
    print(json.dumps({"command": "mask", "source": src.name, "masked_file": str(dest),
                      "masked_counts": counts, "total_masked": sum(counts.values())},
                     ensure_ascii=False, indent=2))


# ---------------------------------------------------------------- CLI

def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(
        prog="bulk_ops.py",
        description="多数ファイルの一括解析・一括変更をローカルで完結させ、要約 JSON だけを返す。",
        epilog="変更系（rename / replace / strip-debug）は既定で dry-run。--apply でのみ書き込む。",
    )
    sub = ap.add_subparsers(dest="command", required=True)

    def common(p: argparse.ArgumentParser, *, need_glob: str = "**/*.py") -> None:
        p.add_argument("--path", default=".", help="対象ディレクトリまたはファイル（既定: .）")
        p.add_argument("--glob", default=need_glob, help=f"ファイルパターン（既定: {need_glob}）")
        p.add_argument("--root", default=None, help="リポジトリ root（既定: カレント。この外は触らない）")
        p.add_argument("--max-bytes", type=int, default=DEFAULT_MAX_BYTES, help="この超過ファイルは飛ばす")
        p.add_argument("--top", type=int, default=10, help="stdout に載せる上位件数（既定: 10）")
        p.add_argument("--out", default=None, help="詳細 JSON の出力先（stdout には出さない）")

    def writable(p: argparse.ArgumentParser) -> None:
        p.add_argument("--apply", action="store_true", help="実際に書き込む（未指定なら dry-run）")
        p.add_argument("--force", action="store_true",
                       help="未コミット変更があっても書き込む（復元手段が失われる。原則使わない）")
        p.add_argument("--diff-out", default=None, help="unified diff の出力先ファイル")

    p = sub.add_parser("analyze", help="Python ファイルの規模・複雑度・未使用 import を集計する")
    common(p)
    p.add_argument("--threshold", type=int, default=10, help="複雑度の報告閾値（既定: 10）")
    p.set_defaults(func=cmd_analyze)

    p = sub.add_parser("find", help="関数・クラスの位置と署名（メタデータのみ）を列挙する")
    common(p)
    p.add_argument("--kind", choices=["function", "class"], default="function")
    p.add_argument("--name-pattern", default=None, help="名前に対する正規表現フィルタ")
    p.set_defaults(func=cmd_find)

    p = sub.add_parser("rename", help="識別子を単語境界付きで一括改名する")
    common(p)
    writable(p)
    p.add_argument("--old", required=True)
    p.add_argument("--new", required=True)
    p.set_defaults(func=cmd_rename)

    p = sub.add_parser("replace", help="任意文字列・正規表現を一括置換する")
    common(p, need_glob="**/*")
    writable(p)
    p.add_argument("--search", required=True)
    p.add_argument("--replace", required=True)
    p.add_argument("--regex", action="store_true", help="--search を正規表現として扱う")
    p.set_defaults(func=cmd_replace)

    p = sub.add_parser("strip-debug", help="デバッグ出力行（print / console.log 等）を削除する")
    common(p, need_glob="**/*")
    writable(p)
    p.set_defaults(func=cmd_strip_debug)

    p = sub.add_parser("scan-secrets", help="機密情報らしい記述を検出する（値は出力しない）")
    common(p, need_glob="**/*")
    p.set_defaults(func=cmd_scan_secrets)

    p = sub.add_parser("mask", help="ファイル内の機密情報をマスクして別ファイルへ書き出す")
    p.add_argument("--file", required=True, help="入力ファイル（変更しない）")
    p.add_argument("--out-file", required=True, help="マスク済みの出力先")
    p.add_argument("--root", default=None)
    p.set_defaults(func=cmd_mask)

    return ap


def main() -> int:
    args = build_parser().parse_args()
    try:
        args.func(args)
    except Abort as exc:
        print(json.dumps({"status": "aborted", "reason": str(exc)}, ensure_ascii=False, indent=2),
              file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
