# security-hardstops

セキュリティに関わる絶対禁止事項。コード生成・ファイル操作・git 操作のすべての場面で適用する。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code ルール（CLAUDE.md から読み込む規約） |
| 導入先 | `.claude/rules/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット d9cbe8a） |

## これは何か

認証情報のハードコーディング禁止・`.env` のコミット禁止・本番データのテスト環境使用禁止（すべて【絶対禁止】）

## なぜ作られたか

記録なし（2026-06-23 に既存ルールから切り分け）。後に `/vnl testdata`・`/bulk-ops mask` を代替手段として名指しする形へ改修（ADR-033）

## 導入

```sh
mkdir -p .claude/rules
cp rules/security-hardstops.md .claude/rules/
```

常時適用したい場合は `CLAUDE.md` に `@.claude/rules/security-hardstops.md` の行を追加する。frontmatter に `paths:` があるルールは `@` 行に**加えない**（加えると常時ロードになり、条件付きの意味が失われる）。

## 収録ファイル

- `rules/security-hardstops.md`（1.1 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/prohibition-levels.md` — 未同梱（別パッケージ `claude-rule-prohibition-levels` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/bulk-ops` `/vnl`

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
