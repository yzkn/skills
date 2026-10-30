# /office-pandoc

Markdown を pandoc で Word（.docx）/ PowerPoint（.pptx）へ一括変換する。「Word に変換して」「設計書を納品用 Word にして」で自動適用。/office-pandoc <入力md> [--to docx|pptx]。凝ったスライドは slides-maker。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/office-pandoc/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 5f3ae03） |

## これは何か

Markdown 正本を pandoc で docx / pptx へ一括変換し、**読み戻して往復検証**する。reference-doc テーマ 7 種

## なぜ作られたか

**作成の経緯は記録されていない。** この項目はキット初期構成（2026-06-02〜06-25）に含まれ、追加コミットのメッセージが 1 行のため動機が残っていない。失敗や不具合が契機だったという記録もない。

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/office-pandoc .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/office-pandoc/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/office-pandoc` での呼び出しもできない。

## 使い方

`/office-pandoc` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/office-pandoc/README.md`（14.1 KB）
- `skills/office-pandoc/SKILL.md`（11.5 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/design-docs.md` — 未同梱（別パッケージ `claude-rule-design-docs` に収録）
- `.claude/rules/guide-access.md` — 未同梱（別パッケージ `claude-rule-guide-access` に収録）
- `.claude/scripts/office/pandoc/build_reference.py` — 未同梱（別パッケージ `claude-script-office` に収録）
- `.claude/scripts/office/pandoc/extract_potx_theme.py` — 未同梱（別パッケージ `claude-script-office` に収録）
- `.claude/scripts/office/pandoc/themes/` — 未同梱（別パッケージ `claude-script-office` に収録）
- `.claude/scripts/office/verify_conversion.py` — 未同梱（別パッケージ `claude-script-office` に収録）
- `.claude/skills/office/SKILL.md` — **同梱**

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/office` `/pretty-mermaid` `/slides-maker`

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
