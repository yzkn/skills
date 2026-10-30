# /design-md

デザイントークンを DESIGN.md（Google Labs 仕様）として作成・検証・取り込みする。「DESIGN.md を作って」「デザイントークンを整理して」「DESIGN.md を検証して」で自動適用。/design-md <new|lint|import>。配色・スタイルの選定は ui-ux-pro-max。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/design-md/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | google-labs-code/design.md, Apache-2.0（Google Labs。6e5da53） |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b8cf817） |

## これは何か

デザインシステムの正本 `design/03_basic_design/DESIGN.md` を Google Labs の DESIGN.md 仕様に準拠して作成・検証・取り込みする

## なぜ作られたか

**本リポジトリが既に 3 つの独自形式でデザインシステムを出力していた**（`ui-designer` の独自見出し・`design-dna` の Hallmark 形式・`ui-ux-pro-max` の `MASTER.md`）ことが調査で判明し、正本を 1 つに定めるために新設（ADR-044）。ユーザーが提示した 2 サイトは**仕様の出典ではなかった**（出典は google-labs-code/design.md）。実在プロダクト由来のデザインシステム集をトークンの入力にしないことを【要指示】とした

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/design-md .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/design-md/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/design-md` での呼び出しもできない。

## 使い方

`/design-md` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/design-md/LICENSE`（11.1 KB）
- `skills/design-md/SKILL.md`（9.1 KB）
- `skills/design-md/eval/trigger.json`（2.3 KB）
- `skills/design-md/references/spec-summary.md`（5.6 KB）
- `skills/design-md/scripts/validate_design_md.py`（8.8 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/code-quality.md` — 未同梱（別パッケージ `claude-rule-code-quality` に収録）
- `.claude/rules/design-docs.md` — 未同梱（別パッケージ `claude-rule-design-docs` に収録）
- `.claude/rules/external-resources.md` — 未同梱（別パッケージ `claude-rule-external-resources` に収録）
- `.claude/rules/third-party-licenses.md` — 未同梱（別パッケージ `claude-rule-third-party-licenses` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/vnl`

## ライセンス

同梱の `skills/design-md/LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: google-labs-code/design.md, Apache-2.0（Google Labs。6e5da53）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
