# check-encoding

テキストファイルの文字コード（UTF-8）・改行コード・BOM を拡張子ごとの要件表に照らして検査する。ERROR で終了コード 1、`--fix` で BOM と改行を修正、ディレクトリ再帰対応

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | 共有スクリプト |
| 導入先 | `.claude/scripts/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 518ae8e） |

## これは何か

テキストファイルの文字コード（UTF-8）・改行コード・BOM を拡張子ごとの要件表に照らして検査する。ERROR で終了コード 1、`--fix` で BOM と改行を修正、ディレクトリ再帰対応

## なぜ作られたか

**失敗起点。** 2026-09-03〜04 に文字コード起因の失敗が **3 件連続**した（ADR-050）: ① `wizard/template.sh` 全 204 行が CRLF で Git Bash から実行不能（`bash -n` は終了コード 0 で通った） ② BOM 無し `.ps1` を PowerShell 5.1 が cp932 として読み **192 回の実測ジョブが起動直後に全滅** ③ heredoc 内のバックスラッシュ解釈でコード例が 2 行に割れた。**3 件の共通点は「書いた直後には気づけず、実行して初めて壊れる」**であり、規約の文言追加では防げないと判断して検査を機械化した

## 導入

```sh
mkdir -p .claude/scripts
cp -r scripts/* .claude/scripts/
```

## 収録ファイル

- `docs/text-encoding.md`（6.8 KB）
- `scripts/check-encoding.py`（7.0 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/docs/text-encoding.md` — **同梱**
- `.claude/rules/safe-file-ops.md` — 未同梱（別パッケージ `claude-rule-safe-file-ops` に収録）
- `.claude/scripts/check-encoding.py` — **同梱**
- `.claude/scripts/fix-bom.py` — 未同梱（別パッケージ `claude-script-fix-bom` に収録）

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
