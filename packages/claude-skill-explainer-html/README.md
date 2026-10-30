# /explainer-html

概念・仕組み・調査結果を説明する自己完結 HTML 文書を作成・編集する。「HTML の解説文書を作って」「説明ページにして」で自動適用。/explainer-html <対象>。図 1 点だけなら visual-doc。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/explainer-html/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | mathbullet/skills, MIT |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット ba3de65） |

## これは何か

概念・仕組み・調査結果を説明する自己完結 HTML 文書（外部リクエスト 0 件・ライト / ダーク両対応・数式は MathML）

## なぜ作られたか

**CDN 4 本を排除し、ダーク対応と MathML / skylighting への置換を加えて作り直した**（ADR-017）

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/explainer-html .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/explainer-html/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/explainer-html` での呼び出しもできない。

## 使い方

`/explainer-html` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/explainer-html/LICENSE`（1.1 KB）
- `skills/explainer-html/SKILL.md`（16.2 KB）
- `skills/explainer-html/assets/sample.html`（26.9 KB）
- `skills/explainer-html/assets/template.html`（18.3 KB）
- `skills/explainer-html/references/components.md`（5.4 KB）
- `skills/explainer-html/scripts/build_sample.py`（3.2 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/external-resources.md` — 未同梱（別パッケージ `claude-rule-external-resources` に収録）
- `.claude/rules/third-party-licenses.md` — 未同梱（別パッケージ `claude-rule-third-party-licenses` に収録）
- `.claude/scripts/pdf/extract_figures.py` — 未同梱（別パッケージ `claude-script-pdf-extract-figures` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/anti-slop-review` `/citation-format` `/ghostwriter` `/newcomer-guide` `/office-pandoc` `/project-dashboard` `/ui-ux-pro-max` `/visual-doc`

## ライセンス

同梱の `skills/explainer-html/LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: mathbullet/skills, MIT

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
