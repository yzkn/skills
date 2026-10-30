# /visual-doc

設計書・レポートに添える自己完結 HTML の図をインライン SVG で生成する。「構成図を作って」「フロー図にして」「ガントチャートを描いて」で自動適用。/visual-doc <モード> [対象]。プロジェクト状況は project-dashboard。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/visual-doc/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | mhattingpete/claude-skills-marketplace, Apache-2.0 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b065e6b） |

## これは何か

自己完結 HTML の図をインライン SVG で生成する 5 モード（architecture / flowchart / timeline / dashboard / techdoc）

## なぜ作られたか

**原典 5 スキルを 1 本に統合し、リファレンスの 4 重複を解消**（ADR-015）。**原典の配色・タイポ体系は採用せず**、紫グラデーションを排除して意味色のみ CSS 変数として残し、`prefers-color-scheme` 対応（原典は 0 件）と日本語フォントスタックを追加

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/visual-doc .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/visual-doc/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/visual-doc` での呼び出しもできない。

## 使い方

`/visual-doc` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/visual-doc/LICENSE`（9.5 KB）
- `skills/visual-doc/SKILL.md`（9.0 KB）
- `skills/visual-doc/assets/base_template.html`（10.7 KB）
- `skills/visual-doc/references/diagram_patterns.md`（12.8 KB）
- `skills/visual-doc/references/svg_library.md`（10.9 KB）
- `skills/visual-doc/scripts/verify_output.py`（8.2 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/api-conventions.md` — 未同梱（別パッケージ `claude-rule-api-conventions` に収録）
- `.claude/rules/design-docs.md` — 未同梱（別パッケージ `claude-rule-design-docs` に収録）
- `.claude/rules/third-party-licenses.md` — 未同梱（別パッケージ `claude-rule-third-party-licenses` に収録）
- `.claude/rules/wbs-tasks.md` — 未同梱（別パッケージ `claude-rule-wbs-tasks` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/anti-slop-review` `/api-guide` `/ghostwriter` `/office-pandoc` `/project-dashboard` `/slides-maker` `/ui-ux-pro-max`

## ライセンス

同梱の `skills/visual-doc/LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: mhattingpete/claude-skills-marketplace, Apache-2.0

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
