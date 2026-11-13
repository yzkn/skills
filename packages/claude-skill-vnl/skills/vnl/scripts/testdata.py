#!/usr/bin/env python3
"""testdata — 架空のテストデータを生成する（Faker ja_JP・MIT）。

位置づけ: `.claude/rules/security-hardstops.md`【絶対禁止】「本番データのテスト環境使用禁止」
に対する代替手段。既存データのマスキングは `/bulk-ops mask` が担い、本モジュールは
ゼロから架空データを作る側を担う。

架空であることの機械的な担保:
  - メールアドレスは RFC 2606 の予約ドメイン（example.jp / example.com）に固定する。
  - 電話番号は実在の加入者番号帯を避けた形（局番 0000）に固定する。
  - 各レコードに `_fictional: true` を付ける（--no-marker で外せる）。
出力の置き場: `src/` のテストフィクスチャか `wip/`。`doc/`（証跡・不変）と
`intake/`（顧客受領原本）には置かない。
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import sys
import uuid

from _common import Abort, emit, run, write_text_out

FIELDS = ("name", "kana", "email", "phone", "mobile", "zip", "address", "prefecture",
          "company", "job", "birthday", "date", "datetime", "uuid", "int", "bool", "sentence")
FORMATS = ("json", "jsonl", "csv")
INLINE_LIMIT = 10  # これを超える件数は --out を必須にする（中間データを context に載せない）
RESERVED_EMAIL_DOMAINS = ("example.jp", "example.com")


def _load_faker(seed: int | None):
    try:
        from faker import Faker  # noqa: PLC0415
    except ImportError as exc:
        raise Abort("faker が無い。導入をユーザーに相談する（このスキルの他の群は faker 不要）") from exc
    fake = Faker("ja_JP")
    if seed is not None:
        Faker.seed(seed)
    return fake


def _ascii_local_part(fake) -> str:
    """ローカル部は ASCII に寄せる（日本語ローカル部を扱えない実装が多いため）。"""
    return fake.user_name()


def build_record(fake, fields: list[str], index: int, marker: bool) -> dict:
    getters = {
        "name": lambda: fake.name(),
        "kana": lambda: getattr(fake, "kana_name", fake.name)(),
        "email": lambda: f"{_ascii_local_part(fake)}@{RESERVED_EMAIL_DOMAINS[index % 2]}",
        "phone": lambda: f"03-0000-{fake.random_int(0, 9999):04d}",
        "mobile": lambda: f"090-0000-{fake.random_int(0, 9999):04d}",
        "zip": lambda: fake.zipcode(),
        "address": lambda: fake.address(),
        "prefecture": lambda: fake.prefecture(),
        "company": lambda: fake.company(),
        "job": lambda: fake.job(),
        "birthday": lambda: fake.date_of_birth(minimum_age=18, maximum_age=80).isoformat(),
        "date": lambda: fake.date_this_decade().isoformat(),
        "datetime": lambda: fake.date_time_this_year().isoformat(timespec="seconds"),
        "uuid": lambda: str(uuid.UUID(int=fake.random_int(0, 2**128 - 1), version=4)),
        "int": lambda: fake.random_int(1, 9999),
        "bool": lambda: fake.boolean(),
        "sentence": lambda: fake.sentence(),
    }
    record: dict = {}
    if marker:
        record["_fictional"] = True
    for field in fields:
        if field not in getters:
            raise Abort(f"未対応の項目: {field}（対応: {', '.join(FIELDS)}）")
        record[field] = getters[field]()
    return record


def _dump(records: list[dict], fmt: str) -> str:
    if fmt == "json":
        return json.dumps(records, ensure_ascii=False, indent=2) + "\n"
    if fmt == "jsonl":
        return "".join(json.dumps(r, ensure_ascii=False) + "\n" for r in records)
    buf = io.StringIO(newline="")
    writer = csv.DictWriter(buf, fieldnames=list(records[0]), lineterminator="\n")
    writer.writeheader()
    writer.writerows(records)
    return buf.getvalue()


def cmd_gen(args) -> int:
    fields = [f.strip() for f in args.fields.split(",") if f.strip()]
    if not fields:
        raise Abort("--fields を 1 つ以上指定する")
    if args.count > INLINE_LIMIT and not args.out:
        raise Abort(f"{INLINE_LIMIT} 件を超える生成は --out でファイルへ出す（生成物を context に載せない）")
    if args.count < 1:
        raise Abort("--count は 1 以上")
    fake = _load_faker(args.seed)
    records = [build_record(fake, fields, i, not args.no_marker) for i in range(args.count)]
    text = _dump(records, args.format)
    summary = {
        "count": len(records), "fields": fields, "format": args.format, "seed": args.seed,
        "fictional": True,
        "note": "架空データ。実在の個人・法人を指すものではない。本番データの代替として使う（.claude/rules/security-hardstops.md）",
        "placement": "src/ のテストフィクスチャまたは wip/ に置く。doc/・intake/ には置かない",
    }
    if args.out:
        summary.update(write_text_out(text, args.out))
    else:
        summary["sample"] = records
    return emit(summary)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="vnl.py testdata", description="架空のテストデータ生成（Faker ja_JP）")
    sub = parser.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("gen", help="項目を指定して生成")
    p.add_argument("--fields", required=True, help=f"カンマ区切り。対応: {', '.join(FIELDS)}")
    p.add_argument("--count", type=int, default=5)
    p.add_argument("--format", choices=FORMATS, default="json")
    p.add_argument("--seed", type=int, help="再現可能にする乱数シード（テストでは指定を推奨）")
    p.add_argument("--out", help=f"出力ファイル（{INLINE_LIMIT} 件超では必須）")
    p.add_argument("--no-marker", action="store_true", help="_fictional 列を付けない")
    p.set_defaults(func=cmd_gen)
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(run(main, sys.argv[1:]))
