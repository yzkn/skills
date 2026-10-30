# dependency-auditor

依存関係診断エージェント（SCA）。依存定義ファイルから既知 CVE・ライセンスリスク・EOL パッケージを診断し、owasp-check・riss-ioqeo が扱わないライブラリ自体のリスクを補完する。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code サブエージェント |
| 導入先 | `.claude/agents/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b065e6b） |

## これは何か

SCA 診断。依存定義ファイルから既知 CVE・ライセンスリスク・EOL パッケージを検出

## なぜ作られたか

2026-06-24 の一括追加（`Add subagents`）。個別の動機は記録なし。`third-party-licenses.md` が定める継続監査の担い手として後から位置づけられた

## 導入

```sh
mkdir -p .claude/agents
cp agents/dependency-auditor.md .claude/agents/
```

**`.claude/agents/` はフラットに置く**（サブディレクトリを作っても登録機構は再帰的に走査するため、無効化の目的では使えない）。

## 使い方

Agent ツールで `subagent_type: "dependency-auditor"` を指定して起動する。

## 収録ファイル

- `agents/dependency-auditor.md`（6.7 KB）
- `references/dependency-auditor-reference.md`（6.9 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/agents/dependency-auditor.md` — **同梱**
- `.claude/references/dependency-auditor-reference.md` — **同梱**

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
