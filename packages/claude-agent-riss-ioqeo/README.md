# riss-ioqeo

情報処理安全確保支援士相当のセキュリティ診断エージェント。IPA セキュアプログラミング・徳丸本に基づき SC-01〜SC-07 を診断し、OWASP Top 10 で扱わない観点を担う。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code サブエージェント |
| 導入先 | `.claude/agents/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b065e6b） |

## これは何か

情報処理安全確保支援士相当の診断。IPA ガイドライン・徳丸本に基づき SC-01〜SC-07（セッション管理・CSRF・クリックジャッキング・ヘッダインジェクション・STRIDE・テスト網羅性・インフラ）を診断する

## なぜ作られたか

2026-06-24 追加。OWASP Top 10 で扱わない観点を埋める目的。定義が 16.1KB あり軽量モデルで手順が脱落するリスクがあったため、最初期に参照分離された 1 件（ADR-001）

## 導入

```sh
mkdir -p .claude/agents
cp agents/riss-ioqeo.md .claude/agents/
```

**`.claude/agents/` はフラットに置く**（サブディレクトリを作っても登録機構は再帰的に走査するため、無効化の目的では使えない）。

## 使い方

Agent ツールで `subagent_type: "riss-ioqeo"` を指定して起動する。

## 収録ファイル

- `agents/riss-ioqeo.md`（10.2 KB）
- `references/riss-ioqeo-reference.md`（9.8 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/agents/riss-ioqeo.md` — **同梱**
- `.claude/references/riss-ioqeo-reference.md` — **同梱**
- `.claude/rules/git-safety.md` — 未同梱（別パッケージ `claude-rule-git-safety` に収録）

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
