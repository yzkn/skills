# auto-record.ps1

各会話ターン終了時にトランスクリプト `.jsonl` から user / assistant メッセージを抽出し、`doc/prompt/YYYYMMDD_HHMMSS_auto.proof.md` として保存して自動コミットする（1 ファイル 30,000 文字で打ち切り）

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code フック |
| 導入先 | `.claude/hooks/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 89f3c5a） |

## これは何か

各会話ターン終了時にトランスクリプト `.jsonl` から user / assistant メッセージを抽出し、`doc/prompt/YYYYMMDD_HHMMSS_auto.proof.md` として保存して自動コミットする（1 ファイル 30,000 文字で打ち切り）

## なぜ作られたか

初期構成（2026-06-02）。**その後 2 件の事故で改修している。** ① `git commit -m <msg>` にパス指定が無く、フック起動前にステージされていた 14 ファイルを巻き込んでコミットした（ADR-023）→ `-- <ファイル>` を追加し、失敗理由を `doc/log/error/auto-record-trace.log` に記録するようにした ② `git add` の標準エラーを `2>$null` で捨てていたため、コミット失敗時に真因の手掛かりが残らなかった（ADR-052）→ add の失敗を記録し、失敗したら commit をスキップするようにした

## 導入

```sh
mkdir -p .claude/hooks doc/log/error
cp hooks/auto-record.ps1 .claude/hooks/
```

その後 `.claude/settings.json` に同梱の `settings.snippet.json` の内容をマージする。
**`.ps1` は UTF-8 BOM 付きで保存する**（BOM が無いと PowerShell 5.1 が cp932 として読み、日本語を含む行で構文エラーになる）。

## 収録ファイル

- `hooks/HOOK-SPEC.md`（9.7 KB）
- `hooks/auto-record.ps1`（13.4 KB）
- `settings.snippet.json`（276 B）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/scripts/check-encoding.py` — 未同梱（別パッケージ `claude-script-check-encoding` に収録）
- `.claude/skills/anthropics/` — 未同梱（切り出しの対象外。読み替えか削除が必要）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/record`

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
