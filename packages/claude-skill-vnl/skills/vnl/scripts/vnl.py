#!/usr/bin/env python3
"""vnl.py — ローカル完結の開発ユーティリティ群への単一入口。

`python .claude/skills/vnl/scripts/vnl.py <群> <サブコマンド> [オプション]`

群を 1 つの入口に束ねているのは、settings.json の allow パターンを 1 つに保ち、
実行ごとの承認ダイアログを増やさないため。群のモジュールは遅延 import するので、
未導入の任意依存（PyYAML / faker）はその群を使ったときだけ問題になる。

参照元: https://vnl.pages.dev/（Vanilla JS の開発者向けツール集）の掲載機能のうち、
本リポジトリの規約・成果物に直結するものを移植した。移植方針と選別の根拠は
doc/adr/20260827_033_vnl相当のローカル開発ユーティリティの統合.md を参照。

通信しない。外部送信を伴う機能は移植対象に含めない（.claude/rules/external-resources.md）。
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _common import fix_encoding  # noqa: E402

GROUPS = {
    "color": ("color", "色空間変換・WCAG コントラスト比・色覚多様性シミュレーション"),
    "security": ("security", "ハッシュ・エンコード・UUID・JWT デコード・パスワード生成"),
    "checkdigit": ("checkdigit", "検査数字（Luhn / EAN / ISBN / 法人番号 / 個人番号）の検証・生成"),
    "text": ("textconv", "JSON / YAML / CSV / TSV / Markdown 表 / XML の相互変換"),
    "testdata": ("testdata", "架空のテストデータ生成（Faker ja_JP）"),
    "cron": ("cronparse", "cron 式の解析と次回実行時刻の列挙"),
    "clock": ("clockcalc", "エポック・タイムゾーン・期間・営業日の計算"),
    "sqlite": ("sqliteq", "SQLite の SQL 実行・スキーマ抽出・実行計画"),
    "qr": ("qrcodes", "QR コードの生成（PNG / SVG / ASCII）と読み取り"),
}


def usage() -> str:
    lines = ["使い方: python .claude/skills/vnl/scripts/vnl.py <群> <サブコマンド> [オプション]", "", "群:"]
    lines += [f"  {name:<11} {desc}" for name, (_, desc) in GROUPS.items()]
    lines += ["", "各群のサブコマンド一覧: vnl.py <群> --help"]
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    fix_encoding()
    if not argv or argv[0] in ("-h", "--help", "help"):
        print(usage())
        return 0
    group = argv[0]
    if group not in GROUPS:
        print(f"未知の群: {group}\n\n{usage()}", file=sys.stderr)
        return 2
    module_name = GROUPS[group][0]
    module = __import__(module_name)
    from _common import run  # noqa: PLC0415
    return run(module.main, argv[1:])


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
