# test-strategist

テスト戦略エージェント。テスト計画・結合/E2E テスト設計・テスト観点の網羅性診断を担う。unit-test-gen/run が扱わないテスト戦略全体を設計する。subagent_type:'test-strategist' で呼び出す。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code サブエージェント |
| 導入先 | `.claude/agents/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 06f8e98） |

## これは何か

テスト計画書・テスト仕様書・E2E シナリオ・テスト観点カバレッジ診断（テストコード生成なし）

## なぜ作られたか

同上（記録なし）

## 導入

```sh
mkdir -p .claude/agents
cp agents/test-strategist.md .claude/agents/
```

**`.claude/agents/` はフラットに置く**（サブディレクトリを作っても登録機構は再帰的に走査するため、無効化の目的では使えない）。

## 使い方

Agent ツールで `subagent_type: "test-strategist"` を指定して起動する。

## 収録ファイル

- `agents/test-strategist.md`（5.4 KB）
- `references/test-strategist-reference.md`（8.3 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/agents/test-strategist.md` — **同梱**
- `.claude/references/test-strategist-reference.md` — **同梱**

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/unit-test-gen`

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
