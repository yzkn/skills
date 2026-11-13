#!/usr/bin/env python3
"""cron — cron 式の解析と次回実行時刻の列挙（標準ライブラリのみ）。

Claude が cron 式を目で読んで「毎週月曜 9 時のはず」と判断すると、曜日の起点・
日と曜日の OR 規則・タイムゾーンの取り違えで誤る。機械的に展開して確定させる。

用途: CI（GitHub Actions 等）のスケジュール設定・運用設計の実行時刻の確認。
GitHub Actions の cron は UTC 基準のため、既定を UTC とし JST も併記する。
"""

from __future__ import annotations

import argparse
import re
import sys
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from _common import Abort, emit, run

FIELD_RANGES = ((0, 59), (0, 23), (1, 31), (1, 12), (0, 7))
FIELD_NAMES = ("minute", "hour", "day_of_month", "month", "day_of_week")
FIELD_LABELS_JA = ("分", "時", "日", "月", "曜日")
MONTH_NAMES = {n: i for i, n in enumerate(
    "jan feb mar apr may jun jul aug sep oct nov dec".split(), start=1)}
DOW_NAMES = {n: i for i, n in enumerate("sun mon tue wed thu fri sat".split())}
DOW_JA = ("日", "月", "火", "水", "木", "金", "土")
ALIASES = {
    "@yearly": "0 0 1 1 *", "@annually": "0 0 1 1 *", "@monthly": "0 0 1 * *",
    "@weekly": "0 0 * * 0", "@daily": "0 0 * * *", "@midnight": "0 0 * * *",
    "@hourly": "0 * * * *",
}
SEARCH_DAYS = 366 * 5  # 5 年先まで探して見つからなければ「実行されない式」と判定する


class Field:
    """1 フィールドの展開結果。`*` だったかどうかを保持する（日と曜日の OR 規則に必要）。"""

    def __init__(self, values: set[int], wildcard: bool) -> None:
        self.values = values
        self.wildcard = wildcard


def _parse_token(token: str, index: int) -> set[int]:
    lo, hi = FIELD_RANGES[index]
    names = MONTH_NAMES if index == 3 else (DOW_NAMES if index == 4 else {})

    def to_int(text: str) -> int:
        key = text.strip().lower()
        if key in names:
            return names[key]
        if not re.fullmatch(r"\d+", key):
            raise Abort(f"{FIELD_NAMES[index]} に解釈できない値: {text}")
        return int(key)

    step = 1
    if "/" in token:
        token, step_text = token.split("/", 1)
        if not re.fullmatch(r"\d+", step_text) or int(step_text) == 0:
            raise Abort(f"{FIELD_NAMES[index]} のステップが不正: /{step_text}")
        step = int(step_text)
    if token in ("*", ""):
        start, end = lo, hi
    elif "-" in token.lstrip("-"):
        a, b = token.split("-", 1)
        start, end = to_int(a), to_int(b)
    else:
        start = end = to_int(token)
    if not (lo <= start <= hi and lo <= end <= hi):
        raise Abort(f"{FIELD_NAMES[index]} は {lo}〜{hi} の範囲: {token}")
    if start > end:  # 5-1 のような巻き戻しは受け付けない（曖昧さを持ち込まない）
        raise Abort(f"{FIELD_NAMES[index]} の範囲が逆順: {token}")
    return set(range(start, end + 1, step))


def parse_field(text: str, index: int) -> Field:
    values: set[int] = set()
    for token in text.split(","):
        values |= _parse_token(token, index)
    if index == 4 and 7 in values:  # 曜日は 0 と 7 のどちらも日曜
        values = (values - {7}) | {0}
    return Field(values, text.strip() == "*")


def parse_cron(expr: str) -> list[Field]:
    text = ALIASES.get(expr.strip().lower(), expr).strip()
    parts = text.split()
    if len(parts) != 5:
        raise Abort(f"cron 式は 5 フィールド（分 時 日 月 曜日）。受け取ったのは {len(parts)} 個: {expr}")
    return [parse_field(p, i) for i, p in enumerate(parts)]


def _day_matches(fields: list[Field], moment: datetime) -> bool:
    """日と曜日の OR 規則: どちらも `*` でない場合はいずれか一方の一致で成立する（cron の仕様）。"""
    dom, dow = fields[2], fields[4]
    dom_ok = moment.day in dom.values
    dow_ok = (moment.weekday() + 1) % 7 in dow.values  # Python は月曜=0、cron は日曜=0
    if dom.wildcard or dow.wildcard:
        return dom_ok and dow_ok
    return dom_ok or dow_ok


def next_times(fields: list[Field], start: datetime, count: int) -> list[datetime]:
    base = start.replace(second=0, microsecond=0)
    hours, minutes = sorted(fields[1].values), sorted(fields[0].values)
    found: list[datetime] = []
    for offset in range(SEARCH_DAYS):
        day = (base + timedelta(days=offset)).replace(hour=0, minute=0)
        if day.month not in fields[3].values or not _day_matches(fields, day):
            continue
        for hh in hours:
            for mm in minutes:
                moment = day.replace(hour=hh, minute=mm)
                if moment <= start:
                    continue
                found.append(moment)
                if len(found) >= count:
                    return found
    return found


def _zone(name: str) -> ZoneInfo:
    try:
        return ZoneInfo(name)
    except (ZoneInfoNotFoundError, ValueError) as exc:
        raise Abort(f"タイムゾーンが解決できない: {name}") from exc


def _describe(fields: list[Field]) -> dict:
    def compact(field: Field, index: int) -> str:
        if field.wildcard:
            return "毎"
        vals = sorted(field.values)
        if index == 4:
            return "・".join(DOW_JA[v] for v in vals)
        return ",".join(str(v) for v in vals) if len(vals) <= 12 else f"{vals[0]}〜{vals[-1]} の {len(vals)} 通り"
    return {FIELD_LABELS_JA[i]: compact(f, i) for i, f in enumerate(fields)}


def cmd_next(args) -> int:
    fields = parse_cron(args.expr)
    tz = _zone(args.tz)
    if args.since:
        try:
            start = datetime.fromisoformat(args.since)
        except ValueError as exc:
            raise Abort(f"--since は ISO 8601 形式で指定する: {args.since}") from exc
        start = start.replace(tzinfo=tz) if start.tzinfo is None else start.astimezone(tz)
    else:
        start = datetime.now(tz)
    times = next_times(fields, start, args.count)
    jst = _zone("Asia/Tokyo")
    return emit({
        "expr": args.expr,
        "normalized": ALIASES.get(args.expr.strip().lower(), args.expr.strip()),
        "tz": args.tz,
        "since": start.isoformat(),
        "fields": _describe(fields),
        "day_rule": ("日と曜日の両方が指定されているため、いずれか一方に一致した日に実行される（cron の OR 規則）"
                     if not fields[2].wildcard and not fields[4].wildcard else None),
        "next": [{"local": t.isoformat(), "jst": t.astimezone(jst).isoformat(),
                  "dow": DOW_JA[(t.weekday() + 1) % 7]} for t in times],
        "note": None if times else f"{SEARCH_DAYS} 日先まで一致する時刻がない（実行されない式の可能性）",
    }, args.out)


def cmd_explain(args) -> int:
    fields = parse_cron(args.expr)
    return emit({
        "expr": args.expr,
        "normalized": ALIASES.get(args.expr.strip().lower(), args.expr.strip()),
        "fields": _describe(fields),
        "expanded": {FIELD_NAMES[i]: sorted(f.values) for i, f in enumerate(fields)},
        "day_rule": ("日と曜日の両方が指定されているため OR 規則が働く（どちらか一方の一致で実行）"
                     if not fields[2].wildcard and not fields[4].wildcard else "日と曜日の一方が `*` のため AND で解釈される"),
        "note": "GitHub Actions の cron は UTC 基準。JST の意図と 9 時間ずれていないか確認する",
    }, args.out)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="vnl.py cron", description="cron 式の解析と次回実行時刻の列挙")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("next", help="次回実行時刻を列挙する")
    p.add_argument("expr", help="cron 式（5 フィールド。@daily 等のエイリアスも可）")
    p.add_argument("--count", type=int, default=5)
    p.add_argument("--tz", default="UTC", help="cron を評価するタイムゾーン（既定 UTC。JST も併記される）")
    p.add_argument("--since", help="基準時刻（ISO 8601。既定は現在時刻）")
    p.set_defaults(func=cmd_next)

    p = sub.add_parser("explain", help="各フィールドの意味と展開結果を返す")
    p.add_argument("expr")
    p.set_defaults(func=cmd_explain)

    for child in sub.choices.values():
        child.add_argument("--out", help="結果 JSON の退避先")
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(run(main, sys.argv[1:]))
