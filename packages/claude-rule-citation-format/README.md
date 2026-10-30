# citation-format

引用・典拠の書式規約（引用ブロック・文中参照・典拠一覧）。design/・report/ 配下のファイルを扱う際に自動ロードされる。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code ルール（CLAUDE.md から読み込む規約） |
| 導入先 | `.claude/rules/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 74feb54） |

## これは何か

引用ブロックの書式・文中参照（`[label (YYYY/MM), 位置]`）・典拠一覧の表形式

## なぜ作られたか

引用・典拠の書式規約が**本リポジトリの空白地帯**だった（grep で該当なし）。mathbullet/skills の `writing-quotation` と `documenting-with-sources` を統合して導入（ADR-017）。原典の行形式の典拠一覧は採らず、`/research` の信頼性付き表形式に統一した

## 導入

```sh
mkdir -p .claude/rules
cp rules/citation-format.md .claude/rules/
```

常時適用したい場合は `CLAUDE.md` に `@.claude/rules/citation-format.md` の行を追加する。frontmatter に `paths:` があるルールは `@` 行に**加えない**（加えると常時ロードになり、条件付きの意味が失われる）。

## 収録ファイル

- `rules/citation-format.md`（1.5 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/skills/citation-format/SKILL.md` — 未同梱（別パッケージ `claude-skill-citation-format` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/research`

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
