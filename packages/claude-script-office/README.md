# office

Office / PDF の読み取り。anydoc → markitdown → Docling の自動フォールバック

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | 共有スクリプト |
| 導入先 | `.claude/scripts/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 5cfe772） |

## これは何か

Office / PDF の読み取り。anydoc → markitdown → Docling の自動フォールバック

## なぜ作られたか

office スキルの読み取り品質改善（2026-07-03）。**stdout を UTF-8 / LF に固定している**（`_init_stdout()`）のは、Windows でのリダイレクト保存時の文字化けと改行の二重変換（`\r\r\n`）を防ぐため。この固定を外すと、保存された Markdown で表の各行が空行に分断され検証が誤判定する

## 導入

```sh
mkdir -p .claude/scripts
cp -r scripts/* .claude/scripts/
```

## 収録ファイル

- `scripts/office/pandoc/build_reference.py`（41.7 KB）
- `scripts/office/pandoc/extract_potx_theme.py`（4.0 KB）
- `scripts/office/pandoc/themes/glacier/reference.docx`（11.5 KB）
- `scripts/office/pandoc/themes/glacier/reference.pptx`（35.5 KB）
- `scripts/office/pandoc/themes/glacier/theme.json`（711 B）
- `scripts/office/pandoc/themes/graphite/reference.docx`（11.5 KB）
- `scripts/office/pandoc/themes/graphite/reference.pptx`（35.5 KB）
- `scripts/office/pandoc/themes/graphite/theme.json`（709 B）
- `scripts/office/pandoc/themes/indigo/reference.docx`（11.5 KB）
- `scripts/office/pandoc/themes/indigo/reference.pptx`（35.5 KB）
- `scripts/office/pandoc/themes/indigo/theme.json`（707 B）
- `scripts/office/pandoc/themes/royal-navy/reference.docx`（11.5 KB）
- `scripts/office/pandoc/themes/royal-navy/reference.pptx`（35.5 KB）
- `scripts/office/pandoc/themes/royal-navy/theme.json`（717 B）
- `scripts/office/pandoc/themes/sunrise/reference.docx`（11.5 KB）
- `scripts/office/pandoc/themes/sunrise/reference.pptx`（35.5 KB）
- `scripts/office/pandoc/themes/sunrise/theme.json`（720 B）
- `scripts/office/pandoc/themes/terracotta/reference.docx`（11.5 KB）
- `scripts/office/pandoc/themes/terracotta/reference.pptx`（35.5 KB）
- `scripts/office/pandoc/themes/terracotta/theme.json`（711 B）
- `scripts/office/read_document.py`（19.7 KB）
- `scripts/office/verify_conversion.py`（23.8 KB）
- `scripts/office/write_excel.py`（1.9 KB）
- `scripts/office/write_pptx.py`（2.4 KB）
- `scripts/office/write_pptx_design.py`（20.5 KB）
- `scripts/office/write_word.py`（2.5 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/external-resources.md` — 未同梱（別パッケージ `claude-rule-external-resources` に収録）
- `.claude/scripts/office/pandoc/build_reference.py` — **同梱**
- `.claude/scripts/office/pandoc/extract_potx_theme.py` — **同梱**
- `.claude/skills/office/SKILL.md` — 未同梱（別パッケージ `claude-skill-office` に収録）

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
