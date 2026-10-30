# job-resume-check.ps1

`.jobs/` に「完了済み（`exit.code` あり）かつ未報告（`collected` なし）」のジョブがある場合のみ、再開の指示を出力する

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code フック |
| 導入先 | `.claude/hooks/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 882bd6b） |

## これは何か

`.jobs/` に「完了済み（`exit.code` あり）かつ未報告（`collected` なし）」のジョブがある場合のみ、再開の指示を出力する

## なぜ作られたか

**失敗起点。** `/long-run` の detach ジョブは走り続けるが**待つ側の Claude Code は止まる**。実際にセッション `9d8bbcfb` で、完了通知が届いた 1.2 秒後に 429（5 時間リミット）で失敗しており、解除後にユーザーが「続けてください」と打つまで再開しなかった（ADR-039）

## 導入

```sh
mkdir -p .claude/hooks doc/log/error
cp hooks/job-resume-check.ps1 .claude/hooks/
```

その後 `.claude/settings.json` に同梱の `settings.snippet.json` の内容をマージする。
**`.ps1` は UTF-8 BOM 付きで保存する**（BOM が無いと PowerShell 5.1 が cp932 として読み、日本語を含む行で構文エラーになる）。

## 収録ファイル

- `hooks/HOOK-SPEC.md`（9.7 KB）
- `hooks/job-resume-check.ps1`（3.8 KB）
- `settings.snippet.json`（294 B）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/scripts/check-encoding.py` — 未同梱（別パッケージ `claude-script-check-encoding` に収録）
- `.claude/scripts/long-run.ps1` — 未同梱（別パッケージ `claude-script-long-run` に収録）
- `.claude/skills/anthropics/` — 未同梱（切り出しの対象外。読み替えか削除が必要）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/long-run`

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
