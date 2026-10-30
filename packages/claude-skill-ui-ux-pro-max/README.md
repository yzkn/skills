# /ui-ux-pro-max

UI/UX デザインインテリジェンス。スタイル・パレット・フォントペアリング・UX ガイドラインを検索提供する。「配色を提案して」「フォントを選んで」「デザインシステムを生成して」で自動適用。/ui-ux-pro-max <キーワード>。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/ui-ux-pro-max/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | 同上 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 6646f56） |

## これは何か

検索可能なデザインデータベース（スタイル 67・パレット 161・フォントペア 57・UX ガイドライン 99・22 スタック別ベストプラクティス）

## なぜ作られたか

Python 標準ライブラリのみで動作

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/ui-ux-pro-max .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/ui-ux-pro-max/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/ui-ux-pro-max` での呼び出しもできない。

## 使い方

`/ui-ux-pro-max` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/ui-ux-pro-max/LICENSE.txt`（1.1 KB）
- `skills/ui-ux-pro-max/SKILL.md`（47.5 KB）
- `skills/ui-ux-pro-max/data/app-interface.csv`（9.5 KB）
- `skills/ui-ux-pro-max/data/charts.csv`（18.9 KB）
- `skills/ui-ux-pro-max/data/colors.csv`（37.9 KB）
- `skills/ui-ux-pro-max/data/google-fonts.csv`（727.7 KB）
- `skills/ui-ux-pro-max/data/icons.csv`（20.3 KB）
- `skills/ui-ux-pro-max/data/landing.csv`（16.3 KB）
- `skills/ui-ux-pro-max/data/motion.csv`（10.3 KB）
- `skills/ui-ux-pro-max/data/products.csv`（72.0 KB）
- `skills/ui-ux-pro-max/data/react-performance.csv`（14.5 KB）
- `skills/ui-ux-pro-max/data/stacks/angular.csv`（17.8 KB）
- `skills/ui-ux-pro-max/data/stacks/astro.csv`（11.6 KB）
- `skills/ui-ux-pro-max/data/stacks/avalonia.csv`（25.1 KB）
- `skills/ui-ux-pro-max/data/stacks/flutter.csv`（10.2 KB）
- `skills/ui-ux-pro-max/data/stacks/html-tailwind.csv`（11.1 KB）
- `skills/ui-ux-pro-max/data/stacks/javafx.csv`（30.2 KB）
- `skills/ui-ux-pro-max/data/stacks/jetpack-compose.csv`（8.1 KB）
- `skills/ui-ux-pro-max/data/stacks/laravel.csv`（18.1 KB）
- `skills/ui-ux-pro-max/data/stacks/nextjs.csv`（12.3 KB）
- `skills/ui-ux-pro-max/data/stacks/nuxt-ui.csv`（20.8 KB）
- `skills/ui-ux-pro-max/data/stacks/nuxtjs.csv`（16.2 KB）
- `skills/ui-ux-pro-max/data/stacks/react-native.csv`（9.8 KB）
- `skills/ui-ux-pro-max/data/stacks/react.csv`（12.7 KB）
- `skills/ui-ux-pro-max/data/stacks/shadcn.csv`（15.6 KB）
- `skills/ui-ux-pro-max/data/stacks/svelte.csv`（10.8 KB）
- `skills/ui-ux-pro-max/data/stacks/swiftui.csv`（10.6 KB）
- `skills/ui-ux-pro-max/data/stacks/threejs.csv`（43.8 KB）
- `skills/ui-ux-pro-max/data/stacks/uno.csv`（26.9 KB）
- `skills/ui-ux-pro-max/data/stacks/uwp.csv`（22.4 KB）
- `skills/ui-ux-pro-max/data/stacks/vue.csv`（10.8 KB）
- `skills/ui-ux-pro-max/data/stacks/winui.csv`（24.6 KB）
- `skills/ui-ux-pro-max/data/stacks/wpf.csv`（22.1 KB）
- `skills/ui-ux-pro-max/data/styles.csv`（139.3 KB）
- `skills/ui-ux-pro-max/data/typography.csv`（48.7 KB）
- `skills/ui-ux-pro-max/data/ui-reasoning.csv`（51.8 KB）
- `skills/ui-ux-pro-max/data/ux-guidelines.csv`（18.3 KB）
- `skills/ui-ux-pro-max/scripts/core.py`（13.2 KB）
- `skills/ui-ux-pro-max/scripts/design_system.py`（57.4 KB）
- `skills/ui-ux-pro-max/scripts/search.py`（6.7 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/design-docs.md` — 未同梱（別パッケージ `claude-rule-design-docs` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/design-md`

## ライセンス

同梱の `skills/ui-ux-pro-max/LICENSE.txt` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: 同上

> ⚠ LICENSE.txt を同梱（自動検出）。

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
