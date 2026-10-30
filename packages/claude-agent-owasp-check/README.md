# owasp-check

OWASP Top 10 2021 に基づく静的脆弱性診断エージェント。A01〜A10 の各カテゴリで診断し、CVSS v3.1 付きでレポートを保存して git コミットする。/security-review から自動的に呼ばれる。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code サブエージェント |
| 導入先 | `.claude/agents/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b065e6b） |

## これは何か

OWASP Top 10 2021（A01〜A10）の静的脆弱性診断。CVSS v3.1 付き

## なぜ作られたか

2026-06-23 追加。**参照知識の分離は非対称性の解消として行った**: ペアで並列実行される `riss-ioqeo` だけが分離済みという状態だった（ADR-002）。**コミット手順にパス指定を追加したのは ADR-023 の事故を受けたもの**（診断レポートの自動コミットも同じ書き方をしていた）

## 導入

```sh
mkdir -p .claude/agents
cp agents/owasp-check.md .claude/agents/
```

**`.claude/agents/` はフラットに置く**（サブディレクトリを作っても登録機構は再帰的に走査するため、無効化の目的では使えない）。

## 使い方

Agent ツールで `subagent_type: "owasp-check"` を指定して起動する。

## 収録ファイル

- `agents/owasp-check.md`（7.2 KB）
- `references/owasp-check-reference.md`（7.8 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/agents/owasp-check.md` — **同梱**
- `.claude/references/owasp-check-reference.md` — **同梱**
- `.claude/rules/git-safety.md` — 未同梱（別パッケージ `claude-rule-git-safety` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/project-code-review` `/security-review`

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
