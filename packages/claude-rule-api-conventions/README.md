# api-conventions

RESTful API の設計規約（エンドポイント命名・HTTP ステータスコード・エラーレスポンス形式・バージョニング）。src/・design/04_detailed_design/ 配下のファイルを扱う際に自動ロードされる。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code ルール（CLAUDE.md から読み込む規約） |
| 導入先 | `.claude/rules/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 88f533c） |

## これは何か

REST の命名・HTTP ステータス・エラーレスポンス形式・バージョニング

## なぜ作られたか

記録なし（初期構成の一部）。パス条件付きルール化は ADR-003 で導入した機構に乗せたもの

## 導入

```sh
mkdir -p .claude/rules
cp rules/api-conventions.md .claude/rules/
```

常時適用したい場合は `CLAUDE.md` に `@.claude/rules/api-conventions.md` の行を追加する。frontmatter に `paths:` があるルールは `@` 行に**加えない**（加えると常時ロードになり、条件付きの意味が失われる）。

## 収録ファイル

- `rules/api-conventions.md`（1.9 KB）

## 単体利用時の注意

元リポジトリ固有のパスへの参照は検出されなかった。

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/api-guide`

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
