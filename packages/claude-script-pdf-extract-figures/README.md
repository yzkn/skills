# pdf-extract-figures

PDF の `Figure N` / `Table N` を画像として切り出す（PyMuPDF）

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | 共有スクリプト |
| 導入先 | `.claude/scripts/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | 第三者由来（同梱 LICENSE を参照） |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 74feb54） |

## これは何か

PDF の `Figure N` / `Table N` を画像として切り出す（PyMuPDF）

## なぜ作られたか

`source-extract` と `explainer-html` の 2 スキルから呼ぶ共有スクリプトとして配置（2026-08-03）。**第三者由来のため LICENSE を同梱している**

## 導入

```sh
mkdir -p .claude/scripts
cp -r scripts/* .claude/scripts/
```

## 収録ファイル

- `scripts/pdf/LICENSE`（1.1 KB）
- `scripts/pdf/extract_figures.py`（7.2 KB）

## 単体利用時の注意

元リポジトリ固有のパスへの参照は検出されなかった。

## ライセンス

同梱の `scripts/pdf/LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: （切り出し元の記録を参照）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
