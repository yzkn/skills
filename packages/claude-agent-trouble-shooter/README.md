# trouble-shooter

障害発生中のリアルタイム調査を対話形式で 8 ステップで支援する。「トラブルシューティング」「障害調査」「問い合わせ対応」で呼び出す。本番環境は変更しない。事後分析は incident-responder。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code サブエージェント |
| 導入先 | `.claude/agents/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b065e6b） |

## これは何か

障害発生中のリアルタイム調査を 8 ステップで対話支援（ヒアリングシート・優先度判定・環境差分分析・障害報告書）

## なぜ作られたか

2026-06-25 追加。定義が 21.9KB あり、`data-modeler` に次いで大きかったため最初期に参照分離された（ADR-001）

## 導入

```sh
mkdir -p .claude/agents
cp agents/trouble-shooter.md .claude/agents/
```

**`.claude/agents/` はフラットに置く**（サブディレクトリを作っても登録機構は再帰的に走査するため、無効化の目的では使えない）。

## 使い方

Agent ツールで `subagent_type: "trouble-shooter"` を指定して起動する。

## 収録ファイル

- `agents/trouble-shooter.md`（12.7 KB）
- `references/trouble-shooter-reference.md`（16.3 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/agents/trouble-shooter.md` — **同梱**
- `.claude/references/trouble-shooter-reference.md` — **同梱**

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/record` `/trouble-shoot`

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
