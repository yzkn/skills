# ux-designer

UX デザイナーエージェント。ユーザーリサーチ・UI/UX 設計・プロトタイプ・ユーザビリティテスト・アクセシビリティ改善を担う。コードは修正せず設計書・HTML モックアップの生成にとどめる。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code サブエージェント |
| 導入先 | `.claude/agents/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b065e6b） |

## これは何か

ユーザーリサーチ・UI/UX 設計・ローフィデリティプロトタイプ・ユーザビリティテスト・アクセシビリティ改善

## なぜ作られたか

2026-06-23 追加。後に **`ui-designer` との役割分離**でプロトタイプをローフィデリティ限定（グレースケール骨格のみ）に変更した

## 導入

```sh
mkdir -p .claude/agents
cp agents/ux-designer.md .claude/agents/
```

**`.claude/agents/` はフラットに置く**（サブディレクトリを作っても登録機構は再帰的に走査するため、無効化の目的では使えない）。

## 使い方

Agent ツールで `subagent_type: "ux-designer"` を指定して起動する。

## 収録ファイル

- `agents/ux-designer.md`（6.6 KB）
- `references/ux-designer-reference.md`（6.7 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/agents/ux-designer.md` — **同梱**
- `.claude/references/ux-designer-reference.md` — **同梱**
- `.claude/skills/ai-product-design/` — 未同梱（切り出しの対象外。読み替えか削除が必要）
- `.claude/skills/ux-research/` — 未同梱（切り出しの対象外。読み替えか削除が必要）
- `.claude/skills/ux-research/research-methods.md` — 未同梱（切り出しの対象外。読み替えか削除が必要）
- `.claude/skills/ux-review/accessibility-wcag.md` — 未同梱（切り出しの対象外。読み替えか削除が必要）
- `.claude/skills/ux-review/cognitive-load.md` — 未同梱（切り出しの対象外。読み替えか削除が必要）
- `.claude/skills/ux-review/heuristics.md` — 未同梱（切り出しの対象外。読み替えか削除が必要）
- `.claude/skills/ux-writing/voice-tone.md` — 未同梱（別パッケージ `claude-skill-ux-writing` に収録）

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
