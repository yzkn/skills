#!/usr/bin/env python3
"""security — ハッシュ・エンコード・UUID・JWT デコード・パスワード生成（標準ライブラリのみ）。

Claude が記憶や暗算で答えると誤った値を出す典型（ダイジェスト・Base64・UUID）を
機械的に算出する。設計上の制約:
  - 秘密になりうる入力（ハッシュ対象・HMAC 鍵・JWT）はコマンドライン引数で受け取らない。
  - JWT は署名検証をしない。鍵を扱わず、既定ではクレームの値も出さない（キーと時刻のみ）。
  - 通信しない（urllib.parse は純粋な文字列処理。urllib.request は import しない）。
"""

from __future__ import annotations

import argparse
import base64
import binascii
import hashlib
import hmac
import json
import secrets
import string
import sys
import urllib.parse
import uuid
from datetime import datetime, timezone
from pathlib import Path

from _common import Abort, emit, read_secret_bytes, run

ALGOS = ("sha256", "sha384", "sha512", "sha1", "md5", "blake2b", "sha3_256")
CODECS = ("base64", "base64url", "hex", "url")
TIME_CLAIMS = ("iat", "exp", "nbf", "auth_time", "updated_at")
# 紛らわしい文字（O/0・l/1/I）を除いた文字集合。読み上げ・転記の誤りを避ける。
PW_LOWER = "abcdefghijkmnopqrstuvwxyz"
PW_UPPER = "ABCDEFGHJKLMNPQRSTUVWXYZ"
PW_DIGIT = "23456789"
PW_SYMBOL = "!#%+-=?@_"


def cmd_hash(args) -> int:
    data = read_secret_bytes(args.in_file, args.stdin)
    if args.hmac_key_file:
        key = Path(args.hmac_key_file).read_bytes()
        digest = hmac.new(key, data, args.algo).hexdigest()
        mode = f"HMAC-{args.algo}"
    else:
        digest = hashlib.new(args.algo, data).hexdigest()
        mode = args.algo
    return emit({
        "mode": mode,
        "input_bytes": len(data),
        "digest_hex": digest,
        "digest_base64": base64.b64encode(bytes.fromhex(digest)).decode(),
    }, args.out)


def _encode(data: bytes, codec: str) -> str:
    if codec == "base64":
        return base64.b64encode(data).decode()
    if codec == "base64url":
        return base64.urlsafe_b64encode(data).decode().rstrip("=")
    if codec == "hex":
        return data.hex()
    return urllib.parse.quote(data.decode("utf-8", errors="strict"), safe="")


def _decode(text: str, codec: str) -> bytes:
    try:
        if codec == "base64":
            return base64.b64decode(text, validate=True)
        if codec == "base64url":
            return base64.urlsafe_b64decode(text + "=" * (-len(text) % 4))
        if codec == "hex":
            return bytes.fromhex(text.strip())
        return urllib.parse.unquote(text).encode()
    except (binascii.Error, ValueError) as exc:
        raise Abort(f"{codec} として復号できない: {exc}") from exc


def cmd_encode(args) -> int:
    data = read_secret_bytes(args.in_file, args.stdin)
    return emit({"codec": args.codec, "input_bytes": len(data), "encoded": _encode(data, args.codec)}, args.out)


def cmd_decode(args) -> int:
    text = read_secret_bytes(args.in_file, args.stdin).decode("utf-8", errors="replace").strip()
    raw = _decode(text, args.codec)
    printable = raw.decode("utf-8", errors="replace")
    return emit({
        "codec": args.codec,
        "output_bytes": len(raw),
        "decoded": printable if args.show else None,
        "note": None if args.show else "値は既定で出力しない。必要なら --show を付ける（機密が context に載る点に注意）",
    }, args.out)


def cmd_uuid(args) -> int:
    if args.version == 7 and not hasattr(uuid, "uuid7"):
        raise Abort("この Python には uuid.uuid7 が無い（3.14 以降が必要）。--version 4 を使う")
    gen = {4: uuid.uuid4, 7: getattr(uuid, "uuid7", None)}[args.version]
    values = [str(gen()) for _ in range(args.count)]  # type: ignore[misc]
    return emit({"version": args.version, "count": len(values), "uuid": values}, args.out)


def _b64url_json(segment: str) -> dict:
    raw = base64.urlsafe_b64decode(segment + "=" * (-len(segment) % 4))
    return json.loads(raw.decode("utf-8"))


def _fmt_epoch(value) -> str | None:
    if not isinstance(value, (int, float)):
        return None
    return datetime.fromtimestamp(value, tz=timezone.utc).isoformat()


def cmd_jwt(args) -> int:
    token = read_secret_bytes(args.in_file, args.stdin).decode("utf-8", errors="replace").strip()
    parts = token.split(".")
    if len(parts) != 3:
        raise Abort(f"JWT は 3 つのセグメントが必要（受け取ったのは {len(parts)}）")
    try:
        header, payload = _b64url_json(parts[0]), _b64url_json(parts[1])
    except (binascii.Error, ValueError, UnicodeDecodeError) as exc:
        raise Abort(f"JWT のデコードに失敗: {exc}") from exc
    now = datetime.now(tz=timezone.utc).timestamp()
    warnings = []
    if str(header.get("alg", "")).lower() == "none":
        warnings.append("alg=none — 署名なしトークン。受理する実装は脆弱")
    if isinstance(payload.get("exp"), (int, float)) and payload["exp"] < now:
        warnings.append("exp が過去 — 期限切れ")
    result = {
        "header": header,
        "signature_verified": False,
        "signature_note": "このツールは署名検証をしない（鍵を扱わない）。検証は実装側の責務",
        "claim_keys": sorted(payload),
        "times": {k: _fmt_epoch(payload.get(k)) for k in TIME_CLAIMS if k in payload},
        "warnings": warnings,
    }
    if args.full:
        result["payload"] = payload
    else:
        result["payload_note"] = "クレームの値は既定で出力しない。必要なら --full（機密が context に載る点に注意。--out 併用を推奨）"
    return emit(result, args.out)


def cmd_password(args) -> int:
    pools = [PW_LOWER, PW_UPPER, PW_DIGIT] + ([PW_SYMBOL] if args.symbols else [])
    if args.length < len(pools):
        raise Abort(f"--length は {len(pools)} 以上にする（各文字種を 1 文字以上含めるため）")
    alphabet = "".join(pools)
    out = []
    for _ in range(args.count):
        while True:
            pw = "".join(secrets.choice(alphabet) for _ in range(args.length))
            if all(any(c in pool for c in pw) for pool in pools):
                out.append(pw)
                break
    return emit({
        "count": len(out), "length": args.length, "symbols": args.symbols, "password": out,
        "note": "生成値はこの出力にしか残らない。コードや設計書へ直書きしない（.claude/rules/security-hardstops.md）",
    }, args.out)


def _add_input_opts(parser) -> None:
    parser.add_argument("--in-file", help="入力ファイル（秘密値は引数ではなくこの経路で渡す）")
    parser.add_argument("--stdin", action="store_true", help="標準入力から読む")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="vnl.py security", description="ハッシュ・エンコード・UUID・JWT デコード・パスワード生成")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("hash", help="ダイジェスト（HMAC 対応）")
    p.add_argument("--algo", choices=ALGOS, default="sha256")
    p.add_argument("--hmac-key-file", help="HMAC 鍵のファイル（鍵を引数で渡す経路は用意しない）")
    _add_input_opts(p)
    p.set_defaults(func=cmd_hash)

    p = sub.add_parser("encode", help="Base64 / Base64URL / Hex / URL エンコード")
    p.add_argument("--codec", choices=CODECS, default="base64")
    _add_input_opts(p)
    p.set_defaults(func=cmd_encode)

    p = sub.add_parser("decode", help="同デコード（既定では値を出力しない）")
    p.add_argument("--codec", choices=CODECS, default="base64")
    p.add_argument("--show", action="store_true", help="復号結果そのものを出力する")
    _add_input_opts(p)
    p.set_defaults(func=cmd_decode)

    p = sub.add_parser("uuid", help="UUID の生成")
    p.add_argument("--version", type=int, choices=(4, 7), default=4)
    p.add_argument("--count", type=int, default=1)
    p.set_defaults(func=cmd_uuid)

    p = sub.add_parser("jwt", help="JWT のデコード（署名検証はしない）")
    p.add_argument("--full", action="store_true", help="ペイロードの値も出力する")
    _add_input_opts(p)
    p.set_defaults(func=cmd_jwt)

    p = sub.add_parser("password", help="パスワード生成（secrets モジュール）")
    p.add_argument("--length", type=int, default=20)
    p.add_argument("--count", type=int, default=1)
    p.add_argument("--symbols", action="store_true")
    p.set_defaults(func=cmd_password)

    for name, child in sub.choices.items():
        child.add_argument("--out", help="結果 JSON の退避先")
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(run(main, sys.argv[1:]))
