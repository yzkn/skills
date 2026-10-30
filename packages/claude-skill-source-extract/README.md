# /source-extract

顧客受領資料・議事メモを要約せず全文抽出する（PDF / pptx / docx / xlsx / テキスト）。「資料を全文抽出して」「議事録を取り込んで」で自動適用。/source-extract [対象パス]。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/source-extract/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 5f3ae03） |

## これは何か

`intake/` の受領資料・議事録を**要約せず全文抽出**し `intake/extract/` に転記する（クロスツール検証を経てから）

## なぜ作られたか

同上（ADR-003）

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/source-extract .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/source-extract/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/source-extract` での呼び出しもできない。

## 使い方

`/source-extract` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/source-extract/SKILL.md`（7.6 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/design-docs.md` — 未同梱（別パッケージ `claude-rule-design-docs` に収録）
- `.claude/rules/security-hardstops.md` — 未同梱（別パッケージ `claude-rule-security-hardstops` に収録）
- `.claude/scripts/office/read_document.py` — 未同梱（別パッケージ `claude-script-office` に収録）
- `.claude/scripts/office/verify_conversion.py` — 未同梱（別パッケージ `claude-script-office` に収録）
- `.claude/scripts/pdf/extract_figures.py` — 未同梱（別パッケージ `claude-script-pdf-extract-figures` に収録）
- `.claude/skills/office/SKILL.md` — **同梱**

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
