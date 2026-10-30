# code-reviewer

読み取り専用のコードレビュー専門エージェント。未コミット・未追跡の変更または指定パスを Critical / Warning / Suggestion の 3 段階で指摘する。ユーザーからの依頼は /project-code-review 経由で呼ぶこと。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code サブエージェント |
| 導入先 | `.claude/agents/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b065e6b） |

## これは何か

読み取り専用のコードレビュー。`git diff` または指定パスを 🔴 Critical / 🟡 Warning / 🟢 Suggestion で指摘する。レビュー観点・出力フォーマットの正本

## なぜ作られたか

**`/project-code-review` スキルと役割が重複していた**ため、観点の正本をエージェント側へ一本化し、スキルは前提確認・委任・独立反証パス・後続提案だけの薄い層に縮小した（コミット `1f39c68`、2026-07-31）。Anthropic 公式のサブエージェント例を日本語化し本リポジトリの観点を統合。`tools` を Read/Grep/Glob/Bash に限定して Write/Edit を持たせないのは**レビュー中のコード改変を防ぐため**（技術的な書き込み不能保証ではなく規約）

## 導入

```sh
mkdir -p .claude/agents
cp agents/code-reviewer.md .claude/agents/
```

**`.claude/agents/` はフラットに置く**（サブディレクトリを作っても登録機構は再帰的に走査するため、無効化の目的では使えない）。

## 使い方

Agent ツールで `subagent_type: "code-reviewer"` を指定して起動する。

## 収録ファイル

- `agents/code-reviewer.md`（13.0 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/project-types/development.md` — 未同梱（切り出しの対象外。読み替えか削除が必要）
- `.claude/rules/adversarial-review.md` — 未同梱（別パッケージ `claude-rule-adversarial-review` に収録）
- `.claude/rules/external-resources.md` — 未同梱（別パッケージ `claude-rule-external-resources` に収録）
- `.claude/rules/guide-access.md` — 未同梱（別パッケージ `claude-rule-guide-access` に収録）
- `.claude/rules/third-party-licenses.md` — 未同梱（別パッケージ `claude-rule-third-party-licenses` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/api-guide` `/code-refactor` `/deploy-guide` `/project-code-review` `/record` `/unit-test-gen`

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
