#!/usr/bin/env python3
"""textconv — JSON / YAML / CSV / TSV / Markdown 表 / XML の相互変換。

用途: 設計書の表（Markdown 正本）と設定ファイル・テストデータの往復。
依存: PyYAML（MIT・導入済み）。YAML を使わない変換は標準ライブラリのみで動く。

設計上の制約:
  - 表形式（csv / tsv / md / xml）は「フラットな辞書の配列」しか扱わない。
    入れ子を黙って潰さず、変換できない構造は中断して理由を示す（Fail Fast）。
  - XML の入力で DOCTYPE を拒否する（外部実体参照・実体展開攻撃を持ち込まない）。
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

from _common import Abort, emit, run, write_text_out

FORMATS = ("json", "yaml", "csv", "tsv", "md", "xml")
TABULAR = ("csv", "tsv", "md", "xml")
DELIM = {"csv": ",", "tsv": "\t"}


def _load_yaml_module():
    try:
        import yaml  # noqa: PLC0415
    except ImportError as exc:
        raise Abort("PyYAML が無い。YAML 以外の形式を使うか、導入をユーザーに相談する") from exc
    return yaml


def _parse_md_table(text: str) -> list[dict]:
    rows = [ln.strip() for ln in text.splitlines() if ln.strip().startswith("|")]
    if len(rows) < 2:
        raise Abort("Markdown 表として解釈できない（`|` で始まる行が 2 行以上必要）")
    def cells(line: str) -> list[str]:
        return [c.strip() for c in line.strip().strip("|").split("|")]
    header = cells(rows[0])
    body = [cells(r) for r in rows[2:]] if set(rows[1].replace("|", "").strip()) <= set("-: ") else [cells(r) for r in rows[1:]]
    return [dict(zip(header, r)) for r in body]


def _parse_xml(text: str) -> list[dict]:
    if "<!DOCTYPE" in text.upper():
        raise Abort("DOCTYPE を含む XML は受け付けない（外部実体参照・実体展開攻撃を避けるため）")
    root = ET.fromstring(text)
    records = []
    for child in root:
        record = {sub.tag: (sub.text or "") for sub in child}
        record.update({k: v for k, v in child.attrib.items()})
        if not record:
            record = {child.tag: child.text or ""}
        records.append(record)
    if not records:
        raise Abort("XML から要素を取り出せない（ルート直下に繰り返し要素が必要）")
    return records


def load_data(text: str, fmt: str):
    if fmt == "json":
        return json.loads(text)
    if fmt == "yaml":
        return _load_yaml_module().safe_load(text)
    if fmt in DELIM:
        return list(csv.DictReader(io.StringIO(text), delimiter=DELIM[fmt]))
    if fmt == "md":
        return _parse_md_table(text)
    return _parse_xml(text)


def _as_records(data, fmt: str) -> list[dict]:
    """表形式へ出す前に構造を検査する。潰せない構造は黙って変換しない。"""
    if isinstance(data, dict):
        data = [data]
    if not isinstance(data, list) or not all(isinstance(r, dict) for r in data):
        raise Abort(f"{fmt} へ変換するには「フラットな辞書の配列」が必要（入れ子・スカラーは変換しない）")
    nested = sorted({k for r in data for k, v in r.items() if isinstance(v, (dict, list))})
    if nested:
        raise Abort(f"{fmt} へ変換できない入れ子の項目がある: {', '.join(nested)}（先に JSON/YAML で整形する）")
    return data


def _dump_delimited(records: list[dict], fmt: str) -> str:
    fields: list[str] = []
    for r in records:
        fields.extend(k for k in r if k not in fields)
    buf = io.StringIO(newline="")
    writer = csv.DictWriter(buf, fieldnames=fields, delimiter=DELIM[fmt], lineterminator="\n")
    writer.writeheader()
    writer.writerows({k: ("" if v is None else v) for k, v in r.items()} for r in records)
    return buf.getvalue()


def _dump_md(records: list[dict]) -> str:
    fields: list[str] = []
    for r in records:
        fields.extend(k for k in r if k not in fields)
    def esc(v) -> str:
        return "" if v is None else str(v).replace("|", "\\|").replace("\n", "<br>")
    lines = ["| " + " | ".join(fields) + " |", "|" + "|".join("---" for _ in fields) + "|"]
    lines += ["| " + " | ".join(esc(r.get(f)) for f in fields) + " |" for r in records]
    return "\n".join(lines) + "\n"


def _dump_xml(records: list[dict]) -> str:
    root = ET.Element("records")
    for r in records:
        item = ET.SubElement(root, "record")
        for k, v in r.items():
            ET.SubElement(item, str(k)).text = "" if v is None else str(v)
    ET.indent(root, space="  ")
    return ET.tostring(root, encoding="unicode") + "\n"


def dump_data(data, fmt: str) -> str:
    if fmt == "json":
        return json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    if fmt == "yaml":
        return _load_yaml_module().safe_dump(data, allow_unicode=True, sort_keys=False)
    records = _as_records(data, fmt)
    if fmt in DELIM:
        return _dump_delimited(records, fmt)
    return _dump_md(records) if fmt == "md" else _dump_xml(records)


def _infer_format(path: str | None, explicit: str | None) -> str:
    if explicit:
        return explicit
    if not path:
        raise Abort("形式を推定できない。--from / --to を明示する")
    suffix = Path(path).suffix.lower().lstrip(".")
    mapping = {"json": "json", "yaml": "yaml", "yml": "yaml", "csv": "csv",
               "tsv": "tsv", "md": "md", "markdown": "md", "xml": "xml"}
    if suffix not in mapping:
        raise Abort(f"拡張子 .{suffix} から形式を推定できない。--from / --to を明示する")
    return mapping[suffix]


def cmd_convert(args) -> int:
    src_fmt = _infer_format(args.in_file, args.src)
    dst_fmt = _infer_format(args.out_file, args.dst)
    text = Path(args.in_file).read_text(encoding="utf-8-sig") if args.in_file else sys.stdin.read()
    data = load_data(text, src_fmt)
    result = dump_data(data, dst_fmt)
    summary = {"from": src_fmt, "to": dst_fmt,
               "records": len(data) if isinstance(data, list) else 1}
    if args.out_file:
        summary.update(write_text_out(result, args.out_file))
    else:
        summary["result"] = result
    return emit(summary)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="vnl.py text", description="JSON / YAML / CSV / TSV / Markdown 表 / XML の相互変換")
    sub = parser.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("convert", help="形式変換（拡張子から推定・--from/--to で明示）")
    p.add_argument("--in-file", help="入力ファイル（省略時は標準入力）")
    p.add_argument("--out-file", help="出力ファイル（省略時は結果を stdout に載せる）")
    p.add_argument("--from", dest="src", choices=FORMATS)
    p.add_argument("--to", dest="dst", choices=FORMATS)
    p.set_defaults(func=cmd_convert)
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(run(main, sys.argv[1:]))
