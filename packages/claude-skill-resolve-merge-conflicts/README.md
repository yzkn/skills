# /resolve-merge-conflicts

進行中の git merge / rebase / cherry-pick のコンフリクトを解消する。「コンフリクトを解消して」「マージが衝突した」「rebase が止まった」で自動適用。/resolve-merge-conflicts。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/resolve-merge-conflicts/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | mattpocock/skills, MIT（Copyright (c) 2026 Matt Pocock。59db609） |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b065e6b） |

## これは何か

進行中の merge / rebase / cherry-pick の衝突を、双方の変更意図の調査に基づいて解消する

## なぜ作られたか

同上

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/resolve-merge-conflicts .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/resolve-merge-conflicts/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/resolve-merge-conflicts` での呼び出しもできない。

## 使い方

`/resolve-merge-conflicts` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/resolve-merge-conflicts/LICENSE`（1.0 KB）
- `skills/resolve-merge-conflicts/SKILL.md`（2.7 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/git-safety.md` — 未同梱（別パッケージ `claude-rule-git-safety` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/unit-test-run`

## ライセンス

同梱の `skills/resolve-merge-conflicts/LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: mattpocock/skills, MIT（Copyright (c) 2026 Matt Pocock。59db609）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
