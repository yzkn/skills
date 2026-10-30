# /design-dna

参考 Web デザインのスクリーンショットまたは URL から「デザイン DNA」（構造・アーキタイプ・タイポ・カラー・リズム）を抽出し、骨格として転用できる形で診断する。「この参考サイトを分析して」で自動適用。/design-dna <URL または説明>。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/design-dna/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | Hallmark, MIT |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 6646f56） |

## これは何か

参考デザインのスクショ / URL から「デザイン DNA」（マクロ構造・アーキタイプ・タイポ役・カラーアンカー・リズム）を抽出する読み取り専用の診断

## なぜ作られたか

同上。URL 取得に間接インジェクション対策・SSRF ガードを追加

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/design-dna .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/design-dna/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/design-dna` での呼び出しもできない。

## 使い方

`/design-dna` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/design-dna/LICENSE`（1.6 KB）
- `skills/design-dna/SKILL.md`（33.0 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/external-resources.md` — 未同梱（別パッケージ `claude-rule-external-resources` に収録）
- `.claude/skills/design-md/SKILL.md` — **同梱**
- `.claude/skills/design-md/scripts/validate_design_md.py` — 未同梱（別パッケージ `claude-skill-design-md` に収録）

## ライセンス

同梱の `skills/design-dna/LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: Hallmark, MIT

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
