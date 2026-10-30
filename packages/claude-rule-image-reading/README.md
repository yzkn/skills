# image-reading

画像を Read する前の解像度調整規約。大きい画像は視覚トークンを大量に消費するため、判読に必要な最小解像度へ縮小してから読む。intake/・guide/・design/・report/・template/ 配下の画像を扱う際に自動ロードされる。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code ルール（CLAUDE.md から読み込む規約） |
| 導入先 | `.claude/rules/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b23f716） |

## これは何か

画像を Read する前に判読に必要な最小解像度へ縮小する（文字を読む画像は縮小しない）

## なぜ作られたか

**視覚トークンの浪費対策。** anthropics/claude-cookbooks の `cost_optimization` から適用可能な手法を実装した一環（コミット `b23f716`、2026-08-19）

## 導入

```sh
mkdir -p .claude/rules
cp rules/image-reading.md .claude/rules/
```

常時適用したい場合は `CLAUDE.md` に `@.claude/rules/image-reading.md` の行を追加する。frontmatter に `paths:` があるルールは `@` 行に**加えない**（加えると常時ロードになり、条件付きの意味が失われる）。

## 収録ファイル

- `rules/image-reading.md`（4.4 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/guide-access.md` — 未同梱（別パッケージ `claude-rule-guide-access` に収録）
- `.claude/rules/safe-file-ops.md` — 未同梱（別パッケージ `claude-rule-safe-file-ops` に収録）
- `.claude/scripts/pdf/extract_figures.py` — 未同梱（別パッケージ `claude-script-pdf-extract-figures` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/bulk-ops`

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
