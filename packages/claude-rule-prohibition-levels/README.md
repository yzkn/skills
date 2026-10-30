# prohibition-levels

禁止事項の 2 階層分類（絶対禁止 / 要指示）と、絶対禁止を指示された場合・違反に気づいた場合の必須行動。すべてのルールに優先して常時適用する。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code ルール（CLAUDE.md から読み込む規約） |
| 導入先 | `.claude/rules/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 30aedfb） |

## これは何か

禁止事項を【絶対禁止】（指示・承認でも解除されない）と【要指示】（明示指示がある場合のみ）の 2 階層に分類し、絶対禁止を指示された場合の標準応答と違反時の必須行動を定める。全ルールに優先

## なぜ作られたか

**失敗起点。** `git push` の禁止ルールが「ユーザーの指示があれば実行可」と誤解釈され、実際に実行された違反の再発防止策として新設（コミット `1dfefe1`、2026-07-03）。同時に `settings.json` の `permissions.deny` へ `Bash(git push*)` 等を追加し、モデルの解釈によらずハーネス側で拒否する二重化を行った

## 導入

```sh
mkdir -p .claude/rules
cp rules/prohibition-levels.md .claude/rules/
```

常時適用したい場合は `CLAUDE.md` に `@.claude/rules/prohibition-levels.md` の行を追加する。frontmatter に `paths:` があるルールは `@` 行に**加えない**（加えると常時ロードになり、条件付きの意味が失われる）。

## 収録ファイル

- `rules/prohibition-levels.md`（2.9 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/git-safety.md` — 未同梱（別パッケージ `claude-rule-git-safety` に収録）
- `.claude/rules/guide-access.md` — 未同梱（別パッケージ `claude-rule-guide-access` に収録）
- `.claude/rules/security-hardstops.md` — 未同梱（別パッケージ `claude-rule-security-hardstops` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/wizard`

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
