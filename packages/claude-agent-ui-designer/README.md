# ui-designer

UI デザイナーエージェント。デザインシステム設計・高精度 HTML モックアップ・ビジュアル品質監査を担う。リサーチ・ワイヤーフレームは ux-designer。コードは修正しない。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code サブエージェント |
| 導入先 | `.claude/agents/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b8cf817） |

## これは何か

デザインシステム設計・高精度 HTML モックアップ・ビジュアル品質監査・コンポーネント全状態の視覚仕様

## なぜ作られたか

**`ux-designer` 1 体が構造と視覚仕上げの両方を抱えていたため役割を分離**して新設（コミット `cfc101f`、2026-06-24）。5 タスク種別を持つ。出力先の `DESIGN.md` は後に Google Labs 仕様の正本へ集約された（ADR-044）

## 導入

```sh
mkdir -p .claude/agents
cp agents/ui-designer.md .claude/agents/
```

**`.claude/agents/` はフラットに置く**（サブディレクトリを作っても登録機構は再帰的に走査するため、無効化の目的では使えない）。

## 使い方

Agent ツールで `subagent_type: "ui-designer"` を指定して起動する。

## 収録ファイル

- `agents/ui-designer.md`（10.7 KB）
- `references/ui-designer-reference.md`（7.2 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/agents/ui-designer.md` — **同梱**
- `.claude/references/ui-designer-reference.md` — **同梱**
- `.claude/skills/design-md/SKILL.md` — 未同梱（別パッケージ `claude-skill-design-md` に収録）
- `.claude/skills/design-md/scripts/validate_design_md.py` — 未同梱（別パッケージ `claude-skill-design-md` に収録）
- `.claude/skills/ui-ux-pro-max/scripts/search.py` — 未同梱（別パッケージ `claude-skill-ui-ux-pro-max` に収録）
- `.claude/skills/ux-review/craft.md` — 未同梱（切り出しの対象外。読み替えか削除が必要）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/design-md`

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
