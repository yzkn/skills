# environment-safety

本番環境に関わる操作で常時適用する安全規則。案件種別を問わず適用する。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code ルール（CLAUDE.md から読み込む規約） |
| 導入先 | `.claude/rules/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 2536052） |

## これは何か

本番デプロイの承認必須、`production`/`prod`/`prd` 文字列の二重確認、本番接続下での破壊的 SQL 禁止

## なぜ作られたか

記録なし（2026-06-23 に既存ルールから切り分け）

## 導入

```sh
mkdir -p .claude/rules
cp rules/environment-safety.md .claude/rules/
```

常時適用したい場合は `CLAUDE.md` に `@.claude/rules/environment-safety.md` の行を追加する。frontmatter に `paths:` があるルールは `@` 行に**加えない**（加えると常時ロードになり、条件付きの意味が失われる）。

## 収録ファイル

- `rules/environment-safety.md`（1.1 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/prohibition-levels.md` — 未同梱（別パッケージ `claude-rule-prohibition-levels` に収録）

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
