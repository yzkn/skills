---
description: 画像を Read する前の解像度調整規約。大きい画像は視覚トークンを大量に消費するため、判読に必要な最小解像度へ縮小してから読む。intake/・guide/・design/・report/・template/ 配下の画像を扱う際に自動ロードされる。
paths:
  - "intake/**"
  - "guide/**"
  - "design/**"
  - "report/**"
  - "template/**"
---

# 画像読み込みの規約（パス条件付き）

Read ツールで画像を開くと、画素数に比例した視覚トークンを消費する。**縮小してから読めば同じ判断ができる画像を、原寸で読んではならない。**

本リポジトリの実測（2026-08-19）: PNG 289 枚のうち **211 枚（73%）が 1280×720 を超えて**おり、最大は 3484×1731。画素数の中央値は 957,488 px。

## 手順

### 1. 読む前に寸法を確認する

```sh
python -c "import struct,sys; d=open(sys.argv[1],'rb').read(33); print(*struct.unpack('>II',d[16:24]))" <画像>
```

PNG 以外や複数枚をまとめて見る場合は PyMuPDF を使う（`fitz.open(<画像>)[0].rect`）。

### 2. 縮小するかを判断する

| 画像の性質 | 判断 |
|---|---|
| 画面全体のレイアウト・構成・配色を見る（モックアップ・スクリーンショット全景） | **縮小する。** 長辺 1280px 以下を目安にする |
| 図表・グラフの形と大まかな値を見る | **縮小する。** 同上 |
| **画像内の文字を読む**（設定値・エラーメッセージ・表の数値・手順書のラベル） | **縮小しない。** 縮小すると文字が判読できなくなり、読み直しで結局トークンを余分に使う |
| 1280×720 以下 | そのまま読む |

**迷ったら縮小しない。** 縮小して読めなかった場合は原寸で読み直すことになり、合計の消費は増える。

### 3. 縮小する

PyMuPDF（導入済み）で縮小し、**スクラッチパッドか作業用の `wip/` に書き出す**。元の画像は書き換えない。

```sh
python -c "
import fitz,sys
src,dst,maxw=sys.argv[1],sys.argv[2],int(sys.argv[3])
native=fitz.Pixmap(src).width                       # 実ピクセル幅
page=fitz.open(src)[0]
zoom=(maxw if native>maxw else native)/page.rect.width
pm=page.get_pixmap(matrix=fitz.Matrix(zoom,zoom)); pm.save(dst)
print(f'{native} -> {pm.width}x{pm.height}')
" <元画像> <出力先>.png 1280
```

**`page.rect` を実ピクセル数として使ってはならない。** PyMuPDF が返す `page.rect` は画像の DPI メタデータに基づくポイント寸法で、実ピクセルとは一致しない（実測: 3484×1731 の PNG で `page.rect` は 760×378）。実ピクセル数は `fitz.Pixmap(src).width` で取る。上のコマンドは 3484px の画像を 1280px へ、908px の画像を 908px のまま出力することを確認済み（2026-08-19 実測）。

### 4. 部分だけが必要なら切り出す

画像の一部（1 つの図・1 つのダイアログ）だけを見たい場合は、縮小より**領域クリップのほうが有効**。PDF からの図表切り出しは `.claude/scripts/pdf/extract_figures.py` を使う。

## 禁止・注意事項

- 【絶対禁止】**`guide/for-human/` の画像を読んではならない**（`.claude/rules/guide-access.md`）。`guide/for-llm/` を使う
- **元の画像を縮小版で上書きしない。** 縮小は読むためだけの一時的な派生物であり、`intake/` の受領資料原本・`design/` の成果物は原寸を保つ（`.claude/rules/safe-file-ops.md`）
- 縮小版は読み終わったら片付ける。削除の前に対象一覧をユーザーに提示して確認を得る
- 大量の画像（目安 10 枚以上）をまとめて縮小・集計する場合は `/bulk-ops` と同じ方針で**スクリプト 1 回にまとめ、要約だけをコンテキストに載せる**

## 根拠

出典: [Anthropic claude-cookbooks](https://github.com/anthropics/claude-cookbooks) の `cost_optimization/cost_optimization.ipynb`。同 notebook は画像を 1280×720 以下へ事前ダウンスケールすることで 4,000 トークンが約 1,200 トークンになる例を示している。**本リポジトリでは「画像内の文字を読む場合は縮小しない」という例外を追加した**（設計書のスクリーンショットは細部の判読が目的であり、一律の縮小は読み直しを招くため）。
