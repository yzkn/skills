#!/usr/bin/env python3
"""sqlite — SQLite への SQL 実行とスキーマ抽出（標準ライブラリの sqlite3 のみ）。

用途: `db-review` / `data-modeler` が扱うスキーマの実物確認、SQL の挙動確認、
実行計画（インデックスが効いているか）の確認。

安全上の既定:
  - **既定は読み取り専用**（`mode=ro` で接続する）。書き込みには --write が必要。
  - 破壊的・更新系の文は --write なしでは実行しない（文の先頭語で判定する）。
  - 【要指示】パスに production / prod / prd を含む DB への書き込みは、--write を
    付けても拒否する（`.claude/rules/environment-safety.md`）。実行はユーザーに委ねる。
"""

from __future__ import annotations

import argparse
import re
import sqlite3
import sys
from pathlib import Path

from _common import Abort, emit, run, write_text_out

READ_ONLY_HEADS = {"select", "with", "pragma", "explain", "values"}
PRODUCTION_HINTS = ("production", "prod", "prd")
INLINE_ROW_LIMIT = 20  # これを超える行は --out へ出す（中間データを context に載せない）
MEMORY_DB = ":memory:"


def _statement_head(sql: str) -> str:
    stripped = re.sub(r"^\s*(?:--[^\n]*\n|/\*.*?\*/|\s)+", "", sql, flags=re.S)
    match = re.match(r"[A-Za-z]+", stripped)
    return match.group(0).lower() if match else ""


def _split_statements(sql: str) -> list[str]:
    return [s.strip() for s in sql.split(";") if s.strip()]


def _looks_production(db: str) -> bool:
    lowered = db.lower()
    return any(hint in lowered for hint in PRODUCTION_HINTS)


def connect(db: str, write: bool) -> sqlite3.Connection:
    if db == MEMORY_DB:
        return sqlite3.connect(MEMORY_DB)
    path = Path(db)
    if not path.is_file():
        raise Abort(f"DB ファイルが無い: {path}（新規作成はこのツールでは行わない）")
    if write and _looks_production(db):
        raise Abort(
            f"パスに production / prod / prd を含む DB への書き込みは拒否する: {path}。"
            "実行が必要な場合はユーザー自身が行う（.claude/rules/environment-safety.md）")
    if write:
        return sqlite3.connect(str(path))
    return sqlite3.connect(f"file:{path.as_posix()}?mode=ro", uri=True)


def _rows_to_dicts(cursor: sqlite3.Cursor) -> tuple[list[str], list[dict]]:
    columns = [d[0] for d in cursor.description] if cursor.description else []
    return columns, [dict(zip(columns, row)) for row in cursor.fetchall()]


def _read_sql(args) -> str:
    if bool(args.sql) == bool(args.sql_file):
        raise Abort("--sql と --sql-file のどちらか一方を指定する")
    if args.sql:
        return args.sql
    file = Path(args.sql_file)
    if not file.is_file():
        raise Abort(f"SQL ファイルが無い: {file}")
    return file.read_text(encoding="utf-8-sig")


def _guard_statements(statements: list[str], write: bool) -> list[str]:
    heads = [_statement_head(s) for s in statements]
    if not write:
        blocked = sorted({h for h in heads if h not in READ_ONLY_HEADS})
        if blocked:
            raise Abort(
                f"読み取り専用で実行できない文が含まれる: {', '.join(blocked)}。"
                "更新が必要なら --write を付ける（本番パスの DB では拒否される）")
    return heads


def cmd_query(args) -> int:
    sql = _read_sql(args)
    statements = _split_statements(sql)
    if not statements:
        raise Abort("SQL が空である")
    heads = _guard_statements(statements, args.write)
    conn = connect(args.db, args.write)
    try:
        result: dict = {"db": args.db, "read_only": not args.write,
                        "statements": len(statements), "heads": heads, "results": []}
        for statement in statements:
            cursor = conn.execute(statement)
            columns, rows = _rows_to_dicts(cursor)
            entry = {"head": _statement_head(statement), "columns": columns,
                     "row_count": len(rows), "changed_rows": cursor.rowcount if not columns else None}
            if args.out:
                entry["rows"] = rows
            elif len(rows) > INLINE_ROW_LIMIT:
                entry["rows"] = rows[:INLINE_ROW_LIMIT]
                entry["truncated"] = f"{len(rows)} 行のうち先頭 {INLINE_ROW_LIMIT} 行のみ。全件は --out で出す"
            else:
                entry["rows"] = rows
            result["results"].append(entry)
        if args.write:
            conn.commit()
        return emit(result, args.out)
    finally:
        conn.close()


def cmd_schema(args) -> int:
    conn = connect(args.db, write=False)
    try:
        tables = [r[0] for r in conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name")]
        detail = []
        for table in tables:
            columns = [{"name": r[1], "type": r[2], "notnull": bool(r[3]),
                        "default": r[4], "pk": bool(r[5])}
                       for r in conn.execute(f'PRAGMA table_info("{table}")')]
            foreign_keys = [{"column": r[3], "references": f"{r[2]}.{r[4]}", "on_delete": r[6]}
                            for r in conn.execute(f'PRAGMA foreign_key_list("{table}")')]
            indexes = [{"name": r[1], "unique": bool(r[2])}
                       for r in conn.execute(f'PRAGMA index_list("{table}")')]
            rows = conn.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0]
            detail.append({"table": table, "rows": rows, "columns": columns,
                           "primary_key": [c["name"] for c in columns if c["pk"]],
                           "foreign_keys": foreign_keys, "indexes": indexes})
        payload = {"db": args.db, "table_count": len(tables), "tables": detail}
        if args.ddl:
            ddl = "\n".join(r[0] + ";" for r in conn.execute(
                "SELECT sql FROM sqlite_master WHERE sql IS NOT NULL ORDER BY type DESC, name") if r[0])
            payload.update(write_text_out(ddl + "\n", args.ddl))
        return emit(payload, args.out)
    finally:
        conn.close()


def cmd_explain(args) -> int:
    sql = _read_sql(args)
    statements = _split_statements(sql)
    if len(statements) != 1:
        raise Abort(f"explain は 1 文だけを対象にする（受け取ったのは {len(statements)} 文）")
    _guard_statements(statements, write=False)
    conn = connect(args.db, write=False)
    try:
        plan = [dict(zip([d[0] for d in cur.description], row))
                for cur in [conn.execute(f"EXPLAIN QUERY PLAN {statements[0]}")]
                for row in cur.fetchall()]
        scans = [p for p in plan if "SCAN" in str(p.get("detail", "")).upper()
                 and "USING INDEX" not in str(p.get("detail", "")).upper()]
        return emit({
            "db": args.db, "sql_head": _statement_head(statements[0]),
            "plan": plan, "full_scans": [p.get("detail") for p in scans],
            "verdict": "index_not_used" if scans else "ok",
            "note": "SCAN のうち USING INDEX を伴わないものはフルスキャン。行数が増えると劣化する",
        }, args.out)
    finally:
        conn.close()


def _add_sql_opts(parser) -> None:
    parser.add_argument("--sql", help="実行する SQL（1 文以上。; 区切り）")
    parser.add_argument("--sql-file", help="SQL を書いたファイル")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="vnl.py sqlite", description="SQLite の SQL 実行・スキーマ抽出・実行計画")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("query", help="SQL を実行する（既定は読み取り専用）")
    p.add_argument("--db", required=True, help="DB ファイルのパス（:memory: も可）")
    _add_sql_opts(p)
    p.add_argument("--write", action="store_true", help="更新系の文を許可する（本番パスでは拒否される）")
    p.set_defaults(func=cmd_query)

    p = sub.add_parser("schema", help="テーブル・列・主キー・外部キー・インデックス・行数を抽出する")
    p.add_argument("--db", required=True)
    p.add_argument("--ddl", help="CREATE 文を書き出すファイル")
    p.set_defaults(func=cmd_schema)

    p = sub.add_parser("explain", help="実行計画を取得し、インデックスが使われているかを判定する")
    p.add_argument("--db", required=True)
    _add_sql_opts(p)
    p.set_defaults(func=cmd_explain)

    for child in sub.choices.values():
        child.add_argument("--out", help="結果 JSON の退避先")
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(run(main, sys.argv[1:]))
