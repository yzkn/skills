# /pretty-mermaid

既存の Mermaid 記法を静的な SVG に描画する。主用途は design/ の図を Word・PowerPoint・PDF の納品物へ載せること。「Mermaid を画像にして」「納品用に図を焼き込んで」で自動適用。/pretty-mermaid <対象>。図の新規設計は visual-doc。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/pretty-mermaid/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | imxv/Pretty-mermaid-skills, MIT |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 8d162a3） |

## これは何か

既存の Mermaid 記法を静的な SVG に描画する（納品物への焼き込み用）

## なぜ作られたか

**導入時点では描画結果を一度も確認しておらず、検証で複数の不具合が判明した**（ADR-020）。生成 SVG が Google Fonts へ `@import` し CSS 変数と `color-mix()` に依存するため、素のままでは対応レンダラー以外で全ノードが黒く潰れる → **原典にない `flatten.mjs` を追加**。さらに pandoc は `rsvg-convert` なしで SVG をラスタ化できず**警告のみで exit 0 のまま**壊れた図を docx に埋めるため `rasterize.mjs` を追加。日本語ラベルは全角 5 文字以内が目安（枠幅が欧文字幅で計算される・実測）

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/pretty-mermaid .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/pretty-mermaid/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/pretty-mermaid` での呼び出しもできない。

## 使い方

`/pretty-mermaid` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/pretty-mermaid/LICENSE`（1.1 KB）
- `skills/pretty-mermaid/SKILL.md`（17.6 KB）
- `skills/pretty-mermaid/assets/example_diagrams/class.mmd`（544 B）
- `skills/pretty-mermaid/assets/example_diagrams/er.mmd`（616 B）
- `skills/pretty-mermaid/assets/example_diagrams/flowchart.mmd`（261 B）
- `skills/pretty-mermaid/assets/example_diagrams/sequence.mmd`（307 B）
- `skills/pretty-mermaid/assets/example_diagrams/state.mmd`（233 B）
- `skills/pretty-mermaid/package-lock.json`（1.5 KB）
- `skills/pretty-mermaid/package.json`（327 B）
- `skills/pretty-mermaid/references/DIAGRAM_TYPES.md`（7.0 KB）
- `skills/pretty-mermaid/references/THEMES.md`（5.1 KB）
- `skills/pretty-mermaid/scripts/batch.mjs`（5.5 KB）
- `skills/pretty-mermaid/scripts/flatten.mjs`（7.3 KB）
- `skills/pretty-mermaid/scripts/rasterize.mjs`（5.9 KB）
- `skills/pretty-mermaid/scripts/render.mjs`（5.3 KB）
- `skills/pretty-mermaid/scripts/themes.mjs`（1.6 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/code-quality.md` — 未同梱（別パッケージ `claude-rule-code-quality` に収録）
- `.claude/rules/design-docs.md` — 未同梱（別パッケージ `claude-rule-design-docs` に収録）
- `.claude/rules/external-resources.md` — 未同梱（別パッケージ `claude-rule-external-resources` に収録）
- `.claude/rules/safe-file-ops.md` — 未同梱（別パッケージ `claude-rule-safe-file-ops` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/db-review` `/drawio` `/explainer-html` `/office-pandoc` `/visual-doc`

## ライセンス

同梱の `skills/pretty-mermaid/LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: imxv/Pretty-mermaid-skills, MIT

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
