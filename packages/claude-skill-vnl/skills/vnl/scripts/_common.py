#!/usr/bin/env python3
"""vnl 共通基盤 — 出力の文字コード固定・要約 JSON 出力・入力経路の制限。

設計方針:
  - 中間データをコンテキストに載せない。stdout には要約 JSON のみを出す。
  - 秘密になりうる入力（ハッシュ対象・JWT・HMAC 鍵）はコマンドライン引数で
    受け取らない。プロセス一覧とシェル履歴に残るため、ファイルか stdin に限る。
  - 通信しない。urllib.request / socket / http は import しない
    （urllib.parse だけは純粋な文字列処理のため使う）。
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


class Abort(Exception):
    """安全条件・前提を満たさないため中断する（症状を隠した続行はしない）。"""


def fix_encoding() -> None:
    """Windows の既定コンソール（cp932）で日本語出力が落ちるのを防ぐ。"""
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")


def emit(payload: dict, out: str | None = None, root: Path | None = None) -> int:
    """要約 JSON を stdout へ出す。out 指定時は本体をファイルへ退避する。"""
    text = json.dumps(payload, ensure_ascii=False, indent=2)
    if not out:
        print(text)
        return 0
    dest = (root or Path.cwd()) / out if not Path(out).is_absolute() else Path(out)
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(text + "\n", encoding="utf-8")
    print(json.dumps({"out": str(dest), "bytes": dest.stat().st_size}, ensure_ascii=False))
    return 0


def write_text_out(text: str, out: str) -> dict:
    """テキスト本体をファイルへ書き出し、要約用の情報を返す。"""
    dest = Path(out)
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(text, encoding="utf-8")
    size = dest.stat().st_size
    if size == 0 and text:
        raise Abort(f"書き込み結果が 0 バイトになった: {dest}")
    return {"out": str(dest), "bytes": size, "lines": text.count("\n")}


def read_secret_bytes(in_file: str | None, use_stdin: bool) -> bytes:
    """秘密になりうる入力を受け取る。--text 相当の引数経路は用意しない。"""
    if bool(in_file) == bool(use_stdin):
        raise Abort("--in-file と --stdin のどちらか一方を指定する（引数で値を渡す経路は用意しない）")
    if use_stdin:
        return sys.stdin.buffer.read()
    path = Path(in_file)  # type: ignore[arg-type]
    if not path.is_file():
        raise Abort(f"入力ファイルが無い: {path}")
    return path.read_bytes()


def read_text_input(in_file: str | None, use_stdin: bool) -> str:
    return read_secret_bytes(in_file, use_stdin).decode("utf-8", errors="replace")


def run(main_func, argv: list[str]) -> int:
    """各モジュールの main を共通のエラー処理で包む。"""
    fix_encoding()
    try:
        return main_func(argv)
    except Abort as exc:
        print(json.dumps({"error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        return 2
