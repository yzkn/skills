# safe-file-ops

ファイル・ディレクトリを操作するすべての場面で常時適用する安全規則。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code ルール（CLAUDE.md から読み込む規約） |
| 導入先 | `.claude/rules/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 518ae8e） |

## これは何か

削除の慎重化・編集前のスコープ明示・編集後の diff 検証・0 バイト化防止・**文字コード / 改行 / BOM の機械検査**・形式変換のクロスツール検証

## なぜ作られたか

2026-06-23 に切り分け。**失敗起点の加筆が 2 回ある。** ① 変換ツールと同じツールで検証しても欠落を再現するだけだと判明 → クロスツール検証を必須化 ② 2 日間で 3 件連続した文字コード起因の失敗（ADR-050）→ `check-encoding.py` を名指しする項目を追加。従前は `.claude/hooks/` 配下の PowerShell に限定した BOM の記述しかなかった

## 導入

```sh
mkdir -p .claude/rules
cp rules/safe-file-ops.md .claude/rules/
```

常時適用したい場合は `CLAUDE.md` に `@.claude/rules/safe-file-ops.md` の行を追加する。frontmatter に `paths:` があるルールは `@` 行に**加えない**（加えると常時ロードになり、条件付きの意味が失われる）。

## 収録ファイル

- `docs/text-encoding.md`（6.8 KB）
- `rules/safe-file-ops.md`（3.7 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/safe-file-ops.md` — **同梱**
- `.claude/scripts/check-encoding.py` — 未同梱（別パッケージ `claude-script-check-encoding` に収録）
- `.claude/scripts/fix-bom.py` — 未同梱（別パッケージ `claude-script-fix-bom` に収録）
- `.claude/skills/office/SKILL.md` — 未同梱（別パッケージ `claude-skill-office` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/vnl`

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
