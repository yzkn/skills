# 文字コード・改行コード・BOM の要件（常時ロードしない）

ファイルを新規作成・編集する前後に参照する。規約本体は [`.claude/rules/safe-file-ops.md`](../rules/safe-file-ops.md)（常時適用）にあり、本ファイルはその根拠・要件表・落とし穴を担う。

**この種の不一致は「書いた直後には気づけず、後で実行したときに壊れる」形で現れる。** 実際に本リポジトリで 3 件連続で発生した（末尾「実測した事例」）。書いたら測る。

---

## 1. 検証コマンド

```sh
python .claude/scripts/check-encoding.py <パス...>          # 検査のみ（ERROR があれば終了コード 1）
python .claude/scripts/check-encoding.py <パス...> --fix    # BOM と改行を修正する
python .claude/scripts/check-encoding.py .claude --quiet    # ディレクトリを再帰検査（OK 行を出さない）
```

- **ERROR** = そのまま実行・解析すると壊れるもの。**WARN** = 差分が汚れるだけで動作は壊れないもの
- `--fix` が直せるのは BOM と改行コードだけである。**UTF-8 として読めないファイルは自動修正しない**（元の文字コードを推定して変換すると別の壊れ方をするため、手動で対処する）
- BOM の付与だけなら `python .claude/scripts/fix-bom.py <パス...>` でもよい（多重 BOM も 1 つに正規化する）

---

## 2. 種別ごとの要件

| 拡張子 | BOM | 改行 | 理由 |
|---|---|---|---|
| `.ps1` `.psm1` `.psd1` | **必須** | 任意 | **PowerShell 5.1 は BOM の無い UTF-8 を cp932 として読む。** 日本語のコメント・文字列が壊れ、文字列リテラルの終端を見失って `TerminatorExpectedAtEndOfString` 等の構文エラーになる。7.x（`pwsh`）は既定 UTF-8 だが、この端末は 5.1 と 7.6 が同居しており、`powershell -File` で起動すると 5.1 が使われる |
| `.sh` `.bash` | **禁止** | **LF** | BOM は shebang（`#!/usr/bin/env bash`）の先頭に入り込んで実行を壊す。CRLF は行末の `\r` がコマンドの一部として読まれ `$'\r': command not found` になる |
| `.py` | 禁止 | 任意 | Python 3 の既定は UTF-8（PEP 3120）。BOM 付きでも動くが、一部ツールの読み取りを壊す |
| `.json` `.yml` `.yaml` `.toml` | 禁止 | 任意 | パーサが BOM を受け付けないことがある |
| `.md` `.txt` `.js` `.mjs` `.ts` `.css` `.html` | 禁止 | 任意 | BOM は不要。混在すると差分が汚れる |
| `.bat` `.cmd` | 任意 | CRLF 推奨 | `cmd.exe` は LF のみのバッチでラベル・`goto` を誤解釈することがある |

**文字コードはすべて UTF-8 に統一する。** cp932（Shift_JIS）で保存されたファイルは、Python・git・多くのツールで読めない。

---

## 3. 書き込み手段ごとの落とし穴

| 手段 | 既定の挙動 | 必要な対処 |
|---|---|---|
| **Write / Edit ツール** | UTF-8・BOM なし・LF | `.ps1` を書いたら **`fix-bom.py` か `check-encoding.py --fix` で BOM を付ける** |
| **Bash の heredoc** | 内容によってはバックスラッシュが解釈される | **`\r` `\n` `\t` などのエスケープを含む内容を heredoc で書かない。** 実際に `b'\r\n'` と書いたつもりが実際の改行になり、コード例が 2 行に割れた（2026-09-03 実測）。この用途では Write / Edit ツールを使う |
| **PowerShell の `>` / `Out-File`** | **5.1 の既定は UTF-16LE**（`Set-Content` は cp932） | PowerShell からテキストを書かない。書く場合は `-Encoding utf8` を明示し、5.1 では BOM が付くことを前提にする |
| **外部リポジトリからのコピー** | `core.autocrlf=true` の環境で clone すると**作業ツリーが CRLF になる** | `cp` は改行を変換しないため、CRLF のまま持ち込まれる。**取り込んだら必ず検査する** |
| **`robocopy` / `cp`** | バイト列をそのまま複製する | コピー元の状態がそのまま持ち込まれる |

---

## 4. 検出できない・しにくいもの

- **`bash -n` は CRLF のスクリプトを通す。** 構文検査は成功（終了コード 0）するのに実行できない。改行コードは別に確認する
- **Python は BOM 付きの `.py` を実行できる。** BOM の有無は実行時エラーにならず、別のツールが読んだときに初めて壊れる
- **`git diff` は改行コードの違いを見せないことがある。** `.gitattributes` の `* text=auto` が格納時に LF へ正規化するため、作業ツリーが CRLF でも差分に現れない
- **PowerShell の構文エラーは原因を指さない。** BOM 欠落による文字化けは「文字列の終端が見つからない」等として報告され、文字コードの問題だとは書かれていない

---

## 5. git 側の防御と、その限界

本リポジトリの [`.gitattributes`](../../.gitattributes) は次を指定している。

```
* text=auto          # 格納時に LF へ正規化する
*.sh text eol=lf     # シェルスクリプトはチェックアウトも LF にする
```

- **効くのは「git を経由したとき」だけである。** clone・checkout したファイルは正規化されるが、**作業ツリーで直接書いたファイル・他所からコピーしたファイルには効かない**
- **BOM は git の管理外である。** `text=auto` は BOM を付けも消しもしないため、`.ps1` の BOM 欠落は git では防げない
- したがって `.gitattributes` があっても、**書いた直後の検査は省略できない**

---

## 6. 実測した事例

| 事例 | 症状 | 原因 | ADR |
|---|---|---|---|
| `wizard/template.sh` が全 204 行 CRLF | Git Bash で実行不能。`bash -n` は通っていた | 上流を `core.autocrlf=true` の環境で clone し、`cp` で持ち込んだ | ADR-049 |
| `wip/trigger-eval-batch.ps1` が BOM なし | PowerShell 5.1 が cp932 と解釈し `TerminatorExpectedAtEndOfString` でジョブが失敗 | Write ツールが BOM なしで書いた | ADR-050 |
| SKILL.md のコード例が 2 行に割れた | `b'\r\n'` と書いたはずが実際の改行になった | Bash heredoc 内のバックスラッシュが解釈された | ADR-050 |
| 自動記録の trace ログが文字化け | ログの日本語が読めない | PowerShell 5.1 の出力エンコーディング | — |
| `anthropics/web-artifacts-builder/scripts/*.sh` が CRLF | 実行すれば失敗する状態だった | 上流の clone 経由 | ADR-049 |

> Python ツールが `claude -p` の出力を読むときの `cp932` / `WinError 10038` は、本ファイルではなく [`windows-python-tooling.md`](windows-python-tooling.md) が扱う（**ファイルの中身**ではなく**プロセス間のストリーム**の問題であるため）。
