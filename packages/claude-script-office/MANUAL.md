# office — マニュアル

## 1. 前提

| 項目 | 内容 |
|---|---|
| 対象 | Claude Code（CLI / VS Code 拡張 / デスクトップアプリ） |
| 検証環境 | Windows 11 Pro / PowerShell 5.1 と 7.x / Python 3.14 / Git Bash |
| 文字コード | すべて UTF-8。`.ps1` は **BOM 必須**、`.sh` は **BOM 禁止・改行 LF** |
| 前提ツール | Python 3.x・pandoc |

## 2. 収録物

| パス | サイズ | 役割 |
|---|---|---|
| `scripts/office/pandoc/build_reference.py` | 41.7 KB | Python スクリプト |
| `scripts/office/pandoc/extract_potx_theme.py` | 4.0 KB | Python スクリプト |
| `scripts/office/pandoc/themes/glacier/reference.docx` | 11.5 KB | — |
| `scripts/office/pandoc/themes/glacier/reference.pptx` | 35.5 KB | — |
| `scripts/office/pandoc/themes/glacier/theme.json` | 711 B | データ・設定 |
| `scripts/office/pandoc/themes/graphite/reference.docx` | 11.5 KB | — |
| `scripts/office/pandoc/themes/graphite/reference.pptx` | 35.5 KB | — |
| `scripts/office/pandoc/themes/graphite/theme.json` | 709 B | データ・設定 |
| `scripts/office/pandoc/themes/indigo/reference.docx` | 11.5 KB | — |
| `scripts/office/pandoc/themes/indigo/reference.pptx` | 35.5 KB | — |
| `scripts/office/pandoc/themes/indigo/theme.json` | 707 B | データ・設定 |
| `scripts/office/pandoc/themes/royal-navy/reference.docx` | 11.5 KB | — |
| `scripts/office/pandoc/themes/royal-navy/reference.pptx` | 35.5 KB | — |
| `scripts/office/pandoc/themes/royal-navy/theme.json` | 717 B | データ・設定 |
| `scripts/office/pandoc/themes/sunrise/reference.docx` | 11.5 KB | — |
| `scripts/office/pandoc/themes/sunrise/reference.pptx` | 35.5 KB | — |
| `scripts/office/pandoc/themes/sunrise/theme.json` | 720 B | データ・設定 |
| `scripts/office/pandoc/themes/terracotta/reference.docx` | 11.5 KB | — |
| `scripts/office/pandoc/themes/terracotta/reference.pptx` | 35.5 KB | — |
| `scripts/office/pandoc/themes/terracotta/theme.json` | 711 B | データ・設定 |
| `scripts/office/read_document.py` | 19.7 KB | Python スクリプト |
| `scripts/office/verify_conversion.py` | 23.8 KB | Python スクリプト |
| `scripts/office/write_excel.py` | 1.9 KB | Python スクリプト |
| `scripts/office/write_pptx.py` | 2.4 KB | Python スクリプト |
| `scripts/office/write_pptx_design.py` | 20.5 KB | Python スクリプト |
| `scripts/office/write_word.py` | 2.5 KB | Python スクリプト |

## 3. 導入手順

```sh
mkdir -p .claude/scripts
cp -r scripts/* .claude/scripts/
```

## 4. 内容の構成

本体（`scripts/office/pandoc/build_reference.py`）の冒頭の説明コメント:

- pandoc reference-doc テンプレート（reference.docx / reference.pptx）を生成する。
- office-pandoc スキルの補助スクリプト。
- - reference.pptx: theme.json の `_source` が指すスライドマスター（potx）**そのもの**を基底に構築する。
- 背景画像・図形・マスターデザインを完全に保持したまま、pandoc が名前で照合する
- レイアウト（Title Slide 等）へ potx のレイアウトを改名して割り当て、potx に存在しない
- レイアウト（Two Content / Comparison / Content with Caption）はコンテンツから
- 合成する。未使用レイアウト・サンプルスライド・未参照メディアは削除して軽量化する。
- - reference.docx: pandoc 組み込みのデフォルト reference をベースに、theme.json の
- デザイントークン（potx から抽出）を OOXML パッチとして適用する。
- 使い方:
- python .claude/scripts/office/pandoc/build_reference.py [--theme <テーマ名>]
- （--theme 省略時は themes/ 配下の全テーマを生成）

## 5. 導入後の検証

```sh
python -m py_compile scripts/office/pandoc/build_reference.py scripts/office/pandoc/extract_potx_theme.py scripts/office/read_document.py scripts/office/verify_conversion.py scripts/office/write_excel.py scripts/office/write_pptx.py scripts/office/write_pptx_design.py scripts/office/write_word.py
echo "exit=$?"
```

## 6. 既知の制約

- 既知の制約なし（切り出し元の記録に基づく）

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/scripts/office/` |
| 元の格納先 | `.claude/scripts/office/` |
| 出典 | 本リポジトリ独自 |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |

### 作成の経緯（切り出し元の記録より）

office スキルの読み取り品質改善（2026-07-03）。**stdout を UTF-8 / LF に固定している**（`_init_stdout()`）のは、Windows でのリダイレクト保存時の文字化けと改行の二重変換（`\r\r\n`）を防ぐため。この固定を外すと、保存された Markdown で表の各行が空行に分断され検証が誤判定する

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
