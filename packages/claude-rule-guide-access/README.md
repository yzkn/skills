# guide-access

guide/ ディレクトリ参照時に適用するアクセス規則。Claude Code は guide/for-llm/ のみを参照する。guide/ 配下のファイルを扱う際に自動ロードされる。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code ルール（CLAUDE.md から読み込む規約） |
| 導入先 | `.claude/rules/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 2196a3d） |

## これは何か

`guide/for-human/`（Office 原本）の参照を【絶対禁止】とし、Markdown 変換済みの `for-llm/` のみを使う

## なぜ作られたか

**Office ファイルの直接読み込みがトークンを大量消費する**ため（コミット `568cf46`、2026-06-25）

## 導入

```sh
mkdir -p .claude/rules
cp rules/guide-access.md .claude/rules/
```

常時適用したい場合は `CLAUDE.md` に `@.claude/rules/guide-access.md` の行を追加する。frontmatter に `paths:` があるルールは `@` 行に**加えない**（加えると常時ロードになり、条件付きの意味が失われる）。

## 収録ファイル

- `rules/guide-access.md`（1.4 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/prohibition-levels.md` — 未同梱（別パッケージ `claude-rule-prohibition-levels` に収録）

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
