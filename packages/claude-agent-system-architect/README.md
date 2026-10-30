# system-architect

システムアーキテクトエージェント。技術選定・システム構成設計・スケーラビリティ設計・セキュリティアーキテクチャ・再アーキテクチャ戦略を担う。設計フェーズではコードを変更しない。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code サブエージェント |
| 導入先 | `.claude/agents/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b8cf817） |

## これは何か

技術選定・システム構成・スケーラビリティ・セキュリティアーキテクチャ・再アーキテクチャ戦略

## なぜ作られたか

2026-06-23 追加（記録なし）。定義が長大だったため参照分離（ADR-002）

## 導入

```sh
mkdir -p .claude/agents
cp agents/system-architect.md .claude/agents/
```

**`.claude/agents/` はフラットに置く**（サブディレクトリを作っても登録機構は再帰的に走査するため、無効化の目的では使えない）。

## 使い方

Agent ツールで `subagent_type: "system-architect"` を指定して起動する。

## 収録ファイル

- `agents/system-architect.md`（8.0 KB）
- `references/system-architect-reference.md`（6.3 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/agents/system-architect.md` — **同梱**
- `.claude/references/system-architect-reference.md` — **同梱**

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/record`

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
