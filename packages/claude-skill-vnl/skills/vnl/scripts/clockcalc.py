#!/usr/bin/env python3
"""clock — エポック変換・タイムゾーン変換・期間計算・営業日計算（標準ライブラリのみ）。

Claude が暗算するとずれる計算（エポック秒、タイムゾーン差、N 営業日後の日付）を
機械的に確定させる。主用途は WBS の日付整合（`.claude/rules/wbs-tasks.md`）。

祝日データは同梱しない。営業日計算は既定で土日のみを除外し、祝日・会社休日は
`--holidays <ファイル>` で渡す（1 行 1 日付 `YYYY-MM-DD`、`#` 以降はコメント）。
理由: 祝日データの同梱はリポジトリ容量・データのライセンス・毎年の更新運用という
負債を伴い、案件ごとに会社休日が異なるためファイル指定のほうが実用的である。
"""

from __future__ import annotations

import argparse
import re
import sys
from datetime import date, datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from _common import Abort, emit, run

MS_THRESHOLD = 10**11  # これ以上ならミリ秒とみなす（秒なら西暦 5138 年相当）
DOW_JA = ("月", "火", "水", "木", "金", "土", "日")


def _zone(name: str) -> ZoneInfo:
    try:
        return ZoneInfo(name)
    except (ZoneInfoNotFoundError, ValueError) as exc:
        raise Abort(f"タイムゾーンが解決できない: {name}") from exc


def _parse_dt(text: str, tz: ZoneInfo) -> datetime:
    try:
        moment = datetime.fromisoformat(text)
    except ValueError as exc:
        raise Abort(f"ISO 8601 形式で指定する（例 2026-08-27T09:00 / 2026-08-27）: {text}") from exc
    return moment.replace(tzinfo=tz) if moment.tzinfo is None else moment


def _parse_date(text: str) -> date:
    try:
        return date.fromisoformat(text)
    except ValueError as exc:
        raise Abort(f"日付は YYYY-MM-DD 形式で指定する: {text}") from exc


def load_holidays(path: str | None) -> set[date]:
    """祝日・会社休日の一覧を読む。1 行 1 日付、`#` 以降はコメント、CSV の 1 列目も可。"""
    if not path:
        return set()
    file = Path(path)
    if not file.is_file():
        raise Abort(f"祝日ファイルが無い: {file}")
    days: set[date] = set()
    for lineno, raw in enumerate(file.read_text(encoding="utf-8-sig").splitlines(), start=1):
        line = raw.split("#", 1)[0].split(",", 1)[0].strip()
        if not line:
            continue
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", line):
            raise Abort(f"{file}:{lineno} が YYYY-MM-DD ではない: {raw.strip()!r}")
        days.add(_parse_date(line))
    return days


def is_business_day(day: date, holidays: set[date]) -> bool:
    return day.weekday() < 5 and day not in holidays


def cmd_epoch(args) -> int:
    tz = _zone(args.tz)
    if args.value is None:
        raise Abort("--value にエポック秒／ミリ秒、または ISO 8601 の時刻を指定する")
    text = args.value.strip()
    if re.fullmatch(r"-?\d+(\.\d+)?", text):
        number = float(text)
        unit = "milliseconds" if abs(number) >= MS_THRESHOLD else "seconds"
        seconds = number / 1000 if unit == "milliseconds" else number
        moment = datetime.fromtimestamp(seconds, tz=tz)
        direction = "epoch -> iso"
    else:
        moment = _parse_dt(text, tz)
        unit, direction = "seconds", "iso -> epoch"
    return emit({
        "input": text, "direction": direction, "detected_unit": unit, "tz": args.tz,
        "iso_local": moment.isoformat(),
        "iso_utc": moment.astimezone(_zone("UTC")).isoformat(),
        "iso_jst": moment.astimezone(_zone("Asia/Tokyo")).isoformat(),
        "epoch_seconds": int(moment.timestamp()),
        "epoch_milliseconds": int(moment.timestamp() * 1000),
        "dow": DOW_JA[moment.weekday()],
    }, args.out)


def cmd_convert(args) -> int:
    src, dst = _zone(args.from_tz), _zone(args.to_tz)
    moment = _parse_dt(args.time, src)
    converted = moment.astimezone(dst)
    offset_hours = (converted.utcoffset() - moment.utcoffset()).total_seconds() / 3600
    return emit({
        "input": args.time, "from_tz": args.from_tz, "to_tz": args.to_tz,
        "from": moment.isoformat(), "to": converted.isoformat(),
        "offset_diff_hours": offset_hours,
        "dow_from": DOW_JA[moment.weekday()], "dow_to": DOW_JA[converted.weekday()],
        "date_changed": moment.date() != converted.date(),
    }, args.out)


def cmd_diff(args) -> int:
    tz = _zone(args.tz)
    start, end = _parse_dt(args.since, tz), _parse_dt(args.until, tz)
    delta = end - start
    total_seconds = delta.total_seconds()
    holidays = load_holidays(args.holidays)
    days = (end.date() - start.date()).days
    business = sum(1 for i in range(days + 1)
                   if is_business_day(start.date() + timedelta(days=i), holidays))
    return emit({
        "since": start.isoformat(), "until": end.isoformat(),
        "days": delta.days, "seconds": int(total_seconds),
        "hours": round(total_seconds / 3600, 2),
        "calendar_days_inclusive": days + 1,
        "business_days_inclusive": business,
        "holidays_loaded": len(holidays),
        "note": "business_days は両端を含む。土日と --holidays の日付を除外する",
    }, args.out)


def cmd_add(args) -> int:
    tz = _zone(args.tz)
    moment = _parse_dt(args.time, tz)
    result = moment + timedelta(days=args.days, hours=args.hours, minutes=args.minutes)
    return emit({
        "input": moment.isoformat(), "added": {"days": args.days, "hours": args.hours, "minutes": args.minutes},
        "result": result.isoformat(), "dow": DOW_JA[result.weekday()],
    }, args.out)


def cmd_business(args) -> int:
    """N 営業日後（負値なら前）の日付を求める。WBS の開始日・期限の連動に使う。"""
    holidays = load_holidays(args.holidays)
    start = _parse_date(args.since)
    if args.days == 0:
        raise Abort("--days は 0 以外を指定する（0 営業日後は起点そのもの）")
    step = 1 if args.days > 0 else -1
    remaining, cursor, skipped = abs(args.days), start, []
    while remaining > 0:
        cursor += timedelta(days=step)
        if is_business_day(cursor, holidays):
            remaining -= 1
        else:
            skipped.append(cursor.isoformat())
    return emit({
        "since": start.isoformat(), "since_is_business_day": is_business_day(start, holidays),
        "days": args.days, "result": cursor.isoformat(), "dow": DOW_JA[cursor.weekday()],
        "skipped": skipped, "holidays_loaded": len(holidays),
        "note": "起点は数えない。土日と --holidays の日付を飛ばす",
    }, args.out)


def _add_tz(parser, default: str = "Asia/Tokyo") -> None:
    parser.add_argument("--tz", default=default, help=f"タイムゾーン（既定 {default}）")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="vnl.py clock", description="エポック・タイムゾーン・期間・営業日の計算")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("epoch", help="エポック秒／ミリ秒 と ISO 8601 の相互変換（単位は自動判定）")
    p.add_argument("value")
    _add_tz(p)
    p.set_defaults(func=cmd_epoch)

    p = sub.add_parser("convert", help="タイムゾーン変換")
    p.add_argument("time")
    p.add_argument("--from-tz", dest="from_tz", required=True)
    p.add_argument("--to-tz", dest="to_tz", required=True)
    p.set_defaults(func=cmd_convert)

    p = sub.add_parser("diff", help="2 時刻の期間と、その間の営業日数")
    p.add_argument("--since", required=True)
    p.add_argument("--until", required=True)
    p.add_argument("--holidays", help="祝日・会社休日のファイル（1 行 1 日付）")
    _add_tz(p)
    p.set_defaults(func=cmd_diff)

    p = sub.add_parser("add", help="時刻に日・時・分を加算する")
    p.add_argument("time")
    p.add_argument("--days", type=int, default=0)
    p.add_argument("--hours", type=int, default=0)
    p.add_argument("--minutes", type=int, default=0)
    _add_tz(p)
    p.set_defaults(func=cmd_add)

    p = sub.add_parser("business", help="N 営業日後（負値なら前）の日付")
    p.add_argument("--since", required=True, help="起点の日付（YYYY-MM-DD）")
    p.add_argument("--days", type=int, required=True)
    p.add_argument("--holidays", help="祝日・会社休日のファイル（1 行 1 日付）")
    p.set_defaults(func=cmd_business)

    for child in sub.choices.values():
        child.add_argument("--out", help="結果 JSON の退避先")
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(run(main, sys.argv[1:]))
