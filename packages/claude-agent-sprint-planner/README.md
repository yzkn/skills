# sprint-planner

スプリント計画エージェント。ストーリーポイント見積もり・タスク分解・スプリントバックログ整理・WBS 生成を行う。requirements-analyst の後工程を担う。subagent_type:'sprint-planner' で呼び出す。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code サブエージェント |
| 導入先 | `.claude/agents/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b065e6b） |

## これは何か

ストーリーポイント見積もり・スプリントバックログ・WBS 生成・ベロシティ推定

## なぜ作られたか

同上。**生成物の形式が揺れていたことが `wbs-tasks.md` 新設の動機になった**（ADR-003）

## 導入

```sh
mkdir -p .claude/agents
cp agents/sprint-planner.md .claude/agents/
```

**`.claude/agents/` はフラットに置く**（サブディレクトリを作っても登録機構は再帰的に走査するため、無効化の目的では使えない）。

## 使い方

Agent ツールで `subagent_type: "sprint-planner"` を指定して起動する。

## 収録ファイル

- `agents/sprint-planner.md`（9.6 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/references/effort-estimation-reference.md` — 未同梱（切り出しの対象外。読み替えか削除が必要）
- `.claude/rules/wbs-tasks.md` — 未同梱（別パッケージ `claude-rule-wbs-tasks` に収録）

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
