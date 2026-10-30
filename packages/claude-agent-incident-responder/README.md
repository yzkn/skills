# incident-responder

インシデント対応エージェント。障害ログから影響範囲を分析し、タイムライン整理・RCA・ポストモーテム・再発防止策を作成する。認証情報の漏えい・リポジトリの誤公開の初動手順も示す。debugger の開発中バグ修正に対し本番障害の事後分析を担う。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code サブエージェント |
| 導入先 | `.claude/agents/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット ced75d8） |

## これは何か

障害ログからタイムライン整理・RCA（5 Whys）・ポストモーテム・再発防止策を作成（本番環境変更なし）

## なぜ作られたか

2026-06-24 の一括追加（記録なし）。`debugger` の開発中バグ修正に対し**本番障害の事後分析**を担う

## 導入

```sh
mkdir -p .claude/agents
cp agents/incident-responder.md .claude/agents/
```

**`.claude/agents/` はフラットに置く**（サブディレクトリを作っても登録機構は再帰的に走査するため、無効化の目的では使えない）。

## 使い方

Agent ツールで `subagent_type: "incident-responder"` を指定して起動する。

## 収録ファイル

- `agents/incident-responder.md`（11.5 KB）
- `references/incident-responder-reference.md`（4.4 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/agents/incident-responder.md` — **同梱**
- `.claude/references/incident-responder-reference.md` — **同梱**
- `.claude/rules/git-safety.md` — 未同梱（別パッケージ `claude-rule-git-safety` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/record` `/wizard`

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
