# /anti-slop-review

生成 UI が「AI が作った見た目（AI slop）」になっていないか診断する読み取り専用の監査。「AI っぽくないか見て」「AI slop を監査して」で自動適用。/anti-slop-review [対象]。品質レビューは ux-review。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/anti-slop-review/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | Hallmark, MIT |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b065e6b） |

## これは何か

生成 UI が「AI が作った見た目（AI slop）」になっていないかを名前付きの兆候（紫グラデヒーロー・3 等分グリッド・Inter 一択・transition-all・捏造メトリクス）で診断する

## なぜ作られたか

2026-07-21 導入。**この基準が後の移植判断を左右した**: `visual-doc` の原典が定義していた `linear-gradient(135deg,#667eea,#764ba2)` は本スキルが 🔴 Critical として名指しで検出する当のものであり、原典の配色体系を採用しない根拠になった（ADR-015）

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/anti-slop-review .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/anti-slop-review/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/anti-slop-review` での呼び出しもできない。

## 使い方

`/anti-slop-review` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/anti-slop-review/LICENSE`（1.6 KB）
- `skills/anti-slop-review/SKILL.md`（12.1 KB）
- `skills/anti-slop-review/references/checklist.md`（16.1 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/external-resources.md` — 未同梱（別パッケージ `claude-rule-external-resources` に収録）
- `.claude/skills/vnl/scripts/vnl.py` — 未同梱（別パッケージ `claude-skill-vnl` に収録）

## ライセンス

同梱の `skills/anti-slop-review/LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: Hallmark, MIT

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
