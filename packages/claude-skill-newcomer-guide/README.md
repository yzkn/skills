# /newcomer-guide

社内文書を、IT や業務の知識がない新人でもわかるレベルまで噛み砕いて解説する。「わかりやすく説明して」「噛み砕いて」「読んでも意味がわからない」など理解が目的の依頼で発動。/newcomer-guide [テキストまたはパス]。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/newcomer-guide/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット a286b46） |

## これは何か

社内文書を IT・業務知識のない新人向けに噛み砕いて解説する（一言 → 1 分要約 → 5 分概要 → 用語 → 引用根拠 → 次の学習）

## なぜ作られたか

2026-07-22 追加。**`description` の改善が実測で検証された最初の事例**: 「レビューではなく意味を理解したい」ケースで発動していなかったため、評価・指摘ではなく**理解を目的とする依頼**で発動する対比を含む版へ差し替え、1.00 発動を確認した（コミット `bb479da`）。この作業中に Windows の `WinError 10038` と cp932 デコード失敗が判明し、`windows-python-tooling.md` が生まれた

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/newcomer-guide .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/newcomer-guide/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/newcomer-guide` での呼び出しもできない。

## 使い方

`/newcomer-guide` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/newcomer-guide/SKILL.md`（8.1 KB）
- `skills/newcomer-guide/eval/trigger-lite.json`（1.7 KB）
- `skills/newcomer-guide/eval/trigger.json`（5.6 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/guide-access.md` — 未同梱（別パッケージ `claude-rule-guide-access` に収録）
- `.claude/rules/prohibition-levels.md` — 未同梱（別パッケージ `claude-rule-prohibition-levels` に収録）

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
