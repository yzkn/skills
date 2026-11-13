"""UTF-8 BOM を正確に 1 つ付与するスクリプト。

.claude/hooks/ 配下の PowerShell スクリプト等、BOM 必須ファイルを
Write / Edit ツールで変更した後に実行する。多重 BOM も 1 つに正規化する。

使い方:
    python .claude/scripts/fix-bom.py <ファイルパス> [<ファイルパス> ...]
"""
import sys

BOM = b"\xef\xbb\xbf"


def fix_bom(path: str) -> str:
    with open(path, "rb") as f:
        data = f.read()
    if not data:
        return f"SKIP (0 bytes): {path}"
    stripped = data
    while stripped.startswith(BOM):
        stripped = stripped[len(BOM):]
    fixed = BOM + stripped
    if fixed == data:
        return f"OK (already single BOM): {path}"
    with open(path, "wb") as f:
        f.write(fixed)
    return f"FIXED: {path} ({len(data)} -> {len(fixed)} bytes)"


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    for path in sys.argv[1:]:
        print(fix_bom(path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
