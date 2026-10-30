# compliance-checker

コンプライアンス診断エージェント。個人情報保護法・GDPR・PCI DSS 等の規制要件および ISO 27001 / SOC 2 への適合状況を静的診断する。owasp-check・riss-ioqeo の技術的観点に対し法的観点を担う。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code サブエージェント |
| 導入先 | `.claude/agents/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b065e6b） |

## これは何か

個人情報保護法・GDPR・PCI DSS・ISO 27001 への適合状況を静的診断（法的判断は専門家に委ねる）

## なぜ作られたか

同上（記録なし）。`owasp-check`・`riss-ioqeo` の技術的観点に対し**法的観点**を担う

## 導入

```sh
mkdir -p .claude/agents
cp agents/compliance-checker.md .claude/agents/
```

**`.claude/agents/` はフラットに置く**（サブディレクトリを作っても登録機構は再帰的に走査するため、無効化の目的では使えない）。

## 使い方

Agent ツールで `subagent_type: "compliance-checker"` を指定して起動する。

## 収録ファイル

- `agents/compliance-checker.md`（6.4 KB）
- `references/compliance-checker-reference.md`（6.7 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/agents/compliance-checker.md` — **同梱**
- `.claude/references/compliance-checker-reference.md` — **同梱**

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/record`

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
