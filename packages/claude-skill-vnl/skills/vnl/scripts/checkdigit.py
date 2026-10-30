#!/usr/bin/env python3
"""checkdigit — 検査数字（チェックデジット）の検証と生成（標準ライブラリのみ）。

用途: 業務システムのバリデーション実装と、テストデータの「形式として妥当な番号」の用意。
対象の値は秘密ではないため引数で受け取る（security モジュールと方針が異なる）。

検証状況:
  - luhn / ean8 / ean13 / isbn13 は selftest で公知の例と突き合わせて確認する。
  - jpcorp（法人番号）・mynumber（個人番号）は公表されている算出式に基づく実装だが、
    公的機関が示す既知サンプルとの突き合わせは未実施。生成 → 検証の往復整合のみ確認済み。
"""

from __future__ import annotations

import argparse
import random
import sys

from _common import Abort, emit, run

KINDS = ("luhn", "ean8", "ean13", "isbn13", "jpcorp", "mynumber")
LENGTH = {"luhn": None, "ean8": 8, "ean13": 13, "isbn13": 13, "jpcorp": 13, "mynumber": 12}


def _digits(value: str) -> list[int]:
    s = "".join(ch for ch in value if ch.isdigit())
    if not s:
        raise Abort(f"数字が含まれていない: {value}")
    return [int(ch) for ch in s]


# ---------------------------------------------------------------- 各方式の検査数字

def luhn_check(body: list[int]) -> int:
    """Luhn（クレジットカード・IMEI 等）。body は検査数字を除いた並び。"""
    total = 0
    for i, d in enumerate(reversed(body)):
        v = d * 2 if i % 2 == 0 else d
        total += v - 9 if v > 9 else v
    return (10 - total % 10) % 10


def ean_check(body: list[int]) -> int:
    """EAN-8 / EAN-13 / JAN / ISBN-13。左端から重み 1,3,1,3,... を掛ける方式。

    EAN-8 は本体 7 桁で左端の重みが 3、EAN-13 は本体 12 桁で左端の重みが 1 になる。
    どちらも「右端（検査数字の隣）の重みが 3」で揃うため、末尾から数えて決める。
    """
    total = 0
    for i, d in enumerate(reversed(body)):
        total += d * (3 if i % 2 == 0 else 1)
    return (10 - total % 10) % 10


def jpcorp_check(body: list[int]) -> int:
    """法人番号（13 桁）。検査数字は先頭 1 桁で、body は後続 12 桁。

    算出式: 9 - (Σ P_n × Q_n) mod 9
      P_n = 1 の位から上位へ n 桁目、Q_n = n が奇数なら 1、偶数なら 2
    """
    if len(body) != 12:
        raise Abort(f"法人番号の本体は 12 桁（受け取ったのは {len(body)} 桁）")
    total = sum(d * (1 if (i + 1) % 2 else 2) for i, d in enumerate(reversed(body)))
    return 9 - total % 9


def mynumber_check(body: list[int]) -> int:
    """個人番号（12 桁）。検査数字は末尾 1 桁で、body は先頭 11 桁。

    算出式: 11 - (Σ P_n × Q_n) mod 11 、ただし (Σ mod 11) <= 1 のときは 0
      P_n = 下位（検査数字を除いた末尾）から n 桁目
      Q_n = n + 1 (1<=n<=6) / n - 5 (7<=n<=11)
    """
    if len(body) != 11:
        raise Abort(f"個人番号の本体は 11 桁（受け取ったのは {len(body)} 桁）")
    total = 0
    for i, d in enumerate(reversed(body)):
        n = i + 1
        total += d * (n + 1 if n <= 6 else n - 5)
    rem = total % 11
    return 0 if rem <= 1 else 11 - rem


# 検査数字が先頭に付く方式（jpcorp）と末尾に付く方式（それ以外）を分けて扱う。
CHECK_AT_HEAD = {"jpcorp"}
CHECKER = {
    "luhn": luhn_check, "ean8": ean_check, "ean13": ean_check,
    "isbn13": ean_check, "jpcorp": jpcorp_check, "mynumber": mynumber_check,
}


def split_body(kind: str, digits: list[int]) -> tuple[list[int], int]:
    expect = LENGTH[kind]
    if expect and len(digits) != expect:
        raise Abort(f"{kind} は {expect} 桁（受け取ったのは {len(digits)} 桁）")
    if kind in CHECK_AT_HEAD:
        return digits[1:], digits[0]
    return digits[:-1], digits[-1]


def compose(kind: str, body: list[int], check: int) -> str:
    seq = [check, *body] if kind in CHECK_AT_HEAD else [*body, check]
    return "".join(str(d) for d in seq)


def cmd_verify(args) -> int:
    digits = _digits(args.value)
    body, actual = split_body(args.kind, digits)
    expected = CHECKER[args.kind](body)
    return emit({
        "kind": args.kind, "value": "".join(str(d) for d in digits),
        "check_digit_position": "head" if args.kind in CHECK_AT_HEAD else "tail",
        "actual": actual, "expected": expected, "valid": actual == expected,
    }, args.out)


def cmd_generate(args) -> int:
    expect = LENGTH[args.kind]
    body_len = (expect - 1) if expect else args.length
    if not body_len or body_len < 1:
        raise Abort("luhn は --length（本体の桁数）が必要")
    rng = random.Random(args.seed)
    values = []
    for _ in range(args.count):
        body = [rng.randrange(10) for _ in range(body_len)]
        values.append(compose(args.kind, body, CHECKER[args.kind](body)))
    return emit({
        "kind": args.kind, "count": len(values), "value": values,
        "note": "検査数字として整合する架空の番号。実在の企業・個人に割り当てられた番号と一致する保証はない",
    }, args.out)


def cmd_selftest(args) -> int:
    """公知の例で実装を突き合わせる。jpcorp / mynumber は往復整合のみ検証する。"""
    # 13 桁の公知例はハイフン区切りの正式表記で書く（`_digits` が区切りを除くため判定は同じ）。
    # 連続 13 桁の literal は gitleaks の法人番号ルール（\b[1-9]\d{12}\b）に誤検知される。
    cases = [
        ("luhn", "79927398713", True), ("luhn", "79927398710", False),
        ("ean13", "978-0-306-40615-7", True), ("ean13", "978-0-306-40615-8", False),
        ("ean8", "96385074", True), ("isbn13", "978-4-87311-565-8", None),
    ]
    results = []
    for kind, value, want in cases:
        body, actual = split_body(kind, _digits(value))
        ok = actual == CHECKER[kind](body)
        results.append({"kind": kind, "value": value, "valid": ok,
                        "expected_valid": want, "matched": None if want is None else ok == want})
    roundtrip = []
    rng = random.Random(0)
    for kind in ("jpcorp", "mynumber", "luhn"):
        body_len = (LENGTH[kind] - 1) if LENGTH[kind] else 15
        for _ in range(200):
            body = [rng.randrange(10) for _ in range(body_len)]
            value = compose(kind, body, CHECKER[kind](body))
            b2, actual = split_body(kind, _digits(value))
            if actual != CHECKER[kind](b2):
                roundtrip.append({"kind": kind, "value": value, "ok": False})
                break
        else:
            roundtrip.append({"kind": kind, "trials": 200, "ok": True})
    failed = [r for r in results if r["matched"] is False] + [r for r in roundtrip if not r["ok"]]
    payload = {"known_examples": results, "roundtrip": roundtrip, "failed": failed,
               "verdict": "ok" if not failed else "failed",
               "note": "jpcorp / mynumber は公的な既知サンプルとの突き合わせが未実施（往復整合のみ）"}
    emit(payload, args.out)
    return 0 if not failed else 1


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="vnl.py checkdigit", description="検査数字の検証・生成")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("verify", help="検査数字の検証")
    p.add_argument("--kind", choices=KINDS, required=True)
    p.add_argument("value")
    p.set_defaults(func=cmd_verify)

    p = sub.add_parser("generate", help="検査数字として整合する架空の番号を生成")
    p.add_argument("--kind", choices=KINDS, required=True)
    p.add_argument("--count", type=int, default=1)
    p.add_argument("--length", type=int, help="luhn のみ: 本体の桁数")
    p.add_argument("--seed", type=int, help="再現可能にする乱数シード")
    p.set_defaults(func=cmd_generate)

    p = sub.add_parser("selftest", help="公知の例と往復整合で実装を検証（不一致があれば終了コード 1）")
    p.set_defaults(func=cmd_selftest)

    for child in sub.choices.values():
        child.add_argument("--out", help="結果 JSON の退避先")
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(run(main, sys.argv[1:]))
